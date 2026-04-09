// lib/models/user_memory_model.dart — Dashboard data model.
// Aggregates user_memory structured context + recent monitoring events.

import 'monitoring_event_model.dart';

class UserMemoryModel {
  final String? topActivePattern;
  final String? overnightSummary;
  final String? communicationLevel;
  final String? wowMoment;
  final List<MonitoringEventModel> unresolvedEvents;
  final DateTime? lastSessionAt;

  const UserMemoryModel({
    this.topActivePattern,
    this.overnightSummary,
    this.communicationLevel,
    this.wowMoment,
    this.unresolvedEvents = const [],
    this.lastSessionAt,
  });

  factory UserMemoryModel.empty() => const UserMemoryModel();

  factory UserMemoryModel.fromJson(
    Map<String, dynamic>? memoryJson,
    List<MonitoringEventModel> events,
  ) {
    if (memoryJson == null) {
      return UserMemoryModel(unresolvedEvents: events);
    }

    // Parse structured_context JSON from user_memory
    final context = memoryJson['structured_context'];
    Map<String, dynamic>? parsed;
    if (context is Map<String, dynamic>) {
      parsed = context;
    }

    return UserMemoryModel(
      topActivePattern: parsed?['top_active_pattern'] as String?,
      overnightSummary: parsed?['overnight_summary'] as String?,
      communicationLevel: memoryJson['communication_level'] as String?,
      wowMoment: parsed?['wow_moment'] as String?,
      unresolvedEvents: events,
      lastSessionAt: memoryJson['last_session_at'] != null
          ? DateTime.tryParse(memoryJson['last_session_at'] as String)
          : null,
    );
  }

  bool get hasActivePattern => topActivePattern != null;
  bool get hasOvernightSummary => overnightSummary != null;
  bool get hasUnresolvedEvents => unresolvedEvents.isNotEmpty;
}