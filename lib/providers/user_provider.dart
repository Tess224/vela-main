// lib/providers/user_provider.dart — User profile and memory.
// Fetches user profile on auth, refreshes memory for dashboard.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/user_memory_model.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

// User profile — auto-fetches when userId changes
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return SupabaseService.instance.fetchUserProfile(userId);
});

// User memory — dashboard data (pattern, overnight summary, events)
final userMemoryProvider = FutureProvider<UserMemoryModel>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return UserMemoryModel.empty();

  final results = await Future.wait([
    SupabaseService.instance.fetchUserMemory(userId),
    SupabaseService.instance.fetchUnresolvedEvents(userId),
  ]);

  final memoryJson = results[0] as Map<String, dynamic>?;
  final events = results[1] as List;

  return UserMemoryModel.fromJson(
    memoryJson,
    events.cast(),
  );
});

// Whether morning session has been completed today
final morningSessionDoneProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  return SupabaseService.instance.hasSessionToday(userId, 'morning');
});

// Whether evening session has been completed today
final eveningSessionDoneProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  return SupabaseService.instance.hasSessionToday(userId, 'evening');
});