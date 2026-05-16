// lib/screens/notification_settings_screen.dart — Notification preferences.
// Reads/writes to users table: notifications_enabled, quiet_hours_start,
// quiet_hours_end, alert_level_filter.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _enabled = true;
  String _quietStart = '22:00';
  String _quietEnd = '07:00';
  String _alertLevel = 'all';
  bool _loading = true;
  bool _saving = false;

  static const _alertLevels = {
    'all': 'All alerts',
    'significant': 'Significant and critical only',
    'critical': 'Critical only',
  };

  static const _hourOptions = [
    '18:00', '19:00', '20:00', '21:00', '22:00', '23:00', '00:00',
    '01:00', '02:00', '03:00', '04:00', '05:00', '06:00', '07:00',
    '08:00', '09:00', '10:00',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('notifications_enabled, quiet_hours_start, quiet_hours_end, alert_level_filter')
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null || !mounted) return;

      setState(() {
        _enabled = (data['notifications_enabled'] as bool?) ?? true;
        _quietStart = (data['quiet_hours_start'] as String?) ?? '22:00';
        _quietEnd = (data['quiet_hours_end'] as String?) ?? '07:00';
        _alertLevel = (data['alert_level_filter'] as String?) ?? 'all';
      });
    } catch (e) {
      debugPrint('Failed to load notification prefs: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);

    try {
      await SupabaseService.instance.updateUserProfile(userId, {
        'notifications_enabled': _enabled,
        'quiet_hours_start': _quietStart,
        'quiet_hours_end': _quietEnd,
        'alert_level_filter': _alertLevel,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences saved')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatHour(String h) {
    final parts = h.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E75B6)),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Enable/disable
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2533),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_outlined,
                                  color: Colors.grey[400], size: 22),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Push notifications',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ),
                              Switch(
                                value: _enabled,
                                activeColor: const Color(0xFF2E75B6),
                                onChanged: (v) =>
                                    setState(() => _enabled = v),
                              ),
                            ],
                          ),
                        ),

                        if (_enabled) ...[
                          const SizedBox(height: 24),

                          // Quiet hours
                          Text(
                            'Quiet hours',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No notifications during this window.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('From',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12)),
                                    const SizedBox(height: 6),
                                    _TimeDropdown(
                                      value: _quietStart,
                                      items: _hourOptions,
                                      formatHour: _formatHour,
                                      onChanged: (v) =>
                                          setState(() => _quietStart = v!),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Until',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12)),
                                    const SizedBox(height: 6),
                                    _TimeDropdown(
                                      value: _quietEnd,
                                      items: _hourOptions,
                                      formatHour: _formatHour,
                                      onChanged: (v) =>
                                          setState(() => _quietEnd = v!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Alert level filter
                          Text(
                            'Alert sensitivity',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._alertLevels.entries.map((entry) =>
                              _AlertLevelOption(
                                value: entry.key,
                                label: entry.value,
                                selected: _alertLevel == entry.key,
                                onTap: () =>
                                    setState(() => _alertLevel = entry.key),
                              )),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E75B6),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
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

class _TimeDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String Function(String) formatHour;
  final ValueChanged<String?> onChanged;

  const _TimeDropdown({
    required this.value,
    required this.items,
    required this.formatHour,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1923),
        border: Border.all(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: const Color(0xFF0F1923),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items
              .map((e) => DropdownMenuItem(
                  value: e, child: Text(formatHour(e))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AlertLevelOption extends StatelessWidget {
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AlertLevelOption({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2E75B6).withValues(alpha: 0.15)
                : const Color(0xFF1A2533),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2E75B6)
                  : Colors.grey[800]!,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected
                    ? const Color(0xFF2E75B6)
                    : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
