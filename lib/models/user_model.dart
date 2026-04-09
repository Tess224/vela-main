// lib/models/user_model.dart — User profile model.
// Maps to the users table in Supabase.

class UserModel {
  final String userId;
  final String? firstName;
  final String? occupationType;
  final String? workStartTime;
  final String? workEndTime;
  final String? sleepTime;
  final bool onboardingComplete;
  final int? signalTier;
  final String? primaryHrvSource;
  final String? subscriptionTier;

  const UserModel({
    required this.userId,
    this.firstName,
    this.occupationType,
    this.workStartTime,
    this.workEndTime,
    this.sleepTime,
    this.onboardingComplete = false,
    this.signalTier,
    this.primaryHrvSource,
    this.subscriptionTier,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String?,
      occupationType: json['occupation_type'] as String?,
      workStartTime: json['work_start_time'] as String?,
      workEndTime: json['work_end_time'] as String?,
      sleepTime: json['sleep_time'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      signalTier: json['signal_tier'] as int?,
      primaryHrvSource: json['primary_hrv_source'] as String?,
      subscriptionTier: json['subscription_tier'] as String?,
    );
  }

  UserModel copyWith({
    String? firstName,
    String? occupationType,
    String? workStartTime,
    String? workEndTime,
    String? sleepTime,
    bool? onboardingComplete,
    int? signalTier,
    String? primaryHrvSource,
  }) {
    return UserModel(
      userId: userId,
      firstName: firstName ?? this.firstName,
      occupationType: occupationType ?? this.occupationType,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      sleepTime: sleepTime ?? this.sleepTime,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      signalTier: signalTier ?? this.signalTier,
      primaryHrvSource: primaryHrvSource ?? this.primaryHrvSource,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
    );
  }
}