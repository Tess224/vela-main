// lib/services/session_pipeline_service.dart — HTTP calls to Railway.
// Handles session start (brief), message exchange, and post-session processing.
// All API keys stay on Railway — Flutter only sends user data.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../config/constants.dart';
import '../models/session_model.dart';

class SessionPipelineService {
  SessionPipelineService._();
  static final SessionPipelineService instance = SessionPipelineService._();

  final _httpClient = http.Client();

  // Start a session — calls reasoning layer, returns brief
  Future<Map<String, dynamic>> startSession({
    required String userId,
    required SessionType sessionType,
    Map<String, dynamic>? deviationContext,
  }) async {
    final typeStr = sessionType == SessionType.morning
        ? 'morning'
        : sessionType == SessionType.evening
            ? 'evening'
            : 'in_moment';

    final body = {
      'user_id': userId,
      'session_type': typeStr,
      if (deviationContext != null) 'deviation_context': deviationContext,
    };

    final response = await _httpClient
        .post(
          Uri.parse('${Env.sessionPipelineUrl}/session'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(AppConstants.httpTimeout);

    if (response.statusCode != 200) {
      throw Exception('Session start failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Send a message in an active session — returns Claude's response as a stream
  Stream<String> sendMessage({
    required String userId,
    required String sessionId,
    required String text,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${Env.sessionPipelineUrl}/session/message'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'user_id': userId,
      'session_id': sessionId,
      'message': text,
    });

    final streamedResponse = await _httpClient.send(request).timeout(AppConstants.httpTimeout);

    if (streamedResponse.statusCode != 200) {
      throw Exception('Message send failed: ${streamedResponse.statusCode}');
    }

    // SSE stream — each line is a token or event
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          yield data;
        }
      }
    }
  }

  // End session — triggers transcript extraction + pattern engine
  Future<void> endSession({
    required String userId,
    required String sessionId,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('${Env.sessionPipelineUrl}/session/end'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'session_id': sessionId,
          }),
        )
        .timeout(AppConstants.httpTimeout);

    if (response.statusCode != 200) {
      throw Exception('Session end failed: ${response.statusCode}');
    }
  }

  void dispose() => _httpClient.close();
}