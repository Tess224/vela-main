// lib/main.dart — App entry point.
// Boot strategy:
//   1. If Supabase credentials exist in secure storage → init full app
//      (Firebase + Supabase + Riverpod + GoRouter + FCM listeners).
//   2. If credentials are missing → show SetupScreen bootstrap (Build 2 flow).
//      After credentials are saved, user restarts the app into the full flow.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'core/health/health_data_manager.dart';
import 'core/security/secure_storage.dart';
import 'providers/notification_provider.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'config/env.dart';

import 'package:app_links/app_links.dart';
import 'services/phantom_service.dart';
import 'services/subscription_service.dart';

const kHealthSyncTask = 'health_sync_task';

 @pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.data['type']}');
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kHealthSyncTask) {
      try {
        final userId = inputData?['user_id'] as String?;
        if (userId == null || userId.isEmpty) return Future.value(false);
        await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
        await HealthDataManager().syncHealthData(userId: userId);
        return Future.value(true);
      } catch (_) {
        return Future.value(false);
      }
    }
    return Future.value(false);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: VelaApp()));
}

// ---------------------------------------------------------------------------
// Full app — runs after credentials are saved
// ---------------------------------------------------------------------------

class VelaApp extends ConsumerStatefulWidget {
  const VelaApp({super.key});

  @override
  ConsumerState<VelaApp> createState() => _VelaAppState();
}

class _VelaAppState extends ConsumerState<VelaApp> {
  bool _notificationsInitialized = false;
  AppLinks? _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _appLinks!.uriLinkStream.listen(_handleDeepLink);
    _checkInitialLink();
  }

  Future<void> _checkInitialLink() async {
    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Initial link error: $e');
    }
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.host != 'phantom-callback') return;

    if (uri.path.contains('connect')) {
      debugPrint('Phantom connect callback params: ${uri.queryParameters}');
      final pubkey = PhantomService.instance.parseConnectResponse(uri);
      if (pubkey != null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await Supabase.instance.client
            .from('users')
            .update({'solana_wallet': pubkey})
            .eq('user_id', userId);
          PhantomService.instance.lastConnectedWallet.value = pubkey;
        }
      }
    } else if (uri.path.contains('sign')) {
      final signature = PhantomService.instance.parseSignResponse(uri);
      if (signature != null) {
        final success = await SubscriptionService.instance.verifyPayment(signature);
        if (success) {
          PhantomService.instance.lastPaymentSignature.value = signature;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Initialize FCM listeners once after first frame
    if (!_notificationsInitialized) {
      _notificationsInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await NotificationService.instance.requestPermission();
          await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
          await initializeNotificationListeners(router, ref);

          // Register device token if user is signed in
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            await NotificationService.instance.registerToken(userId);
            // Sync health data on every app boot (no permission request —
            // permissions are handled during onboarding)
            final manager = HealthDataManager();
            await manager.syncHealthData(userId: userId);
          }
        } catch (e) {
          debugPrint('Notification init error: $e');
        }
      });
    }

    return MaterialApp.router(
      title: 'Vela',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF000000)),
      ),
      routerConfig: router,
    );
  }
}

