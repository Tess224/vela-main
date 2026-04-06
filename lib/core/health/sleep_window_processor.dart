import 'package:supabase_flutter/supabase_flutter.dart';

class SleepWindow {
  final DateTime sleepTime;
  final DateTime wakeTime;
  final String confidence;
  const SleepWindow({required this.sleepTime, required this.wakeTime, required this.confidence});
}

class SleepWindowProcessor {
  static Future<SleepWindow?> fetchLatestWindow(String userId) async {
    try {
      final result = await Supabase.instance.client
          .from('baseline_observations')
          .select('sleep_time_reported, wake_time_reported, sleep_time_confidence')
          .eq('user_id', userId)
          .not('sleep_time_reported', 'is', null)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();
      if (result == null) return null;
      final sleepTime = DateTime.tryParse(result['sleep_time_reported'] ?? '');
      final wakeTime = DateTime.tryParse(result['wake_time_reported'] ?? '');
      if (sleepTime == null || wakeTime == null) return null;
      return SleepWindow(
        sleepTime: sleepTime,
        wakeTime: wakeTime,
        confidence: result['sleep_time_confidence'] ?? 'unknown',
      );
    } catch (_) {
      return null;
    }
  }

  static String classify(DateTime sampleTime, SleepWindow? window) {
    if (window == null) return 'unknown';
    if (!sampleTime.isBefore(window.sleepTime) && !sampleTime.isAfter(window.wakeTime)) {
      return 'confirmed_sleep';
    }
    final hour = sampleTime.hour;
    if (hour >= 7 && hour <= 22) return 'confirmed_awake';
    return 'confirmed_rest';
  }
}
