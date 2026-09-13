import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signal_tier_detector.dart';
import 'hrv_calculator.dart';
import 'sleep_window_processor.dart' show SleepWindow, SleepWindowProcessor;
import 'outlier_classifier.dart';
import 'supabase_writer.dart';

class HealthDataManager {
  static final Health _health = Health();
  late final SignalTierDetector _tierDetector;

  HealthDataManager() {
    _tierDetector = SignalTierDetector(_health);
    _health.configure();
  }

  static const List<HealthDataType> _fullTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<bool> requestPermissions() async {
    try {
      final granted = await _health.requestAuthorization(_fullTypes);
      debugPrint('Health permissions: granted=' + granted.toString());
      return granted;
    } catch (e) {
      debugPrint('Health permission error: ' + e.toString());
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

      // Read each type individually
      List<HealthDataPoint> points = [];
      String source = 'health_connect';
      final ok = <String>[];
      final skipped = <String>[];

      for (final type in _fullTypes) {
        try {
          final result = await _health.getHealthDataFromTypes(
            types: [type],
            startTime: since,
            endTime: now,
          );
          if (result.isNotEmpty) {
            points.addAll(result);
            ok.add(type.name);
          }
        } catch (_) {
          skipped.add(type.name);
        }
      }

      if (ok.isEmpty) source = 'hr_derived';
      if (ok.isNotEmpty) log('Read: ' + ok.join(', '));
      if (skipped.isNotEmpty) log('Skipped: ' + skipped.join(', '));
      log('Total points: ' + points.length.toString());

      if (points.isEmpty) {
        log('No health data in last 24 hours.');
        log('Sync your watch to Samsung Health then try again.');
        return;
      }

      final baseConfidence = kSourceConfidence[source] ?? 0.60;
      final sleepWindow = await SleepWindowProcessor.fetchLatestWindow(userId);
      final baselines = await _fetchBaselines(userId);

      final hrPoints = points
          .where((p) => p.type == HealthDataType.HEART_RATE)
          .map((p) => (
                value: (p.value as NumericHealthValue).numericValue.toDouble(),
                at: p.dateFrom,
              ))
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));

      final hrSamples = hrPoints.map((s) => s.value).toList();

      double? hrvProxy;
      if (hrSamples.isNotEmpty) {
        hrvProxy = HrvCalculator.hrDerivedProxy(hrSamples);
        if (hrvProxy != null) {
          log('HRV proxy: ' + hrvProxy.toStringAsFixed(1) + ' ms');
        }
      }

      final restingHr = _deriveRestingHr(hrPoints, sleepWindow);
      if (restingHr == null && hrPoints.isNotEmpty) {
        log('Resting HR: not derived (needs $_minSleepSamplesForRestingHr '
            'sleep-window samples, had ${hrPoints.length} total)');
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
          notes: point.sourceName + ' via ' + point.type.name,
          // toUtc() first: toIso8601String() on a local DateTime emits no
          // offset, so Postgres read WAT (UTC+1) as UTC and every row landed
          // an hour in the future.
          timestamp: point.dateFrom.toUtc().toIso8601String(),
        ));
      }

      if (restingHr != null) {
        records.add(ObservationRecord(
          userId: userId,
          metricType: 'resting_hr',
          value: double.parse(restingHr.value.toStringAsFixed(1)),
          source: 'hr_derived',
          confidence: 0.75,
          contextTag: 'confirmed_sleep',
          outlierFlag: 'none',
          weightInCalculation: 1.0,
          notes: 'p10 of sleep-window HR samples',
          timestamp: restingHr.at.toUtc().toIso8601String(),
        ));
        log('Resting HR: ' + restingHr.value.toStringAsFixed(1) + ' bpm');
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
          notes: 'hr-derived proxy from ' + hrSamples.length.toString() + ' HR samples',
          // Was DateTime.now(), which produced a new timestamp on every sync
          // and so could never dedupe. Anchored to the latest sample instead.
          timestamp: hrPoints.last.at.toUtc().toIso8601String(),
        ));
      }

      if (records.isEmpty) {
        log('No records to write.');
        return;
      }

      log('Writing ' + records.length.toString() + ' records...');
      await SupabaseWriter.batchInsert(records);
      log('Sync complete: ' + records.length.toString() + ' records written');
    } catch (e) {
      debugPrint('Sync error: ' + e.toString());
      onLog?.call('Error: ' + e.toString());
    }
  }

  String? _metricType(HealthDataType type) {
    // HEART_RATE is deliberately absent. Writing every heart rate sample as
    // resting_hr meant a reading taken while walking became a resting-HR
    // baseline point. Raw HR is now input to _deriveRestingHr only.
    //
    // STEPS is absent for a different reason: it was being written as
    // active_energy, averaging step counts and kilojoules into one metric.
    // The schema allowlist has no 'steps' entry, so storing it properly
    // needs a migration.
    const map = {
      HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'hrv',
      HealthDataType.RESTING_HEART_RATE: 'resting_hr',
      HealthDataType.SLEEP_ASLEEP: 'sleep_hours',
      HealthDataType.BLOOD_OXYGEN: 'spo2',
      HealthDataType.RESPIRATORY_RATE: 'respiratory_rate',
      HealthDataType.ACTIVE_ENERGY_BURNED: 'active_energy',
    };
    return map[type];
  }

  /// Resting HR as the 10th percentile of sleep-window heart rate samples.
  ///
  /// The minimum is too sensitive to a single artifact; the 10th percentile
  /// is what wearables use internally. Returns null below the sample floor —
  /// a resting HR derived from three readings is a guess wearing a number's
  /// clothes, and writing it would repeat the bug this replaces.
  static const int _minSleepSamplesForRestingHr = 8;

  ({double value, DateTime at})? _deriveRestingHr(
    List<({double value, DateTime at})> hrSamples,
    SleepWindow? sleepWindow,
  ) {
    if (sleepWindow == null) return null;

    final asleep = hrSamples
        .where((s) => SleepWindowProcessor.classify(s.at, sleepWindow) == 'confirmed_sleep')
        .toList();

    if (asleep.length < _minSleepSamplesForRestingHr) return null;

    final values = asleep.map((s) => s.value).toList()..sort();
    final position = 0.10 * (values.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    final resting = lower == upper
        ? values[lower]
        : values[lower] + (values[upper] - values[lower]) * (position - lower);

    // Stamped at the window's end, not now() — one row per sleep window,
    // so repeated syncs of the same night dedupe against each other.
    return (value: resting, at: sleepWindow.wakeTime);
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
