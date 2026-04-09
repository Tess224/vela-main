import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/session_model.dart';

class SessionPipelineService {
  Future<String> fetchBrief(String sessionType) async {
    final userId = _getUserId();
    final uri = Uri.parse('${Env.sessionPipelineUrl}/brief');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'session_type': sessionType,
      }),
    );

    if (response.statusCode != 200) {
      throw SessionPipelineException(
        'Brief fetch failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final brief = json['brief'] as String?;

    if (brief == null || brief.trim().isEmpty) {
      throw SessionPipelineException('Brief returned empty response');
    }

    return brief;
  }

  Stream<String> sendMessage(
    String text, {
    required String sessionType,
  }) async* {
    final userId = _getUserId();
    final uri = Uri.parse('${Env.sessionPipelineUrl}/session');

    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'text/event-stream');

    request.write(jsonEncode({
      'user_id': userId,
      'session_type': sessionType,
      'message': text,
    }));

    final response = await request.close();

    if (response.statusCode != 200) {
      client.close();
      throw SessionPipelineException(
        'Session pipeline failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    await for (final chunk in response.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') {
            client.close();
            return;
          }
          yield data;
        }
      }
    }

    client.close();
  }

  Future<void> endSession({
    required List<Exchange> exchanges,
    required String sessionType,
  }) async {
    final userId = _getUserId();
    final uri = Uri.parse('${Env.sessionPipelineUrl}/session/end');

    final transcript = exchanges.map((e) {
      final parts = <String>[];
      if (e.userText.isNotEmpty) parts.add('User: ${e.userText}');
      if (e.avatarText.isNotEmpty) parts.add('Vela: ${e.avatarText}');
      return parts.join('\n');
    }).join('\n\n');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'session_type': sessionType,
        'transcript': transcript,
      }),
    );

    if (response.statusCode != 200) {
      throw SessionPipelineException(
        'End session failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  String _getUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw SessionPipelineException('User not authenticated');
    }
    return user.id;
  }
}

class SessionPipelineException implements Exception {
  final String message;
  final int? statusCode;

  SessionPipelineException(this.message, {this.statusCode});

  @override
  String toString() => 'SessionPipelineException: $message';
}
