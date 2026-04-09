// lib/models/monitoring_event_model.dart — Monitoring event model.
// Maps to monitoring_events table for dashboard display and notification routing.

class MonitoringEventModel {
  final String eventId;
  final String metricType;
  final double deviationScore;
  final String classification;
  final String? contextResponse;
  final bool notificationSent;
  final bool responseReceived;
  final String? resolution;
  final bool fedToSession;
  final String? calendarEventId;
  final DateTime detectedAt;

  const MonitoringEventModel({
    required this.eventId,
    required this.metricType,
    required this.deviationScore,
    required this.classification,
    this.contextResponse,
    this.notificationSent = false,
    this.responseReceived = false,
    this.resolution,
    this.fedToSession = false,
    this.calendarEventId,
    required this.detectedAt,
  });

  factory MonitoringEventModel.fromJson(Map<String, dynamic> json) {
    return MonitoringEventModel(
      eventId: json['event_id'] as String,
      metricType: json['metric_type'] as String,
      deviationScore: (json['deviation_score'] as num).toDouble(),
      classification: json['classification'] as String,
      contextResponse: json['context_response'] as String?,
      notificationSent: json['notification_sent'] as bool? ?? false,
      responseReceived: json['response_received'] as bool? ?? false,
      resolution: json['resolution'] as String?,
      fedToSession: json['fed_to_session'] as bool? ?? false,
      calendarEventId: json['calendar_event_id'] as String?,
      detectedAt: DateTime.parse(json['detected_at'] as String),
    );
  }

  bool get isUnresolved => resolution == null;

  String get metricLabel {
    const labels = {
      'hrv': 'Recovery signal',
      'resting_hr': 'Resting heart rate',
      'stress': 'Stress levels',
      'spo2': 'Blood oxygen',
      'respiratory_rate': 'Respiratory rate',
      'sleep_hours': 'Sleep',
    };
    return labels[metricType] ?? metricType;
  }
}