Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _rows(dynamic value) =>
    (value as List? ?? []).map(_map).toList(growable: false);

String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value : null;

double? _number(dynamic value) =>
    value is num && value.isFinite ? value.toDouble() : null;

class DayActivity {
  final String id, kind, title, timeLabel, status;
  final String? goalTitle, instruction, reasoning, completionStandard;
  final DateTime startsAt;
  final DateTime? endsAt;
  final double? minutes, bufferMinutes, actualMinutes;
  final bool carriedFromEarlierPlan;
  final List<PlanStep> steps;

  DayActivity.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        kind = json['kind'] as String,
        title = json['title'] as String,
        timeLabel = json['timeLabel'] as String,
        status = json['status'] as String,
        goalTitle = _text(json['goalTitle']),
        instruction = _text(json['instruction']),
        reasoning = _text(json['reasoning']),
        completionStandard = _text(json['completionStandard']),
        startsAt = DateTime.parse(json['startsAt'] as String),
        endsAt = json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt'] as String),
        minutes = _number(json['minutes']),
        bufferMinutes = _number(json['bufferMinutes']),
        actualMinutes = _number(json['actualMinutes']),
        carriedFromEarlierPlan = json['carriedFromEarlierPlan'] == true,
        steps = _rows(json['steps'])
            .map(PlanStep.fromJson)
            .toList(growable: false);

  bool get isWork => kind == 'work';
  bool get isCompleted => status == 'Completed';
  bool get canBeNext => isWork && status == 'Planned';
}

class PlanStep {
  final String title;
  final double? minutes;

  PlanStep.fromJson(Map<String, dynamic> json)
      : title = json['title'] as String,
        minutes = _number(json['minutes']);
}

class PlanDeferred {
  final String title;
  final String? reason;

  PlanDeferred.fromJson(Map<String, dynamic> json)
      : title = json['title'] as String,
        reason = _text(json['reason']);
}

class PlanRevision {
  final String id, at, label;

  PlanRevision.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        at = json['at'] as String,
        label = json['label'] as String;
}

class DailyPlanModel {
  final String date, timezone;
  final String? planId, summary;
  final DateTime fetchedAt;
  final List<DayActivity> activities;
  final List<PlanDeferred> deferred;
  final List<PlanRevision> history;

  DailyPlanModel.fromJson(Map<String, dynamic> json)
      : date = json['date'] as String,
        timezone = json['timezone'] as String,
        planId = _text(json['planId']),
        summary = _text(json['summary']),
        fetchedAt = DateTime.parse(json['fetchedAt'] as String),
        activities = _rows(json['activities'])
            .map(DayActivity.fromJson)
            .toList(growable: false),
        deferred = _rows(json['deferred'])
            .map(PlanDeferred.fromJson)
            .toList(growable: false),
        history = _rows(json['history'])
            .map(PlanRevision.fromJson)
            .toList(growable: false);

  DayActivity? activity(String id) {
    for (final item in activities) {
      if (item.id == id) return item;
    }
    return null;
  }

  // Calendar passage never marks work completed.
  // The backend supplies the recorded status.
  DayActivity? get nextActivity {
    for (final item in activities) {
      if (item.canBeNext &&
          (item.endsAt?.isAfter(fetchedAt) ?? false)) {
        return item;
      }
    }
    return null;
  }
}
