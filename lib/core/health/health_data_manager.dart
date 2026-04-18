import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signal_tier_detector.dart';
import 'hrv_calculator.dart';
import 'sleep_window_processor.dart';
import 'outlier_classifier.dart';
import 'supabase_writer.dart';

class HealthDataManager {
  static final Health _health = Health();
  late final SignalTierDetector _tierDetector;

  HealthDataManager() {
    _tierDetector = SignalTierDetector(_health);
  }

  static const List<HealthDataType> _fullTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static const List<HealthDataType> _fallbackTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
  ];

  Future<bool> requestPermissions() async {
    try {
      final granted = await _health.requestAuthorization(_fullTypes);
      if (granted) {
        debugPrint('Health: full permissions granted');
        return true;
      }
    } catch (e) {
      debugPrint('Health: full permission request failed: $e');
    }

    // Fall back to basic types
    try {
      final granted = await _health.requestAuthorization(_fallbackTypes);
      debugPrint('Health: fallback permissions granted=$granted');
      return granted;
    } catch (e) {
      debugPrint('Health: fallback permission request failed: $e');
      return false;
    }
  }

  Future<void> syncHealthData({
    required String userId,
    Function(String)? onLog,
  }) async {
    void log(String msg) {
      debugPrint(msg);
      onLog?.call(msg);
    }

    try {
      final tier = await _tierDetector.detectAndPersist(userId);
      log('Signal tier: $tier');

      final now = DateTime.now();
      final since = now.subtract(const Duration(hours: 24));

      // Try full types first, fall back if it fails
      List<HealthDataPoint> points = [];
      String source = 'health_connect';

      try {
        points = await _health.getHealthDataFromTypes(
          types: _fullTypes,
          startTime: since,
          endTime: now,
        );
        log('Full read: ${points.length} points');
      } catch (e) {
        log('Full read failed: $e — trying fallback');
        try {
          points = await _health.getHealthDataFromTypes(
            types: _fallbackTypes,
            startTime: since,
            endTime: now,
          );
          source = 'hr_derived';
          log('Fallback read: ${points.length} points');
        } catch (e2) {
          log('Fallback read also failed: $e2');
          log('Make sure Samsung Health is synced and watch is connected.');
          return;
        }
      }

      if (points.isEmpty) {
        log('No health data in last 24 hours.');
        log('Sync your watch to Samsung Health then try again.');
        return;
      }

      final baseConfidence = kSourceConfidence[source] ?? 0.60;
      log('Source: $source | Points: ${points.length}');

      final sleepWindow = await SleepWindowProcessor.fetchLatestWindow(userId);
      final baselines = await _fetchBaselines(userId);

      final hrSamples = points
          .where((p) => p.type == HealthDataType.HEART_RATE)
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .toList();

      double? hrvProxy;
      if (hrSamples.isNotEmpty) {
        hrvProxy = HrvCalculator.hrDerivedProxy(hrSamples);
        if (hrvProxy != null) {
          log('HRV proxy: ${hrvProxy.toStringAsFixed(1)} ms');
        }
      }

      final records = <ObservationRecord>[];

      for (final point in points) {
        final metricType = _metricType(point.type);
        if (metricType == null) continue;
        final value =
            (point.value as NumericHealthValue).numericValue.toDouble();
        final contextTag =
            SleepWindowProcessor.classify(point.dateFrom, sleepWindow);
        final baseline = baselines[metricType];
        final classified = OutlierClassifier.classify(
          value: value,
          rollingMean: baseline?['personal_mean'],
          rollingVariance: baseline?['personal_variance'],
          sourceConfidence: baseConfidence,
        );
        records.add(ObservationRecord(
          userId: userId,
          metricType: metricType,
          value: classified.value,
          source: source,
          confidence: classified.confidence,
          contextTag: contextTag,
          outlierFlag: classified.outlierFlag,
          weightInCalculation: classified.weight,
          notes: '${point.sourceName} via ${point.type.name}',
          timestamp: point.dateFrom.toIso8601String(),
        ));
      }

      if (hrvProxy != null) {
        records.add(ObservationRecord(
          userId: userId,
          metricType: 'hrv',
          value: hrvProxy,
          source: 'hr_derived',
          confidence: 0.60,
          contextTag: 'confirmed_awake',
          outlierFlag: 'none',
          weightInCalculation: 1.0,
          notes: 'hr-derived proxy from ${hrSamples.length} HR samples',
          timestamp: DateTime.now().toIso8601String(),
        ));
      }

      if (records.isEmpty) {
        log('No records to write.');
        return;
      }

      log('Writing ${records.length} records to Supabase...');
      await SupabaseWriter.batchInsert(records);
      log('Sync complete — ${records.length} records written');
    } catch (e) {
      debugPrint('Sync error: $e');
      onLog?.call('Error: $e');
    }
  }

  String? _metricType(HealthDataType type) {
    const map = {
      HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'hrv',
      HealthDataType.RESTING_HEART_RATE: 'resting_hr',
      HealthDataType.HEART_RATE: 'resting_hr',
      HealthDataType.SLEEP_ASLEEP: 'sleep_hours',
      HealthDataType.BLOOD_OXYGEN: 'spo2',
      HealthDataType.RESPIRATORY_RATE: 'respiratory_rate',
      HealthDataType.ACTIVE_ENERGY_BURNED: 'active_energy',
      HealthDataType.STEPS: 'active_energy',
    };
    return map[type];
  }

  Future<Map<String, Map<String, double?>?>> _fetchBaselines(
      String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('user_baselines')
          .select('metric_type, personal_mean, personal_variance')
          .eq('user_id', userId);
      return {
        for (final r in rows)
          r['metric_type'] as String: {
            'personal_mean': (r['personal_mean'] as num?)?.toDouble(),
            'personal_variance': (r['personal_variance'] as num?)?.toDouble(),
          }
      };
    } catch (_) {
      return {};
    }
  }
}
