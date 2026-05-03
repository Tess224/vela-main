// lib/providers/notification_provider.dart — Notification routing.
// Listens to FCM messages and routes to the correct screen via GoRouter.
// Intercepts data-only messages to show local notifications with action buttons.

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../services/notification_service.dart';

class NotificationRouter {
  final GoRouter router;

  NotificationRouter(this.router);

  void handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    switch (type) {
      case 'context_confirm':
        router.push('/in-moment', extra: {
          'eventId': data['event_id'],
          'calendarEventId': data['calendar_event_id'],
          'metricType': data['metric_type'],
          'interventionText': data['intervention_text'],
        });
        break;
      case 'deviation':
        router.push('/dashboard', extra: {
          'highlightEventId': data['event_id'],
        });
        break;
      case 'recovery':
        router.push('/dashboard', extra: {
          'recoveryEventId': data['event_id'],
        });
        break;
      case 'in_moment':
        router.push('/session', extra: {
          'sessionType': 'inMoment',
          'eventId': data['event_id'],
        });
        break;
      case 'ambient_checkin':
        router.go('/dashboard');
        break;
      default:
        router.go('/dashboard');
    }
  }
}

final latestNotificationProvider = StateProvider<RemoteMessage?>((ref) => null);

Future<void> initializeNotificationListeners(
  GoRouter router,
  WidgetRef ref,
) async {
  final notificationRouter = NotificationRouter(router);
  final service = NotificationService.instance;

  // Initialize local notifications for action buttons
  await service.initializeLocal();

  // Register the action tap handler — writes response to monitoring_events
  service.onActionTap = (eventId, actionId) {
    _writeEventResponse(eventId, actionId);
  };

  // 1. Terminated state
  final initialMessage = await service.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('FCM: launched from notification');
    ref.read(latestNotificationProvider.notifier).state = initialMessage;
    Future.delayed(const Duration(milliseconds: 300), () {
      notificationRouter.handleNotificationTap(initialMessage);
    });
  }

  // 2. Background state — user tapped notification while app was backgrounded
  service.onMessageOpenedApp.listen((message) {
    debugPrint('FCM: opened from background');
    ref.read(latestNotificationProvider.notifier).state = message;
    notificationRouter.handleNotificationTap(message);
  });

  // 3. Foreground state — notification arrived while app is open
  service.onMessage.listen((message) {
    debugPrint('FCM: foreground message');
    ref.read(latestNotificationProvider.notifier).state = message;

    final type = message.data['type'] as String?;
    final hasActions = message.data['actions'] != null &&
        (message.data['actions'] as String).isNotEmpty;

    if (hasActions) {
      // Show as local notification with action buttons
      service.showWithActions(message);
    } else if (type == 'context_confirm' || type == 'in_moment') {
      notificationRouter.handleNotificationTap(message);
    } else if (type == 'ambient_checkin') {
      _showCheckinDialog(router, message);
    }
  });
}

/// Write the user's action button response to monitoring_events
Future<void> _writeEventResponse(String eventId, String actionId) async {
  try {
    await Supabase.instance.client.from('monitoring_events').update({
      'context_response': actionId,
      'response_received': true,
    }).eq('event_id', eventId);
    debugPrint('Event response written: $actionId for $eventId');
  } catch (e) {
    debugPrint('Event response write failed: $e');
  }
}

// ---------------------------------------------------------------------------
// Ambient check-in dialog (unchanged)
// ---------------------------------------------------------------------------

void _showCheckinDialog(
  GoRouter router,
  RemoteMessage message,
) {
  final data = message.data;
  final checkinId = data['checkin_id'] as String?;

  final questionText = data['question_text'] as String? ??
      message.notification?.body ??
      'How are you doing?';

  List<String> options = [];
  try {
    final optionsJson = data['response_options'] as String?;
    if (optionsJson != null && optionsJson.isNotEmpty) {
      options = _parseOptionsList(optionsJson);
    }
  } catch (_) {
    options = ['Good', 'Okay', 'Not great'];
  }

  if (options.isEmpty) {
    options = ['Good', 'Okay', 'Not great'];
  }

  if (checkinId == null) return;

  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A2533),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Vela',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              questionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ...options.map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _sendCheckinResponse(checkinId, option);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    option,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            )),
          ],
        ),
      );
    },
  );
}

List<String> _parseOptionsList(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
  } catch (_) {}

  try {
    return json
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _sendCheckinResponse(String checkinId, String response) async {
  try {
    final uri = Uri.parse('${Env.sessionPipelineUrl}/checkin/respond');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'checkin_id': checkinId,
        'response_value': response,
      }),
    );
    debugPrint('Checkin response sent: $response');
  } catch (e) {
    debugPrint('Checkin response failed: $e');
  }
}