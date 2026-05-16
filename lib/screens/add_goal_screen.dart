// lib/screens/add_goal_screen.dart — Add or edit a goal.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/goal_model.dart';
import '../services/supabase_service.dart';

class AddGoalScreen extends StatefulWidget {
  final GoalModel? existing;

  const AddGoalScreen({super.key, this.existing});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _titleController = TextEditingController();
  String _category = 'performance';
  String _timeframe = 'short_term';
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.existing!.title;
      _category = widget.existing!.category;
      _timeframe = widget.existing!.timeframe;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      if (_isEditing) {
        await SupabaseService.instance.updateGoal(
          widget.existing!.goalId,
          title: title,
          category: _category,
          timeframe: _timeframe,
        );
      } else {
        await SupabaseService.instance.createGoal(
          userId: userId,
          title: title,
          category: _category,
          timeframe: _timeframe,
        );
      }

      if (mounted) context.pop();
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
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1923),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit goal' : 'New goal',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('What do you want to achieve?',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Sleep 7+ hours consistently',
                hintStyle: TextStyle(color: Colors.grey[700]),
                filled: true,
                fillColor: const Color(0xFF1A2533),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 28),

            Text('Category', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipOption(label: 'Performance', value: 'performance', selected: _category, onTap: (v) => setState(() => _category = v)),
                _ChipOption(label: 'Recovery', value: 'recovery', selected: _category, onTap: (v) => setState(() => _category = v)),
                _ChipOption(label: 'Health', value: 'health', selected: _category, onTap: (v) => setState(() => _category = v)),
                _ChipOption(label: 'Skill', value: 'skill', selected: _category, onTap: (v) => setState(() => _category = v)),
                _ChipOption(label: 'Habit', value: 'habit', selected: _category, onTap: (v) => setState(() => _category = v)),
                _ChipOption(label: 'Lifestyle', value: 'lifestyle', selected: _category, onTap: (v) => setState(() => _category = v)),
              ],
            ),
            const SizedBox(height: 28),

            Text('Timeframe', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipOption(label: 'Short-term', value: 'short_term', selected: _timeframe, onTap: (v) => setState(() => _timeframe = v)),
                _ChipOption(label: 'Mid-term', value: 'mid_term', selected: _timeframe, onTap: (v) => setState(() => _timeframe = v)),
                _ChipOption(label: 'Long-term', value: 'long_term', selected: _timeframe, onTap: (v) => setState(() => _timeframe = v)),
              ],
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E75B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Save changes' : 'Add goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipOption extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  const _ChipOption({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E75B6).withValues(alpha: 0.2) : const Color(0xFF1A2533),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E75B6) : Colors.grey.shade800,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF2E75B6) : Colors.grey[400],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
