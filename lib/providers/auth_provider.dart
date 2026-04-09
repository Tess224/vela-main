// lib/providers/auth_provider.dart — Supabase auth state.
// Manual riverpod — no code generation.
// Exposes auth state as a StreamProvider for the entire app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

// Current auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.instance.authStateChanges;
});

// Current user ID (null if not authenticated)
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenData((state) => state.session?.user.id).value;
});

// Whether the user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return userId != null;
});