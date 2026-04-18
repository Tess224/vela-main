import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SignalTierDetector {
  final Health _health;

  SignalTierDetector(this._health);

  Future<int> detectAndPersist(String userId) async {
    final tier = await _detectTier();
    final source = _sourceForTier(tier);

    await Supabase.instance.client
        .from('users')
        .update({'signal_tier': tier, 'primary_hrv_source': source})
        .eq('user_id', userId);

    debugPrint('SignalTier: tier=$tier source=$source');
    return tier;
  }

  Future<int> _detectTier() async {
    try {
      final hasHrv = await _health.hasPermissions(
            [HealthDataType.HEART_RATE_VARIABILITY_SDNN]) ?? false;
      if (hasHrv) return 1;

      final hasSleep = await _health.hasPermissions(
            [HealthDataType.SLEEP_ASLEEP]) ?? false;
      if (hasSleep) return 2;

      return 3;
    } catch (e) {
      debugPrint('Tier detection failed: $e');
      return 3;
    }
  }

  String _sourceForTier(int tier) {
    if (tier == 1) return 'health_connect';
    return 'hr_derived';
  }
}
