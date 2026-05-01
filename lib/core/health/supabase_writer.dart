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
  static Future<void> batchInsert(List<ObservationRecord> records) async {
    if (records.isEmpty) return;

    // Dedup: fetch existing timestamps for this user+metric combination
    // to avoid writing duplicate rows from repeated syncs
    final userId = records.first.userId;
    final timestamps = records.map((r) => r.timestamp).toList();

    final existing = await Supabase.instance.client
        .from('baseline_observations')
        .select('metric_type, timestamp')
        .eq('user_id', userId)
        .inFilter('timestamp', timestamps);

    final existingKeys = <String>{};
    for (final row in existing as List) {
      existingKeys.add('${row['metric_type']}_${row['timestamp']}');
    }

    final deduped = records.where((r) =>
      !existingKeys.contains('${r.metricType}_${r.timestamp}')
    ).toList();

    if (deduped.isEmpty) return;

    const batchSize = 50;
    for (var i = 0; i < deduped.length; i += batchSize) {
      final batch = deduped.skip(i).take(batchSize).map((r) => r.toJson()).toList();
      await Supabase.instance.client.from('baseline_observations').insert(batch);
    }
  }
}
