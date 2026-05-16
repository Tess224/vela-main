// lib/providers/goals_provider.dart — Goals state management.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal_model.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

final userGoalsProvider = FutureProvider<List<GoalModel>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final data = await SupabaseService.instance.fetchUserGoals(userId);
  return data.map((json) => GoalModel.fromJson(json)).toList();
});
