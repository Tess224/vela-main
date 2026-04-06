import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keySupabaseUrl = 'supabase_url';
  static const _keySupabaseAnon = 'supabase_anon_key';
  static const _keyUserId = 'user_id';

  Future<void> saveSupabaseCredentials({
    required String url,
    required String anonKey,
  }) async {
    await _storage.write(key: _keySupabaseUrl, value: url);
    await _storage.write(key: _keySupabaseAnon, value: anonKey);
  }

  Future<String?> getSupabaseUrl() => _storage.read(key: _keySupabaseUrl);
  Future<String?> getSupabaseAnonKey() => _storage.read(key: _keySupabaseAnon);
  Future<void> saveUserId(String userId) => _storage.write(key: _keyUserId, value: userId);
  Future<String?> getUserId() => _storage.read(key: _keyUserId);
  Future<void> clearAll() => _storage.deleteAll();
}
