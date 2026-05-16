// lib/models/goal_model.dart — User goal data model.

class GoalModel {
  final String goalId;
  final String userId;
  final String title;
  final String category;
  final String timeframe;
  final int priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  GoalModel({
    required this.goalId,
    required this.userId,
    required this.title,
    required this.category,
    required this.timeframe,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      goalId: json['goal_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      timeframe: json['timeframe'] as String,
      priority: json['priority'] as int? ?? 1,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'performance':
        return 'Performance';
      case 'recovery':
        return 'Recovery';
      case 'health':
        return 'Health';
      case 'skill':
        return 'Skill';
      case 'habit':
        return 'Habit';
      case 'lifestyle':
        return 'Lifestyle';
      default:
        return category;
    }
  }

  String get timeframeLabel {
    switch (timeframe) {
      case 'short_term':
        return 'Short-term';
      case 'mid_term':
        return 'Mid-term';
      case 'long_term':
        return 'Long-term';
      default:
        return timeframe;
    }
  }

  bool get isActive => status == 'active';
}
