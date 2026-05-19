// lib/screens/onboarding/profile_screen.dart — Basic profile collection.
// Collects: name (stored as username per Build 1), occupation (dropdown + Other free text).
// Work hours + bedtime are UI-only for now — collected conversationally during
// sessions 2-7 and written to user_schedule as recurring events.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/health/health_data_manager.dart';
import '../../core/security/secure_storage.dart';
import '../../main.dart' show kHealthSyncTask;
import '../../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _customOccupationController = TextEditingController();
  String _occupation = 'Office / Desk';
  String _workStart = '9:00 AM';
  String _workEnd = '5:00 PM';
  String _sleepTime = '10:00 PM';
  bool _loading = false;

  static const _occupations = [
    'Office / Desk',
    'Healthcare',
    'Creative / Media',
    'Education',
    'Manual / Physical',
    'Remote / Freelance',
    'Student',
    'Other',
  ];

  static const _times = [
    '5:00 AM', '6:00 AM', '7:00 AM', '8:00 AM', '9:00 AM',
    '10:00 AM', '11:00 AM', '12:00 PM', '1:00 PM', '2:00 PM',
    '3:00 PM', '4:00 PM', '5:00 PM', '6:00 PM', '7:00 PM',
    '8:00 PM', '9:00 PM', '10:00 PM', '11:00 PM', '12:00 AM',
  ];

  bool get _isOther => _occupation == 'Other';

  @override
  void dispose() {
    _nameController.dispose();
    _customOccupationController.dispose();
    super.dispose();
  }

  /// Converts the selected dropdown value (or custom text) to a DB-friendly string.
  /// "Office / Desk" -> "office_desk", "Healthcare" -> "healthcare",
  /// "Other" + custom text -> custom text as-is.
  String _occupationForDatabase() {
    if (_isOther) {
      return _customOccupationController.text.trim();
    }
    return _occupation
        .toLowerCase()
        .replaceAll(' / ', '_')
        .replaceAll(' ', '_');
  }

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // If "Other" is selected, require the custom text
    if (_isOther && _customOccupationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your occupation.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Only write columns that exist in the Build 1 schema.
      // Work hours and bedtime are kept in UI for user experience but not
      // persisted here — they go in user_schedule later as recurring events.
      final occupation = _occupationForDatabase();
      await SupabaseService.instance.updateUserProfile(userId, {
        'username': name,
        if (occupation.isNotEmpty) 'occupation': occupation,
      });

      // Trigger first health data sync
      final manager = HealthDataManager();
      await manager.syncHealthData(userId: userId);

      // Register background sync
      await SecureStorage.instance.saveUserId(userId);
      await Workmanager().registerPeriodicTask(
        kHealthSyncTask, kHealthSyncTask,
        frequency: const Duration(minutes: 15),
        inputData: {'user_id': userId},
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      if (mounted) context.go('/onboarding/ready');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text(
                'A little about you',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps your first session feel personal.',
                style: TextStyle(color: Colors.grey[500], fontSize: 15),
              ),
              const SizedBox(height: 32),
              _Label('First name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Your name'),
              ),
              const SizedBox(height: 24),
              _Label('What kind of work do you do?'),
              const SizedBox(height: 8),
              _Dropdown(
                value: _occupation,
                items: _occupations,
                onChanged: (v) => setState(() => _occupation = v!),
              ),
              if (_isOther) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customOccupationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Describe your work'),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Work starts'),
                        const SizedBox(height: 8),
                        _Dropdown(
                          value: _workStart,
                          items: _times,
                          onChanged: (v) => setState(() => _workStart = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Work ends'),
                        const SizedBox(height: 8),
                        _Dropdown(
                          value: _workEnd,
                          items: _times,
                          onChanged: (v) => setState(() => _workEnd = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Label('Typical bedtime'),
              const SizedBox(height: 8),
              _Dropdown(
                value: _sleepTime,
                items: _times,
                onChanged: (v) => setState(() => _sleepTime = v!),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveAndContinue,
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
                      : const Text('Continue', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[700]),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey[800]!),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF2E75B6)),
        borderRadius: BorderRadius.circular(10),
      ),
      filled: true,
      fillColor: const Color(0xFF000000),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 13));
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({required this.value, required this.items, required this.onChanged});

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
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF0F1923),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
