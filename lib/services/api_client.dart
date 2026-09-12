// lib/services/api_client.dart
// Single place where backend calls get their auth token and error handling.
// Every Railway service requires a Supabase JWT on POST. http.post does NOT
// throw on 401, so callers must go through here or failures stay invisible.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const Duration _timeout = Duration(seconds: 30);

  // Guards against two callers refreshing at the same time, which can
  // invalidate the refresh token.
  Future<String>? _refreshInFlight;

  Future<String> _accessToken() async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;

    if (session == null) {
      throw ApiException(401, 'Not signed in');
    }
    if (!session.isExpired) {
      return session.accessToken;
    }

    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String> _refresh() async {
    try {
      final result = await Supabase.instance.client.auth.refreshSession();
      final token = result.session?.accessToken;
      if (token == null) throw ApiException(401, 'Session expired');
      return token;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(401, 'Session refresh failed: $e');
    }
  }

  Future<Map<String, dynamic>> getJson(String url) => _send('GET', url);

  Future<Map<String, dynamic>> postJson(
    String url, {
    Map<String, dynamic>? body,
  }) =>
      _send('POST', url, body: body);

  Future<Map<String, dynamic>> deleteJson(
    String url, {
    Map<String, dynamic>? body,
  }) =>
      _send('DELETE', url, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _accessToken();
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : utf8.encode(jsonEncode(body));

    http.Response resp;
    switch (method) {
      case 'GET':
        resp = await http.get(uri, headers: headers).timeout(_timeout);
        break;
      case 'POST':
        resp = await http
            .post(uri, headers: headers, body: encoded)
            .timeout(_timeout);
        break;
      case 'DELETE':
        resp = await http
            .delete(uri, headers: headers, body: encoded)
            .timeout(_timeout);
        break;
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(resp.statusCode, _errorMessage(resp));
    }

    if (resp.bodyBytes.isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
  }

  String _errorMessage(http.Response resp) {
    if (resp.bodyBytes.isEmpty) return 'HTTP ${resp.statusCode}';
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'HTTP ${resp.statusCode}';
  }
}
