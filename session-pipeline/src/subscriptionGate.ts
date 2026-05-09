import { SupabaseClient } from '@supabase/supabase-js';

interface TierConfig {
  weeklySessionLimit: number;
  sessionDurationMinutes: number;
  notificationsEnabled: boolean;
}

const TIER_CONFIGS: Record<string, TierConfig> = {
  free: { weeklySessionLimit: 3, sessionDurationMinutes: 3, notificationsEnabled: false },
  premium: { weeklySessionLimit: 10, sessionDurationMinutes: 5, notificationsEnabled: true },
};

export interface GateResult {
  allowed: boolean;
  reason?: string;
  tier: string;
  sessionDurationMinutes: number;
  sessionsRemaining: number;
}

export async function checkSessionGate(
  supabase: SupabaseClient,
  userId: string
): Promise<GateResult> {
  const { data: user, error } = await supabase
    .from('users')
    .select('subscription_tier, subscription_expires_at, ai_sessions_used_this_week, ai_week_start')
    .eq('user_id', userId)
    .single();

  if (error || !user) {
    return { allowed: false, reason: 'User not found', tier: 'free', sessionDurationMinutes: 3, sessionsRemaining: 0 };
  }

  let tier = (user.subscription_tier as string) ?? 'free';
  if (tier === 'premium' && user.subscription_expires_at) {
    const expiry = new Date(user.subscription_expires_at);
    if (expiry < new Date()) {
      tier = 'free';
      await supabase.from('users').update({ subscription_tier: 'free' }).eq('user_id', userId);
    }
  }

  const config = TIER_CONFIGS[tier] ?? TIER_CONFIGS.free;

  const now = new Date();
  const weekStart = user.ai_week_start ? new Date(user.ai_week_start) : null;
  let used = (user.ai_sessions_used_this_week as number) ?? 0;

  if (!weekStart || daysBetween(weekStart, now) >= 7) {
    await supabase.from('users').update({
      ai_sessions_used_this_week: 0,
      ai_week_start: now.toISOString().substring(0, 10),
    }).eq('user_id', userId);
    used = 0;
  }

  const remaining = Math.max(0, config.weeklySessionLimit - used);

  if (remaining <= 0) {
    return {
      allowed: false,
      reason: `Weekly session limit reached (${config.weeklySessionLimit}/${tier})`,
      tier,
      sessionDurationMinutes: config.sessionDurationMinutes,
      sessionsRemaining: 0,
    };
  }

  return { allowed: true, tier, sessionDurationMinutes: config.sessionDurationMinutes, sessionsRemaining: remaining };
}

export async function incrementSessionCount(
  supabase: SupabaseClient,
  userId: string
): Promise<void> {
  const { error } = await supabase.rpc('increment_session_count', { p_user_id: userId });

  if (error) {
    const { data } = await supabase
      .from('users')
      .select('ai_sessions_used_this_week')
      .eq('user_id', userId)
      .single();

    if (data) {
      await supabase.from('users')
        .update({ ai_sessions_used_this_week: ((data.ai_sessions_used_this_week as number) ?? 0) + 1 })
        .eq('user_id', userId);
    }
  }
}

export function shouldSendNotifications(tier: string): boolean {
  const config = TIER_CONFIGS[tier] ?? TIER_CONFIGS.free;
  return config.notificationsEnabled;
}

export async function verifyAndActivateSubscription(
  supabase: SupabaseClient,
  userId: string,
  signature: string,
  solanaRpcUrl: string
): Promise<{ success: boolean; error?: string }> {
  const { data: existing } = await supabase
    .from('payment_transactions')
    .select('id')
    .eq('solana_signature', signature)
    .maybeSingle();

  if (existing) {
    return { success: false, error: 'Transaction already processed' };
  }

  try {
    const txInfo = await fetchSolanaTransaction(signature, solanaRpcUrl);

    if (!txInfo) return { success: false, error: 'Transaction not found on-chain' };
    if (txInfo.err) return { success: false, error: 'Transaction failed on-chain' };

    await supabase.from('payment_transactions').insert({
      user_id: userId,
      solana_signature: signature,
      amount_cash: 25,
      status: 'confirmed',
      confirmed_at: new Date().toISOString(),
    });

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await supabase.from('users').update({
      subscription_tier: 'premium',
      subscription_expires_at: expiresAt.toISOString(),
    }).eq('user_id', userId);

    return { success: true };
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Unknown error';
    return { success: false, error: msg };
  }
}

function daysBetween(a: Date, b: Date): number {
  return Math.floor(Math.abs(b.getTime() - a.getTime()) / (1000 * 60 * 60 * 24));
}

async function fetchSolanaTransaction(
  signature: string,
  rpcUrl: string
): Promise<{ err: unknown } | null> {
  const response = await fetch(rpcUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 1,
      method: 'getTransaction',
      params: [signature, { encoding: 'jsonParsed', maxSupportedTransactionVersion: 0 }],
    }),
  });

  const json = await response.json() as { result?: { meta?: { err: unknown } } };
  if (!json.result) return null;
  return { err: json.result.meta?.err ?? null };
}
