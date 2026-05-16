// lib/screens/settings_screen.dart — Profile, notifications toggle, sign out.
// Minimal — most settings are managed conversationally during sessions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import '../core/health/health_data_manager.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

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
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
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
              data: (profile) => GestureDetector(
                onTap: () => context.push('/edit-profile'),
                child: _ProfileSection(
                  firstName: profile?.firstName ?? '—',
                  email: Supabase.instance.client.auth.currentUser?.email ?? '—',
                ),
              ),
              loading: () => const _ProfileSection(firstName: '...', email: '...'),
              error: (_, __) => const _ProfileSection(firstName: '—', email: '—'),
            ),
            const SizedBox(height: 32),

            // Notifications
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
              onTap: () => context.push('/notification-settings'),
            ),
            const SizedBox(height: 8),

            // Schedule
            _SettingsTile(
              icon: Icons.calendar_today_outlined,
              label: 'Schedule',
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
              onTap: () => context.push('/schedule'),
            ),
            const SizedBox(height: 8),

            // Goals
            _SettingsTile(
              icon: Icons.flag_outlined,
              label: 'Goals',
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
              onTap: () => context.push('/goals'),
            ),
            const SizedBox(height: 8),

            // Health profile
            _SettingsTile(
              icon: Icons.favorite_outline,
              label: 'Health profile',
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
              onTap: () => context.push('/health-profile'),
            ),
            const SizedBox(height: 8),

            // Manual health sync
            _SettingsTile(
              icon: Icons.sync,
              label: 'Sync health data',
              trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
              onTap: () async {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId == null) return;
                final manager = HealthDataManager();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Syncing health data...')),
                );
                await manager.syncHealthData(userId: userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync complete')),
                  );
                }
              },
            ),
            const SizedBox(height: 8),

            // Subscription
            _SettingsTile(
              icon: Icons.diamond_outlined,
              label: 'Subscription',
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
              onTap: () => context.push('/subscription'),
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
