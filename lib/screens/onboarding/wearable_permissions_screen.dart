// lib/screens/onboarding/wearable_permissions_screen.dart
// Requests Health Connect permissions via the Flutter health package.
// Uses the existing Build 2 HealthDataManager.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/health/health_data_manager.dart';

class WearablePermissionsScreen extends StatefulWidget {
  const WearablePermissionsScreen({super.key});

  @override
  State<WearablePermissionsScreen> createState() => _WearablePermissionsScreenState();
}

class _WearablePermissionsScreenState extends State<WearablePermissionsScreen> {
  bool _loading = false;
  bool _denied = false;

  Future<void> _requestPermissions() async {
    setState(() {
      _loading = true;
      _denied = false;
    });

    try {
      final manager = HealthDataManager();
      final granted = await manager.requestPermissions();

      if (granted && mounted) {
        context.go('/onboarding/profile');
      } else {
        setState(() => _denied = true);
      }
    } catch (e) {
      setState(() => _denied = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text(
                'To build your personal model,',
                style: TextStyle(color: Colors.white, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'we need access to your health data.',
                style: TextStyle(color: Colors.white, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _PermissionItem(label: 'Heart rate variability — your recovery signal'),
              const SizedBox(height: 12),
              _PermissionItem(label: 'Resting heart rate — cardiovascular baseline'),
              const SizedBox(height: 12),
              _PermissionItem(label: 'Sleep stages — overnight recovery quality'),
              const SizedBox(height: 12),
              _PermissionItem(label: 'Blood oxygen — respiratory health'),
              const SizedBox(height: 12),
              _PermissionItem(label: 'Respiratory rate — sleep quality indicator'),
              if (_denied) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Health permissions were not granted. Vela needs this data to work. '
                    'On Android 12, permissions may be limited — that\'s okay, we\'ll work with what\'s available.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
                  ),
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E75B6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _denied ? 'Try again' : 'Grant access',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              if (_denied) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/onboarding/profile'),
                  child: Text(
                    'Continue without full access',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final String label;
  const _PermissionItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF2E75B6), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}