// lib/services/notification_service.dart — FCM setup and token registration.
// Registers device token on launch, listens for incoming notifications.
// Routing logic lives in notification_provider.dart.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Register FCM token for push notifications
  Future<void> registerToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('FCM: no token available');
        return;
      }
      await SupabaseService.instance.upsertDeviceToken(userId, token);
      debugPrint('FCM: token registered');
    } catch (e) {
      debugPrint('FCM: token registration failed: $e');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await SupabaseService.instance.upsertDeviceToken(userId, newToken);
        debugPrint('FCM: token refreshed');
      } catch (e) {
        debugPrint('FCM: token refresh failed: $e');
      }
    });
  }

  // Request notification permissions (Android 13+ requires explicit permission)
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // Get the initial message (app opened from terminated state via notification)
  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  // Stream of messages when app is in foreground
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  // Stream of messages when app is opened from background
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}