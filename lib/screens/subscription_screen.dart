import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/phantom_service.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _tier = 'free';
  String? _walletAddress;
  double? _cashBalance;
  String? _expiresAt;
  int _remainingSessions = 0;
  bool _loading = true;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _loadState();
    PhantomService.instance.lastConnectedWallet.addListener(_onWalletEvent);
    PhantomService.instance.lastPaymentSignature.addListener(_onPaymentEvent);
  }

  @override
  void dispose() {
    PhantomService.instance.lastConnectedWallet.removeListener(_onWalletEvent);
    PhantomService.instance.lastPaymentSignature.removeListener(_onPaymentEvent);
    super.dispose();
  }

  void _onWalletEvent() => _loadState();

  void _onPaymentEvent() {
    if (PhantomService.instance.lastPaymentSignature.value != null) {
      _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated! Welcome aboard.')),
        );
      }
    }
  }

  Future<void> _loadState() async {
    setState(() => _loading = true);

    final tier = await SubscriptionService.instance.getCurrentTier();
    final remaining = await SubscriptionService.instance.remainingSessions();

    final userId = Supabase.instance.client.auth.currentUser?.id;
    String? wallet;
    String? expiresAt;
    if (userId != null) {
      final data = await Supabase.instance.client
          .from('users')
          .select('solana_wallet, subscription_expires_at')
          .eq('user_id', userId)
          .maybeSingle();
      wallet = data?['solana_wallet'] as String?;
      expiresAt = data?['subscription_expires_at'] as String?;
    }

    double? balance;
    if (wallet != null && wallet.isNotEmpty) {
      balance = await PhantomService.instance.getCashBalance(wallet);
    }

    if (mounted) {
      setState(() {
        _tier = tier;
        _walletAddress = wallet;
        _cashBalance = balance;
        _expiresAt = expiresAt;
        _remainingSessions = remaining;
        _loading = false;
      });
    }
  }

  Future<void> _connectWallet() async {
    final installed = await PhantomService.instance.isPhantomInstalled();
    if (!installed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phantom wallet app not found. Please install it first.')),
        );
      }
      return;
    }

    final launched = await PhantomService.instance.connect();
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Phantom. Please try again.')),
      );
    }
  }

  Future<void> _cancelSubscription() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('users')
        .update({'subscription_tier': 'free', 'subscription_expires_at': null})
        .eq('user_id', userId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription cancelled.')),
      );
      _loadState();
    }
  }

  Future<void> _subscribe() async {
    if (_walletAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect your wallet first.')),
      );
      return;
    }

    setState(() => _paying = true);

    final tx = await SubscriptionService.instance
        .buildPaymentTransaction(_walletAddress!);

    if (tx == null) {
      if (mounted) {
        setState(() => _paying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to prepare payment. Try again.')),
        );
      }
      return;
    }

    final launched = await PhantomService.instance.requestPayment(
      serializedTransaction: tx,
    );

    if (!launched && mounted) {
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Phantom.')),
      );
    }
  }

  Future<void> handlePaymentCallback(String signature) async {
    setState(() => _paying = true);

    final success = await SubscriptionService.instance.verifyPayment(signature);

    if (mounted) {
      setState(() => _paying = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated! Welcome aboard.')),
        );
        _loadState();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment could not be verified. Contact support.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Subscription', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC9A6FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlanCard(tier: _tier, remainingSessions: _remainingSessions),
                  const SizedBox(height: 24),
                  _SectionLabel('Wallet'),
                  const SizedBox(height: 12),
                  _WalletCard(
                    walletAddress: _walletAddress,
                    cashBalance: _cashBalance,
                    onConnect: _connectWallet,
                    onDisconnect: () async {
                      await PhantomService.instance.disconnect();
                      _loadState();
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_tier == 'free') ...[
                    _SectionLabel('Upgrade to Premium'),
                    const SizedBox(height: 12),
                    _UpgradeCard(
                      paying: _paying,
                      walletConnected: _walletAddress != null,
                      onSubscribe: _subscribe,
                    ),
                  ],
                  if (_tier == 'premium') ...[
                    _SectionLabel('Your plan'),
                    const SizedBox(height: 12),
                    _ActivePlanCard(
                      expiresAt: _expiresAt,
                      paying: _paying,
                      walletConnected: _walletAddress != null,
                      onRenew: _subscribe,
                      onCancel: _cancelSubscription,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String tier;
  final int remainingSessions;

  const _PlanCard({required this.tier, required this.remainingSessions});

  @override
  Widget build(BuildContext context) {
    final isPremium = tier == 'premium';
    final limits = SubscriptionService.instance.getLimits(tier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? const Color(0xFFC9A6FF).withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPremium
                  ? const Color(0xFFC9A6FF).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPremium ? 'PREMIUM' : 'FREE',
              style: TextStyle(
                color: isPremium ? const Color(0xFFC9A6FF) : Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$remainingSessions sessions left this week',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${limits.sessionDurationMinutes} min per session · ${limits.notificationsEnabled ? "Notifications on" : "No notifications"}',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String? walletAddress;
  final double? cashBalance;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _WalletCard({
    required this.walletAddress,
    required this.cashBalance,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final connected = walletAddress != null && walletAddress!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: connected
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Connected', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(walletAddress!.length - 4)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace'),
                ),
                if (cashBalance != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${cashBalance!.toStringAsFixed(2)} CASH',
                    style: const TextStyle(
                      color: Color(0xFFC9A6FF),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onDisconnect,
                  child: Text(
                    'Disconnect wallet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Text(
                  'Connect your Phantom wallet to subscribe with CASH.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onConnect,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC9A6FF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Connect Phantom',
                      style: TextStyle(color: Color(0xFFC9A6FF), fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final bool paying;
  final bool walletConnected;
  final VoidCallback onSubscribe;

  const _UpgradeCard({
    required this.paying,
    required this.walletConnected,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9A6FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '25 CASH / month',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _FeatureRow('10 AI sessions per week'),
          const SizedBox(height: 8),
          _FeatureRow('5 min sessions (vs 3 min)'),
          const SizedBox(height: 8),
          _FeatureRow('Push notifications for deviations'),
          const SizedBox(height: 8),
          _FeatureRow('Expanded pattern analysis'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: paying || !walletConnected ? null : onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                disabledBackgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: paying
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      walletConnected ? 'Pay 25 CASH' : 'Connect wallet first',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFFC9A6FF), size: 18),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 14)),
      ],
    );
  }
}

class _ActivePlanCard extends StatelessWidget {
  final String? expiresAt;
  final bool paying;
  final bool walletConnected;
  final VoidCallback onRenew;
  final VoidCallback onCancel;
  const _ActivePlanCard({
    this.expiresAt,
    required this.paying,
    required this.walletConnected,
    required this.onRenew,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    String expiryText = 'Your subscription renews monthly.';
    bool expired = false;
    int daysLeft = 0;
    if (expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt!);
      if (expiry != null) {
        daysLeft = expiry.difference(DateTime.now()).inDays;
        expired = daysLeft <= 0;
        expiryText = expired
            ? 'Expired. Pay 25 CASH to reactivate.'
            : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}.';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9A6FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium active',
            style: TextStyle(color: Color(0xFFC9A6FF), fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            expiryText,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: paying || !walletConnected ? null : onRenew,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                disabledBackgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: paying
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      expired ? 'Reactivate — 25 CASH' : 'Renew early — 25 CASH',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    title: const Text('Cancel subscription?', style: TextStyle(color: Colors.white)),
                    content: Text(
                      'Your premium features will remain active until expiry. You won\'t be charged again unless you renew.',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Keep', style: TextStyle(color: Color(0xFFC9A6FF))),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onCancel();
                        },
                        child: const Text('Cancel subscription', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                'Cancel subscription',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
