import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/health/health_data_manager.dart';
import 'core/security/secure_storage.dart';

const kHealthSyncTask = 'health_sync_task';

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
  final url = await SecureStorage.instance.getSupabaseUrl();
  final anonKey = await SecureStorage.instance.getSupabaseAnonKey();
  if (url != null && anonKey != null) {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const VelaApp());
}

class VelaApp extends StatelessWidget {
  const VelaApp({super.key});

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
              const Text('Build 2 — Health Data Setup',
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
