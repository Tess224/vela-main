// lib/screens/settings_screen.dart — Profile, notifications toggle, sign out.
// Minimal — most settings are managed conversationally during sessions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2533),
        title: const Text(
          'Sign out?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You can sign back in any time.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: Color(0xFFE57373)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/sign-in');
      }
    } catch (error) {
      debugPrint('Sign out error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1923),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile section
            profileAsync.when(
              data: (profile) => _ProfileSection(
                firstName: profile?.firstName ?? '—',
                email: Supabase.instance.client.auth.currentUser?.email ?? '—',
              ),
              loading: () => const _ProfileSection(firstName: '...', email: '...'),
              error: (_, __) => const _ProfileSection(firstName: '—', email: '—'),
            ),
            const SizedBox(height: 32),

            // Notifications toggle
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              trailing: Switch(
                value: _notificationsEnabled,
                activeColor: const Color(0xFF2E75B6),
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  // TODO Build 6.4+: persist to user preferences in Supabase
                },
              ),
            ),
            const SizedBox(height: 8),

            // About
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'About Vela',
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Vela',
                  applicationVersion: '0.1.0',
                  applicationLegalese: 'HealthChain',
                );
              },
            ),
            const SizedBox(height: 32),

            // Sign out
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _signOut,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1A2533),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: Color(0xFFE57373),
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String firstName;
  final String email;

  const _ProfileSection({required this.firstName, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2533),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2E75B6).withValues(alpha: 0.2),
            child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF2E75B6),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A2533),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[400], size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
