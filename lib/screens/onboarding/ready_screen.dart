// lib/screens/onboarding/ready_screen.dart — Setup complete.
// Sets onboarding_complete = true, registers FCM token, sends to dashboard.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';

class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Mark onboarding complete
    await SupabaseService.instance.updateUserProfile(userId, {
      'onboarding_complete': true,
    });

    // Request notification permission and register FCM token
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.registerToken(userId);

    if (context.mounted) context.go('/dashboard');
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
              const Spacer(flex: 3),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2A3A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF2E75B6),
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'You\'re all set',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vela is now collecting your baseline data. '
                'Your first session will be ready tomorrow morning.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The more data Vela has, the more personal it gets.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _completeOnboarding(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E75B6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go to dashboard',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}