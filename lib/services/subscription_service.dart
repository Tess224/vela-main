import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class TierLimits {
  final int weeklySessionLimit;
  final int sessionDurationMinutes;
  final bool notificationsEnabled;

  const TierLimits({
    required this.weeklySessionLimit,
    required this.sessionDurationMinutes,
    required this.notificationsEnabled,
  });

  static const free = TierLimits(
    weeklySessionLimit: 3,
    sessionDurationMinutes: 3,
    notificationsEnabled: false,
  );

  static const premium = TierLimits(
    weeklySessionLimit: 10,
    sessionDurationMinutes: 5,
    notificationsEnabled: true,
  );
}

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> getCurrentTier() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 'free';

    final data = await _client
        .from('users')
        .select('subscription_tier, subscription_expires_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return 'free';

    final tier = data['subscription_tier'] as String? ?? 'free';
    final expiresAt = data['subscription_expires_at'] as String?;

    if (tier == 'premium' && expiresAt != null) {
      final expiry = DateTime.parse(expiresAt);
      if (expiry.isBefore(DateTime.now())) return 'free';
    }

    return tier;
  }

  TierLimits getLimits(String tier) {
    return tier == 'premium' ? TierLimits.premium : TierLimits.free;
  }

  Future<bool> canStartSession() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await _client
        .from('users')
        .select('subscription_tier, subscription_expires_at, ai_sessions_used_this_week, ai_week_start')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return false;

    final tier = await getCurrentTier();
    final limits = getLimits(tier);

    final weekStart = DateTime.tryParse(data['ai_week_start'] as String? ?? '');
    final now = DateTime.now();
    int used = data['ai_sessions_used_this_week'] as int? ?? 0;

    if (weekStart == null || now.difference(weekStart).inDays >= 7) {
      await _client.from('users').update({
        'ai_sessions_used_this_week': 0,
        'ai_week_start': now.toIso8601String().substring(0, 10),
      }).eq('user_id', userId);
      used = 0;
    }

    return used < limits.weeklySessionLimit;
  }

  Future<void> recordSessionUsed() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.rpc('increment_session_count', params: {
      'p_user_id': userId,
    });
  }

  Future<int> remainingSessions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final tier = await getCurrentTier();
    final limits = getLimits(tier);

    final data = await _client
        .from('users')
        .select('ai_sessions_used_this_week, ai_week_start')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return 0;

    final weekStart = DateTime.tryParse(data['ai_week_start'] as String? ?? '');
    final now = DateTime.now();

    if (weekStart == null || now.difference(weekStart).inDays >= 7) {
      return limits.weeklySessionLimit;
    }

    final used = data['ai_sessions_used_this_week'] as int? ?? 0;
    return (limits.weeklySessionLimit - used).clamp(0, limits.weeklySessionLimit);
  }

  Future<int> sessionDurationSeconds() async {
    final tier = await getCurrentTier();
    final limits = getLimits(tier);
    return limits.sessionDurationMinutes * 60;
  }

  Future<String?> buildPaymentTransaction(String walletAddress) async {
    try {
      final response = await http.post(
        Uri.parse('${Env.sessionPipelineUrl}/subscription/build-tx'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _client.auth.currentUser?.id,
          'wallet_address': walletAddress,
        }),
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['transaction'] as String?;
    } catch (e) {
      debugPrint('Failed to build payment tx: $e');
      return null;
    }
  }

  Future<bool> verifyPayment(String signature) async {
    try {
      final response = await http.post(
        Uri.parse('${Env.sessionPipelineUrl}/subscription/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _client.auth.currentUser?.id,
          'signature': signature,
        }),
      );

      if (response.statusCode != 200) return false;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['success'] == true;
    } catch (e) {
      debugPrint('Failed to verify payment: $e');
      return false;
    }
  }
}
