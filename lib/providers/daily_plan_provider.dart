import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import '../models/daily_plan_model.dart';
import '../services/api_client.dart';
import 'auth_provider.dart';

final dailyPlanProvider =
    FutureProvider.autoDispose<DailyPlanModel>((ref) async {
  final userId = ref.watch(currentUserIdProvider) ??
      Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    throw ApiException(401, 'Sign in to view your plan.');
  }

  // Home, Plan, and activity details share this response.
  final timer = Timer(
    const Duration(minutes: 1),
    ref.invalidateSelf,
  );

  ref.onDispose(timer.cancel);

  final base = Env.plannerUrl.replaceFirst(RegExp(r'/$'), '');
  final json = await ApiClient.instance.getJson('$base/daily-plan');

  return DailyPlanModel.fromJson(json);
});
