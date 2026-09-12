// lib/services/pending_response_queue.dart
//
// Drains notification responses that the Android background receiver could
// not deliver. The receiver has no Supabase session; the app does, so the
// drain re-sends over the normal authenticated path.
//
// Items carry the time the user actually tapped, so a response delivered
// hours later is still attributed to the moment it happened.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/env.dart';
import 'api_client.dart';

class PendingResponseQueue {
  PendingResponseQueue._();
  static final PendingResponseQueue instance = PendingResponseQueue._();

  static const MethodChannel _channel =
      MethodChannel('com.tess224.vela_main/notification');

  bool _draining = false;

  /// Sends everything queued on the device. Safe to call on every app start;
  /// concurrent calls are collapsed.
  Future<void> drain() async {
    if (_draining || !Platform.isAndroid) return;
    _draining = true;

    try {
      final raw = await _channel.invokeMethod<String>('getPendingResponses');
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return;

      final delivered = <String>[];

      for (final entry in decoded) {
        if (entry is! Map) continue;
        final item = Map<String, dynamic>.from(entry);
        final queueId = item['queue_id'] as String?;
        if (queueId == null) continue;

        if (await _send(item)) delivered.add(queueId);
      }

      if (delivered.isNotEmpty) {
        await _channel.invokeMethod('clearPendingResponses', delivered);
        debugPrint('Pending responses: delivered ${delivered.length}');
      }
    } catch (e) {
      debugPrint('Pending response drain failed: $e');
    } finally {
      _draining = false;
    }
  }

  /// Returns true when the item should be removed from the queue — either it
  /// succeeded, or it can never succeed and retrying forever is pointless.
  Future<bool> _send(Map<String, dynamic> item) async {
    final targetType = item['target_type'] as String?;
    final targetId = item['target_id'] as String?;
    final response = item['response'] as String?;
    if (targetType == null || targetId == null || response == null) return true;

    final String url;
    final Map<String, dynamic> body;

    switch (targetType) {
      case 'nudge':
        url = '${Env.sessionPipelineUrl}/nudge/respond';
        body = {'nudge_id': targetId, 'response_value': response};
        break;
      case 'checkin':
        url = '${Env.sessionPipelineUrl}/checkin/respond';
        body = {'checkin_id': targetId, 'response_value': response};
        break;
      case 'event':
        url = '${Env.monitoringEngineUrl}/event/respond';
        body = {'event_id': targetId, 'context_response': response};
        break;
      default:
        return true; // Unknown type — drop it rather than retry forever.
    }

    try {
      await ApiClient.instance.postJson(url, body: body);
      return true;
    } on ApiException catch (e) {
      // 401 means no valid session yet — keep it and try next launch.
      // Other 4xx (already answered, deleted, malformed) will never succeed.
      if (e.statusCode == 401) return false;
      if (e.statusCode >= 400 && e.statusCode < 500) {
        debugPrint('Dropping unsendable $targetType response: ${e.message}');
        return true;
      }
      return false; // 5xx — retry later.
    } catch (e) {
      debugPrint('Queued $targetType send failed: $e');
      return false; // Network error — retry later.
    }
  }
}
