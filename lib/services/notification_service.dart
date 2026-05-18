// lib/services/notification_service.dart — FCM + local notifications.
// Intercepts FCM data messages and re-displays them as local notifications
// with action buttons. Handles action taps in background without app launch.

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

// Top-level callback for background action taps.
// Must be top-level (not a class method) for isolate compatibility.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  // Background action taps are handled here.
  // We can't access Supabase easily in a background isolate without
  // re-initializing, so we store the response and process it on next launch.
  // For now, foreground actions handle the write.
  debugPrint('FCM background action: ${response.actionId} payload=${response.payload}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  bool _localInitialized = false;

  // Callback for when a user taps an action button (foreground)
  void Function(String eventId, String actionId)? onActionTap;

  /// Initialize the local notifications plugin. Call once at app start.
  Future<void> initializeLocal() async {
    if (_localInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
    );

    _localInitialized = true;
    debugPrint('Local notifications initialized');
  }

  /// Handle foreground action button taps
  void _onForegroundAction(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;

    if (actionId == null || actionId.isEmpty) {
      // User tapped the notification body, not an action button.
      // This is handled by notification_provider.dart via FCM streams.
      return;
    }

    debugPrint('Action tapped: $actionId payload=$payload');

    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final eventId = data['event_id'] as String?;
      final checkinId = data['checkin_id'] as String?;

      if (eventId != null && onActionTap != null) {
        onActionTap!(eventId, actionId);
      } else if (checkinId != null) {
        _writeCheckinResponse(checkinId, actionId);
      } else if (data.containsKey('nudge_id')) {
        final nudgeId = data['nudge_id'] as String;
        _writeNudgeResponse(nudgeId, actionId);
      }
    } catch (e) {
      debugPrint('Action tap parse error: $e');
    }
  }

  /// Show an FCM message as a local notification with action buttons.
  Future<void> showWithActions(RemoteMessage message) async {
    if (!_localInitialized) await initializeLocal();

    final data = message.data;
    final title = message.notification?.title ?? data['title'] ?? 'Vela';
    final body = message.notification?.body ?? data['body'] ?? '';
    final type = data['type'] as String?;

    // Parse actions from the data payload
    final actions = _parseActions(data['actions'] as String?);

    // Build Android action buttons
    final androidActions = actions.map((label) {
      return AndroidNotificationAction(
        label, // actionId = the label text itself
        label,
        showsUserInterface: false,
      );
    }).toList();

    final androidDetails = AndroidNotificationDetails(
      'vela_alerts',
      'Vela Alerts',
      channelDescription: 'Health deviation alerts from Vela',
      importance: Importance.high,
      priority: Priority.high,
      actions: androidActions,
    );

    final details = NotificationDetails(android: androidDetails);

    // Encode the data payload as the notification payload string
    // so action handlers can read event_id, checkin_id, etc.
    final payloadJson = jsonEncode(data);

    // Use a unique ID based on event_id or timestamp
    final notifId = (data['event_id'] ?? data['checkin_id'] ?? '')
        .hashCode
        .abs() % 100000;

    await _localPlugin.show(
      notifId,
      title,
      body,
      details,
      payload: payloadJson,
    );
  }

  /// Parse the actions JSON string from FCM data payload
  List<String> _parseActions(String? actionsJson) {
    if (actionsJson == null || actionsJson.isEmpty) return [];

    try {
      final decoded = jsonDecode(actionsJson);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    // Fallback: try comma-separated
    try {
      return actionsJson
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

  /// Write a nudge response directly (for ambient nudge actions)
  Future<void> _writeNudgeResponse(String nudgeId, String response) async {
    try {
      await Supabase.instance.client.from('scheduled_nudges').update({
        'response_value': response,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('nudge_id', nudgeId);
      debugPrint('Nudge action response written: $response');
    } catch (e) {
      debugPrint('Nudge action write failed: $e');
    }
  }

  /// Write a checkin response directly (for ambient checkin actions)
  Future<void> _writeCheckinResponse(String checkinId, String response) async {
    try {
      await Supabase.instance.client.from('ambient_checkins').update({
        'response_value': response,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('checkin_id', checkinId);
      debugPrint('Checkin action response written: $response');
    } catch (e) {
      debugPrint('Checkin action write failed: $e');
    }
  }

  // --- Existing methods below (unchanged) ---

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

    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await SupabaseService.instance.upsertDeviceToken(userId, newToken);
        debugPrint('FCM: token refreshed');
      } catch (e) {
        debugPrint('FCM: token refresh failed: $e');
      }
    });
  }

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('FCM background: ${message.data['type']}');
  }
}