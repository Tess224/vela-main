import 'package:supabase_flutter/supabase_flutter.dart';

const Map<String, double> kSourceConfidence = {
  'healthkit': 0.95,
  'health_connect': 0.92,
  'app_computed_rr': 0.88,
  'hr_derived': 0.60,
  'self_report': 0.80,
  'simulated': 1.0,
};

class ObservationRecord {
  final String userId;
  final String metricType;
  final double value;
  final String source;
  final double confidence;
  final String contextTag;
  final String outlierFlag;
  final double weightInCalculation;
  final String notes;
  final String timestamp;

  const ObservationRecord({
    required this.userId, required this.metricType, required this.value,
    required this.source, required this.confidence, required this.contextTag,
    required this.outlierFlag, required this.weightInCalculation,
    required this.notes, required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId, 'metric_type': metricType, 'value': value,
    'source': source, 'confidence': confidence, 'context_tag': contextTag,
    'outlier_flag': outlierFlag, 'weight_in_calculation': weightInCalculation,
    'notes': notes, 'timestamp': timestamp,
  };
}

class SupabaseWriter {
  /// Identity of a reading: metric + instant.
  ///
  /// Compared as epoch milliseconds, never as formatted strings. The previous
  /// version compared Dart's local-time output ("...T04:07:56.481") against
  /// PostgREST's ("...T04:07:56.481+00:00"); those never matched, so nothing
  /// was ever deduped and every sync re-inserted its whole 24h window.
  static String? _key(String? metricType, String? timestamp) {
    if (metricType == null || timestamp == null) return null;
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) return null;
    return '${metricType}_${parsed.toUtc().millisecondsSinceEpoch}';
  }

  static Future<void> batchInsert(List<ObservationRecord> records) async {
    if (records.isEmpty) return;

    final userId = records.first.userId;

    // Bound the lookup by time rather than by an IN list of every timestamp —
    // that list grows with sample count and can overflow the request URL.
    final instants = records
        .map((r) => DateTime.tryParse(r.timestamp)?.toUtc())
        .whereType<DateTime>()
        .toList();
    if (instants.isEmpty) return;

    instants.sort();
    final earliest = instants.first.subtract(const Duration(seconds: 1));
    final latest = instants.last.add(const Duration(seconds: 1));

    final existingKeys = <String>{};
    try {
      final existing = await Supabase.instance.client
          .from('baseline_observations')
          .select('metric_type, timestamp')
          .eq('user_id', userId)
          .gte('timestamp', earliest.toIso8601String())
          .lte('timestamp', latest.toIso8601String());

      for (final row in existing as List) {
        final key = _key(row['metric_type'] as String?, row['timestamp'] as String?);
        if (key != null) existingKeys.add(key);
      }
    } catch (e) {
      // A failed dedupe read must not become a silent duplicate write.
      throw Exception('Dedupe check failed, skipping write: $e');
    }

    // Also guard against duplicates inside this batch.
    final seen = <String>{};
    final deduped = <ObservationRecord>[];
    for (final r in records) {
      final key = _key(r.metricType, r.timestamp);
      if (key == null || existingKeys.contains(key) || !seen.add(key)) continue;
      deduped.add(r);
    }

    if (deduped.isEmpty) return;

    const batchSize = 50;
    for (var i = 0; i < deduped.length; i += batchSize) {
      final batch = deduped.skip(i).take(batchSize).map((r) => r.toJson()).toList();
      await Supabase.instance.client.from('baseline_observations').insert(batch);
    }
  }
}
