// lib/models/session_record_model.dart — Maps session_records rows for display.

class SessionRecordModel {
  final String sessionId;
  final String sessionType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? transcript;
  final String? insightDelivered;

  const SessionRecordModel({
    required this.sessionId,
    required this.sessionType,
    required this.startedAt,
    this.endedAt,
    this.transcript,
    this.insightDelivered,
  });

  factory SessionRecordModel.fromJson(Map<String, dynamic> json) {
    return SessionRecordModel(
      sessionId: json['session_id'] as String,
      sessionType: json['session_type'] as String? ?? 'morning',
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
      transcript: json['transcript'] as String?,
      insightDelivered: json['insight_delivered'] as String?,
    );
  }

  String get typeLabel {
    switch (sessionType) {
      case 'morning':
        return 'Morning check-in';
      case 'evening':
        return 'Evening review';
      case 'in_moment':
        return 'In-moment check-in';
      default:
        return 'Session';
    }
  }

  String get durationLabel {
    if (endedAt == null) return 'In progress';
    final mins = endedAt!.difference(startedAt).inMinutes;
    if (mins < 1) return 'Under 1 min';
    return '$mins min';
  }

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final diff = today.difference(sessionDay).inDays;

    final time = '${startedAt.hour.toString().padLeft(2, '0')}:'
        '${startedAt.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return 'Today at $time';
    if (diff == 1) return 'Yesterday at $time';
    return '${startedAt.day}/${startedAt.month} at $time';
  }
}
