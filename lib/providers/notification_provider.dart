// lib/providers/notification_provider.dart — Notification routing.
// Listens to FCM messages and routes to the correct screen via GoRouter.
// Handles foreground, background, and terminated-state notifications.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      default:
        router.go('/dashboard');
    }
  }
}

// Holds the latest notification payload for the UI to react to
final latestNotificationProvider = StateProvider<RemoteMessage?>((ref) => null);

/// Initializes FCM listeners and routes incoming notifications.
/// Call this once after the router is built (in main.dart or a wrapper widget).
/// Returns a function that can be called to dispose subscriptions if needed.
Future<void> initializeNotificationListeners(
  GoRouter router,
  WidgetRef ref,
) async {
  final notificationRouter = NotificationRouter(router);
  final service = NotificationService.instance;

  // 1. Terminated state — app launched from a notification tap
  final initialMessage = await service.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('FCM: launched from notification');
    ref.read(latestNotificationProvider.notifier).state = initialMessage;
    // Delay slightly to let router finish building
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
  // For class_3 (context_confirm) and class_4 (in_moment), route immediately.
  // For class_2 (deviation) and recovery, just store — user sees it on next dashboard visit.
  service.onMessage.listen((message) {
    debugPrint('FCM: foreground message');
    ref.read(latestNotificationProvider.notifier).state = message;

    final type = message.data['type'] as String?;
    if (type == 'context_confirm' || type == 'in_moment') {
      notificationRouter.handleNotificationTap(message);
    }
  });
}
