// lib/services/supabase_service.dart — Database reads and writes.
// All Supabase queries live here. No direct Supabase calls from UI code.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/monitoring_event_model.dart';
import '../config/constants.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get currentUserId => _client.auth.currentUser?.id;

  // --- Auth ---

  Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // --- User Profile ---

  Future<UserModel?> fetchUserProfile(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await _client.from('users').update(updates).eq('user_id', userId);
  }

  Future<void> createUserProfile(String userId, Map<String, dynamic> profile) async {
    await _client.from('users').insert({
      'user_id': userId,
      ...profile,
    });
  }

  // --- User Memory (for dashboard) ---

  Future<Map<String, dynamic>?> fetchUserMemory(String userId) async {
    final data = await _client
        .from('user_memory')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return data;
  }

  // --- Monitoring Events ---

  Future<List<MonitoringEventModel>> fetchUnresolvedEvents(String userId) async {
    final since = DateTime.now()
        .subtract(Duration(hours: AppConstants.unresolvedEventsMaxAge))
        .toIso8601String();

    final data = await _client
        .from('monitoring_events')
        .select()
        .eq('user_id', userId)
        .isFilter('resolution', null)
        .gte('detected_at', since)
        .order('detected_at', ascending: false)
        .limit(5);

    return (data as List).map((row) => MonitoringEventModel.fromJson(row)).toList();
  }

  Future<void> writeContextResponse(String eventId, String response) async {
    await _client.from('monitoring_events').update({
      'context_response': response,
      'response_received': true,
    }).eq('event_id', eventId);
  }

  // --- Sessions ---

  Future<bool> hasSessionToday(String userId, String sessionType) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

    final data = await _client
        .from('session_transcripts')
        .select('session_id')
        .eq('user_id', userId)
        .eq('session_type', sessionType)
        .gte('started_at', startOfDay)
        .limit(1);

    return (data as List).isNotEmpty;
  }

  // --- Device Tokens ---

  Future<void> upsertDeviceToken(String userId, String token) async {
    await _client.from('device_tokens').upsert({
      'user_id': userId,
      'fcm_token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id, fcm_token');
  }
}