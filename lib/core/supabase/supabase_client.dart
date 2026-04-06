import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientProvider {
  SupabaseClientProvider._();
  static SupabaseClient get client => Supabase.instance.client;
  static String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;
}
