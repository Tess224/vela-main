// lib/services/session_pipeline_service.dart
//
// Build 6.3 voice pipeline client — talks to the Railway session pipeline
// over the new streaming endpoints (/session/stream and /session/end).
//
// Contract:
// - Turn 1: call sendMessage() with empty history and no sessionId. The first
//   SSE event fires onSessionStart with the server-assigned session_id. Yield
//   tokens until [DONE].
// - Turn 2+: call sendMessage() with the sessionId and the accumulated
//   conversation history. Server loads cached brief, streams Claude response.
// - End: call endSession() with the sessionId and full transcript. Server
//   runs post-session extraction, correlations, pattern engine trigger.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Role in a conversation turn — matches Anthropic's format.
enum ConversationRole { user, assistant }

/// A single turn in the conversation history sent to the backend.
class ConversationTurn {
  final ConversationRole role;
  final String content;

  const ConversationTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {
        'role': role == ConversationRole.user ? 'user' : 'assistant',
        'content': content,
      };
}

/// Metadata emitted at the start of a streaming session turn.
class SessionMetadata {
  final String sessionId;
  final int sessionNumber;

  const SessionMetadata({required this.sessionId, required this.sessionNumber});
}

class SessionPipelineService {
  /// Streams a turn of a session. On turn 1 (no sessionId), the backend builds
  /// and caches a SessionBrief and assigns a session_id. On turn 2+, the cached
  /// brief is loaded by sessionId and no rebuild happens.
  ///
  /// Yields text tokens as they stream from Claude. Fires [onSessionStart] once
  /// when the session metadata event arrives (which is always the first SSE
  /// event from the server).
  Stream<String> sendMessage(
    String text, {
    required String sessionType,
    required void Function(SessionMetadata metadata) onSessionStart,
    String? sessionId,
    List<ConversationTurn> conversationHistory = const [],
  }) async* {
    final userId = _getUserId();
    final uri = Uri.parse('${Env.sessionPipelineUrl}/session/stream');

    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json; charset=utf-8');
    request.headers.set('Accept', 'text/event-stream');

    final body = <String, dynamic>{
      'user_id': userId,
      'session_type': sessionType,
      'message': text,
      'conversation_history':
          conversationHistory.map((t) => t.toJson()).toList(),
    };
    if (sessionId != null) {
      body['session_id'] = sessionId;
    }

    // Encode to UTF-8 bytes ourselves and add() them. Using request.write()
    // would try to encode the string with HttpClientRequest's default encoding
    // (latin1), which rejects em-dashes, curly quotes, and any character above
    // 0xFF — exactly the kind of characters Claude's responses contain.
    final bodyBytes = utf8.encode(jsonEncode(body));
    request.headers.contentLength = bodyBytes.length;
    request.add(bodyBytes);
    final response = await request.close();

    if (response.statusCode != 200) {
      client.close();
      throw SessionPipelineException(
        'Session stream failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    // SSE parser state machine:
    // - Events are terminated by blank lines (\n\n).
    // - Each event is a sequence of "field: value" lines.
    // - We track the current "event:" name so we can distinguish metadata
    //   events from token data events.
    final buffer = StringBuffer();
    String? currentEventName;

    try {
      await for (final chunk in response.transform(utf8.decoder)) {
        buffer.write(chunk);

        // Process complete lines (separated by \n). We don't wait for \n\n
        // boundaries here because 'data:' lines can be consumed immediately.
        while (true) {
          final bufferStr = buffer.toString();
          final newlineIdx = bufferStr.indexOf('\n');
          if (newlineIdx == -1) break;

          final line = bufferStr.substring(0, newlineIdx);
          final remaining = bufferStr.substring(newlineIdx + 1);
          buffer.clear();
          buffer.write(remaining);

          if (line.isEmpty) {
            // Blank line = end of SSE event. Reset event name.
            currentEventName = null;
            continue;
          }

          if (line.startsWith('event: ')) {
            currentEventName = line.substring(7).trim();
            continue;
          }

          if (line.startsWith('data: ')) {
            final data = line.substring(6);

            if (data == '[DONE]') {
              return;
            }

            if (currentEventName == 'session') {
              // Metadata event — parse the session_id and fire callback
              try {
                final meta = jsonDecode(data) as Map<String, dynamic>;
                onSessionStart(SessionMetadata(
                  sessionId: meta['session_id'] as String,
                  sessionNumber: (meta['session_number'] as num).toInt(),
                ));
              } catch (_) {
                // Malformed metadata — log but don't crash the stream
                // ignore: avoid_print
                print('SSE: failed to parse session metadata: $data');
              }
              continue;
            }

            if (currentEventName == 'error') {
              throw SessionPipelineException('Server stream error: $data');
            }

            // Default: text token delta. Un-escape \n and \\ back to literals.
            final unescaped = _unescape(data);
            yield unescaped;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Un-escapes SSE-safe text back to real characters.
  /// Server sends `\\` for a real backslash and `\n` for a real newline.
  /// Order matters — unescape `\n` first using a marker, then collapse `\\`.
  String _unescape(String s) {
    // Use a placeholder that can't appear in real text to avoid collision
    const marker = '\x00BACKSLASH\x00';
    return s
        .replaceAll(r'\\', marker)
        .replaceAll(r'\n', '\n')
        .replaceAll(marker, r'\');
  }

  /// Ends a streaming session — saves transcript and runs post-processing.
  Future<void> endSession({
    required String sessionId,
    required String transcript,
  }) async {
    final uri = Uri.parse('${Env.sessionPipelineUrl}/session/end');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: utf8.encode(jsonEncode({
        'session_id': sessionId,
        'transcript': transcript,
      })),
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
