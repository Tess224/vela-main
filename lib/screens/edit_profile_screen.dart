// lib/screens/edit_profile_screen.dart — Edit onboarding profile fields.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _customOccupationController = TextEditingController();
  String _occupation = 'Office / Desk';
  String _workStart = '9:00 AM';
  String _workEnd = '5:00 PM';
  String _sleepTime = '10:00 PM';
  bool _loading = true;
  bool _saving = false;

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
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customOccupationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('username, occupation, sleep_time')
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null || !mounted) return;

      setState(() {
        _nameController.text = (data['username'] as String?) ?? '';
        final occ = (data['occupation'] as String?) ?? '';
        final match = _occupations.where(
          (o) => o.toLowerCase().replaceAll(' / ', '_').replaceAll(' ', '_') == occ,
        );
        if (match.isNotEmpty) {
          _occupation = match.first;
        } else if (occ.isNotEmpty) {
          _occupation = 'Other';
          _customOccupationController.text = occ;
        }
        final st = data['sleep_time'] as String?;
        if (st != null && _times.contains(st)) {
          _sleepTime = st;
        }
      });
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _occupationForDatabase() {
    if (_isOther) return _customOccupationController.text.trim();
    return _occupation.toLowerCase().replaceAll(' / ', '_').replaceAll(' ', '_');
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    if (_isOther && _customOccupationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your occupation.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.instance.updateUserProfile(userId, {
        'username': name,
        'occupation': _occupationForDatabase(),
        'sleep_time': _sleepTime,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
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
          'Edit profile',
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ],
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
