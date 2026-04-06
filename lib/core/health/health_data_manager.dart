import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'signal_tier_detector.dart';
import 'hrv_calculator.dart';
import 'sleep_window_processor.dart';
import 'outlier_classifier.dart';
import 'supabase_writer.dart';

class HealthDataManager {
  static final Health _health = Health();
  late final SignalTierDetector _tierDetector;
  static int? _cachedSdkInt;

  HealthDataManager() {
    _tierDetector = SignalTierDetector(_health);
  }

  static Future<int> _getAndroidSdkInt() async {
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    if (!Platform.isAndroid) return 99;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _cachedSdkInt = info.version.sdkInt;
      return _cachedSdkInt!;
    } catch (_) {
      return 33;
    }
  }

  static Future<bool> get _isAndroid13Plus async {
    final sdk = await _getAndroidSdkInt();
    return sdk >= 33;
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
    final isFullPath = await _isAndroid13Plus;
    if (!isFullPath) {
      debugPrint('Android 12 — skipping Health Connect permission dialog');
      return true;
    }
    try {
      return await _health.requestAuthorization(_fullTypes);
    } catch (e) {
      debugPrint('Permission error: $e');
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
      final isFullPath = await _isAndroid13Plus;
      final sdkInt = await _getAndroidSdkInt();

      log(isFullPath
          ? 'Android $sdkInt — full Health Connect'
          : 'Android $sdkInt — basic fallback HR + Steps');

      // detectAndPersist now handles Android version detection internally
      final tier = await _tierDetector.detectAndPersist(userId);
      final source = isFullPath ? 'health_connect' : 'hr_derived';
      final baseConfidence = kSourceConfidence[source] ?? 0.60;

      log('Tier: $tier | Source: $source');

      final now = DateTime.now();
      final since = now.subtract(const Duration(hours: 24));
      final types = isFullPath ? _fullTypes : _fallbackTypes;

      List<HealthDataPoint> points = [];
      try {
        points = await _health.getHealthDataFromTypes(
          types: types,
          startTime: since,
          endTime: now,
        );
      } catch (e) {
        log('Could not read health data: $e');
        log('Make sure Samsung Health is synced and watch is connected.');
        return;
      }

      if (points.isEmpty) {
        log('No health data in last 24 hours.');
        log('Sync your watch to Samsung Health then try again.');
        return;
      }

      log('Found ${points.length} data points');

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
