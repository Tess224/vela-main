// lib/screens/goals_screen.dart — View and manage user goals.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/goal_model.dart';
import '../providers/goals_provider.dart';
import '../services/supabase_service.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(userGoalsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1923),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Goals',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              await context.push('/add-goal');
              ref.invalidate(userGoalsProvider);
            },
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E75B6)),
        ),
        error: (e, _) => Center(
          child: Text('Failed to load goals', style: TextStyle(color: Colors.grey[500])),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, color: Colors.grey[700], size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No goals yet',
                    style: TextStyle(color: Colors.grey[500], fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tell Vela what you want to achieve',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context.push('/add-goal');
                      ref.invalidate(userGoalsProvider);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add a goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E75B6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final active = goals.where((g) => g.isActive).toList();
          final inactive = goals.where((g) => !g.isActive).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (active.isNotEmpty) ...[
                Text('Active', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                ...active.map((g) => _GoalCard(goal: g, onRefresh: () => ref.invalidate(userGoalsProvider))),
              ],
              if (inactive.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Completed / Paused', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                ...inactive.map((g) => _GoalCard(goal: g, onRefresh: () => ref.invalidate(userGoalsProvider))),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback onRefresh;

  const _GoalCard({required this.goal, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          await context.push('/add-goal', extra: goal);
          onRefresh();
        },
        onLongPress: () => _showStatusMenu(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2533),
            borderRadius: BorderRadius.circular(12),
            border: goal.isActive
                ? Border.all(color: _categoryColor(goal.category).withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goal.isActive ? _categoryColor(goal.category) : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        color: goal.isActive ? Colors.white : Colors.grey[500],
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${goal.categoryLabel}  •  ${goal.timeframeLabel}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!goal.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    goal.status == 'completed' ? 'Done' : 'Paused',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2533),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (goal.isActive) ...[
              _ActionTile(icon: Icons.pause, label: 'Pause goal', onTap: () {
                _updateStatus(context, 'paused');
              }),
              _ActionTile(icon: Icons.check_circle_outline, label: 'Mark complete', onTap: () {
                _updateStatus(context, 'completed');
              }),
              _ActionTile(icon: Icons.close, label: 'Abandon goal', onTap: () {
                _updateStatus(context, 'abandoned');
              }),
            ] else ...[
              _ActionTile(icon: Icons.play_arrow, label: 'Reactivate', onTap: () {
                _updateStatus(context, 'active');
              }),
              _ActionTile(icon: Icons.delete_outline, label: 'Delete', onTap: () {
                _deleteGoal(context);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    Navigator.of(context).pop();
    await SupabaseService.instance.updateGoalStatus(goal.goalId, newStatus);
    onRefresh();
  }

  Future<void> _deleteGoal(BuildContext context) async {
    Navigator.of(context).pop();
    await SupabaseService.instance.deleteGoal(goal.goalId);
    onRefresh();
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'performance':
        return const Color(0xFF2E75B6);
      case 'recovery':
        return const Color(0xFF4CAF50);
      case 'health':
        return const Color(0xFFE57373);
      case 'skill':
        return const Color(0xFFD4A843);
      case 'habit':
        return const Color(0xFFC9A6FF);
      case 'lifestyle':
        return const Color(0xFF64B5F6);
      default:
        return Colors.grey;
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}
