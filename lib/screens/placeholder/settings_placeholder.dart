// lib/screens/placeholder/settings_placeholder.dart
// Temporary — replaced in Build 6.4 with full settings screen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050507),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: Text(
                'Full settings coming in Build 6.4',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await SupabaseService.instance.signOut();
                  if (context.mounted) context.go('/sign-in');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sign out', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}