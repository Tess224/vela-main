import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SignalTierDetector {
  final Health _health;
  SignalTierDetector(this._health);

  // Android version detection lives here — callers do not need to know about it
  Future<bool> _isAndroid13Plus() async {
    if (!Platform.isAndroid) return true;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt >= 33;
    } catch (_) {
      return true;
    }
  }

  Future<int> detectAndPersist(String userId) async {
    final fullPath = await _isAndroid13Plus();
    final tier = await _detectTier(fullPath);
    final source = _sourceForTier(tier, fullPath);

    await Supabase.instance.client
        .from('users')
        .update({'signal_tier': tier, 'primary_hrv_source': source})
        .eq('user_id', userId);

    return tier;
  }

  Future<int> _detectTier(bool fullPath) async {
    if (!fullPath) return 3;
    try {
      final hasHrv = await _health.hasPermissions(
            [HealthDataType.HEART_RATE_VARIABILITY_SDNN]) ?? false;
      if (hasHrv) return 1;
      final hasSleep = await _health.hasPermissions(
            [HealthDataType.SLEEP_ASLEEP]) ?? false;
      if (hasSleep) return 2;
      return 3;
    } catch (_) {
      return 3;
    }
  }

  String _sourceForTier(int tier, bool fullPath) {
    if (!fullPath) return 'hr_derived';
    if (tier == 1) return 'health_connect';
    return 'hr_derived';
  }
}
