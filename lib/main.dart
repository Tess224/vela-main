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
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/health/health_data_manager.dart';
import 'core/security/secure_storage.dart';
import 'providers/notification_provider.dart';
import 'router.dart';
import 'services/notification_service.dart';

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
        final url = await SecureStorage.instance.getSupabaseUrl();
        final anonKey = await SecureStorage.instance.getSupabaseAnonKey();
        if (url == null || anonKey == null) return Future.value(false);
        await Supabase.initialize(url: url, anonKey: anonKey);
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

  // Check for credentials before deciding boot path
  final url = await SecureStorage.instance.getSupabaseUrl();
  final anonKey = await SecureStorage.instance.getSupabaseAnonKey();
  final hasCredentials = url != null && anonKey != null;

  // Workmanager init runs in both paths
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  if (hasCredentials) {
    // Full app boot — Firebase + Supabase + Riverpod + Router
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await Supabase.initialize(url: url, anonKey: anonKey);

    runApp(const ProviderScope(child: VelaApp()));
  } else {
    // Bootstrap path — show SetupScreen so user can enter credentials
    runApp(const VelaBootstrapApp());
  }
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
  }

  void _handleDeepLink(Uri uri) async {
    if (uri.host != 'phantom-callback') return;

    if (uri.path.contains('connect')) {
      final pubkey = PhantomService.instance.parseConnectResponse(uri);
      if (pubkey != null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await SupabaseService.instance.updateUserProfile(userId, {
            'solana_wallet': pubkey,
          });
        }
      }
    } else if (uri.path.contains('sign')) {
      final signature = PhantomService.instance.parseSignResponse(uri);
      if (signature != null) {
        await SubscriptionService.instance.verifyPayment(signature);
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
      theme: ThemeData.dark(),
      routerConfig: router,
    );
  }
}

// ---------------------------------------------------------------------------
// Bootstrap app — runs when no credentials exist (Build 2 flow preserved)
// ---------------------------------------------------------------------------

class VelaBootstrapApp extends StatelessWidget {
  const VelaBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vela',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SetupScreen(),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  final List<String> _logs = [];
  bool _loading = false;

  void _log(String message) {
    setState(() => _logs.add(message));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndSync() async {
    final url = _urlController.text.trim();
    final anonKey = _anonKeyController.text.trim();

    if (url.isEmpty || !url.startsWith('https://')) {
      _log('❌ URL must start with https://');
      return;
    }
    if (anonKey.isEmpty || anonKey.length < 20) {
      _log('❌ Please enter a valid anon key.');
      return;
    }

    setState(() { _loading = true; _logs.clear(); });

    try {
      _log('💾 Saving credentials...');
      await SecureStorage.instance.saveSupabaseCredentials(
          url: url, anonKey: anonKey);

      _log('🔌 Connecting to Supabase...');
      await Supabase.initialize(url: url, anonKey: anonKey);

      _log('🔍 Requesting health permissions...');
      final manager = HealthDataManager();
      final granted = await manager.requestPermissions();

      if (!granted) {
        _log('❌ Health permissions denied. Please grant in Settings.');
        setState(() => _loading = false);
        return;
      }

      _log('✅ Permissions granted.');

      const testUserId = 'a4d61682-d99b-4862-a323-a8c776d53ed2';
      await SecureStorage.instance.saveUserId(testUserId);

      await manager.syncHealthData(
        userId: testUserId,
        onLog: _log,
      );

      await Workmanager().registerPeriodicTask(
        kHealthSyncTask, kHealthSyncTask,
        frequency: const Duration(minutes: 15),
        inputData: {'user_id': testUserId},
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      _log('🔄 Background sync registered — every 15 minutes.');
      _log('');
      _log('✅ Setup complete. Restart the app to enter the main flow.');
      setState(() => _loading = false);
    } catch (e) {
      _log('❌ Error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('Vela',
                  style: TextStyle(
                      color: Color(0xFFC9A6FF),
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('First-time setup',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Supabase URL',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _anonKeyController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Supabase Anon Key',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveAndSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Connect & Sync',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(_logs[index],
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
