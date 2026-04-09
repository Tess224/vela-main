// lib/providers/notification_provider.dart — Notification routing.
// Listens to FCM messages and routes to the correct screen via GoRouter.
// Handles foreground, background, and terminated-state notifications.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          'sessionType': 'in_moment',
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