import 'dart:async';
import '../config/env.dart';
import '../services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/daily_plan_model.dart';
import '../providers/daily_plan_provider.dart';
import 'day_editor.dart';

const _accent = Color(0xFFC9A6FF);
const _muted = Color(0xFFA5A5B5);
const _card = Color(0xFF15151D);

String _minutes(double value) =>
    '${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(1)} min';

class DailyPlanScreen extends ConsumerWidget {
  const DailyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Plan'),
        actions: [
          IconButton(
            tooltip: 'Signals',
            icon: const Icon(Icons.show_chart),
            onPressed: () => context.push('/signals'),
          ),
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push('/schedule'),
          ),
          const _RegeneratePlanButton(),
        ],
      ),
      body: ref.watch(dailyPlanProvider).when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(
          child: CircularProgressIndicator(color: _accent),
        ),
        error: (_, __) => _PlanError(
          onRetry: () => ref.invalidate(dailyPlanProvider),
        ),
        data: (plan) => RefreshIndicator(
          color: _accent,
          onRefresh: () =>
              ref.refresh(dailyPlanProvider.future).then((_) {}),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                '${plan.date} · ${plan.timezone}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => openDayEditor(context),
                icon: const Icon(Icons.tune),
                label: const Text('Shape today · availability, timing and progress'),
              ),
              const SizedBox(height: 12),
              _PlanCard(
                children: [
                  const _SectionTitle('TODAY', 'Your day, in order'),
                  if (plan.summary != null) ...[
                    Text(
                      plan.summary!,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (plan.planId == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No Vela plan has been saved for today yet. '
                        'Your calendar commitments appear below.',
                        style: TextStyle(
                          color: _muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  if (plan.activities.isEmpty)
                    const Text(
                      'Nothing scheduled here yet.',
                      style: TextStyle(color: _muted),
                    ),
                  for (final activity in plan.activities)
                    _ActivityRow(
                      activity: activity,
                      next: activity.id == plan.nextActivity?.id,
                    ),
                ],
              ),
              if (plan.deferred.isNotEmpty) ...[
                const SizedBox(height: 16),
                _PlanCard(
                  children: [
                    const _SectionTitle('LATER', 'Deferred activities'),
                    for (final item in plan.deferred)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.reason != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  item.reason!,
                                  style: const TextStyle(
                                    color: _muted,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (plan.history.isNotEmpty) ...[
                const SizedBox(height: 16),
                _PlanCard(
                  children: [
                    const _SectionTitle('UPDATES', 'Plan history'),
                    for (final update in plan.history)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 62,
                              child: Text(
                                update.at,
                                style: const TextStyle(color: _accent),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                update.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RegeneratePlanButton extends ConsumerStatefulWidget {
  const _RegeneratePlanButton();

  @override
  ConsumerState<_RegeneratePlanButton> createState() =>
      _RegeneratePlanButtonState();
}

class _RegeneratePlanButtonState
    extends ConsumerState<_RegeneratePlanButton> {
  bool _busy = false;

  Future<void> _showResult(String title, String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerate() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final base = Env.plannerUrl.replaceFirst(RegExp(r'/$'), '');

      final result = await ApiClient.instance.postJson(
        '$base/plan',
        body: {'trigger': 'user_request'},
        timeout: const Duration(minutes: 3),
      );

      if (!mounted) return;

      if (result['planningStatus'] == 'needs_details') {
        if (result['clarification']?.toString().toLowerCase().contains('available') == true) {
          await openDayEditor(context);
          return;
        }
        await _showResult(
          'Vela needs more detail',
          result['clarification']?.toString() ??
              'More information is needed before Vela can prepare this plan.',
        );
        return;
      }

      if (result['planningStatus'] != 'published') {
        await _showResult(
          'No new plan published',
          'Vela did not publish a replacement plan. '
              'The activities displayed may still belong to your earlier plan.',
        );
        return;
      }

      final planId = result['planId'];

      if (planId is! String || planId.isEmpty) {
        throw StateError('The planner did not return the new plan ID.');
      }

      final plan = await ref.refresh(dailyPlanProvider.future);
      if (!mounted) return;

      if (plan.planId != planId) {
        await _showResult(
          'New plan not confirmed',
          'The planner returned a new plan, but the app has not loaded '
              'that version. Pull down on Plan to reload it.',
        );
        return;
      }

      final currentWork = plan.activities
          .where((a) => a.isWork && !a.carriedFromEarlierPlan)
          .toList();

      if (currentWork.isEmpty ||
          currentWork.any((a) =>
              a.steps.isEmpty ||
              a.instruction == null ||
              a.expectedResult == null)) {
        await _showResult(
          'Activity details are still missing',
          'The new plan was loaded, but its activities do not contain '
              'the required instructions, steps and expected result. '
              'This needs a backend check. Plan ID: $planId',
        );
        return;
      }

      await _showResult(
        'New plan loaded',
        'Open an activity to see its instructions, steps and expected result.',
      );
    } on TimeoutException {
      await _showResult(
        'Planning has not been confirmed',
        'Vela may still be preparing the plan. Pull down on Plan to check '
            'for an update before requesting another regeneration.',
      );
    } on ApiException catch (error) {
      await _showResult('Could not regenerate plan', error.message);
    } catch (error) {
      await _showResult('Could not confirm the new plan', error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _busy ? 'Regenerating plan' : 'Regenerate plan',
      onPressed: _busy ? null : _regenerate,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _accent,
              ),
            )
          : const Icon(Icons.auto_awesome),
    );
  }
}

class TodayPlanCard extends ConsumerWidget {
  const TodayPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PlanCard(
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle('TODAY', 'Your plan'),
            ),
            TextButton(
              onPressed: () => context.push('/plan'),
              child: const Text(
                'View all',
                style: TextStyle(color: _accent),
              ),
            ),
          ],
        ),
        ref.watch(dailyPlanProvider).when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(color: _accent),
          ),
          error: (_, __) => _PlanError(
            compact: true,
            onRetry: () => ref.invalidate(dailyPlanProvider),
          ),
          data: (plan) {
            final upcoming = plan.activities
                .where(
                  (item) =>
                      !item.isCompleted &&
                      (item.endsAt ?? item.startsAt)
                          .isAfter(plan.fetchedAt),
                )
                .take(3)
                .toList();

            if (upcoming.isEmpty) {
              return Text(
                plan.planId == null
                    ? 'Your saved plan will appear here.'
                    : 'No remaining scheduled activities.',
                style: const TextStyle(color: _muted),
              );
            }

            return Column(
              children: [
                for (final activity in upcoming)
                  _ActivityRow(
                    activity: activity,
                    next: activity.id == plan.nextActivity?.id,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class PlanActivityScreen extends ConsumerWidget {
  final String activityId;

  const PlanActivityScreen({
    super.key,
    required this.activityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Activity details'),
      ),
      body: ref.watch(dailyPlanProvider).when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(
          child: CircularProgressIndicator(color: _accent),
        ),
        error: (_, __) => _PlanError(
          onRetry: () => ref.invalidate(dailyPlanProvider),
        ),
        data: (plan) {
          final activity = plan.activity(activityId);

          if (activity == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This activity is no longer in today’s plan. '
                  'Return to Plan for the latest version.',
                  style: TextStyle(
                    color: _muted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PlanCard(
                children: [
                  Text(
                    activity.isWork ? 'PLANNED WORK' : 'CALENDAR',
                    style: const TextStyle(
                      color: _accent,
                      letterSpacing: 1.5,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activity.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Tag(activity.timeLabel),
                      if (activity.minutes != null)
                        _Tag(_minutes(activity.minutes!)),
                      _Tag(
                        activity.status,
                        done: activity.isCompleted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    plan.timezone,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                  if (activity.carriedFromEarlierPlan)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Retained from an earlier plan because work was reported.',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                ],
              ),
              if (activity.goalTitle != null)
                _DetailSection('Goal', activity.goalTitle!),
              if (activity.instruction != null)
                _DetailSection('What to do', activity.instruction!),
              if (activity.steps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _PlanCard(
                    children: [
                      const _SectionTitle(
                        'BREAKDOWN',
                        'Activity steps',
                      ),
                      for (var i = 0; i < activity.steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '${i + 1}.',
                                  style: const TextStyle(color: _accent),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.steps[i].title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (activity.steps[i].minutes != null)
                                      Text(
                                        'Estimated ${_minutes(activity.steps[i].minutes!)}',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (activity.isWork && activity.steps.isEmpty)
                const _DetailSection(
                  'Breakdown',
                  'No further steps were saved for this activity.',
                ),
              if (activity.expectedResult != null)
                _DetailSection('Expected result', activity.expectedResult!),
              if (activity.completionStandard != null)
                _DetailSection(
                  'What counts as progress',
                  activity.completionStandard!,
                ),
              if (activity.reasoning != null)
                _DetailSection(
                  'Planning explanation',
                  activity.reasoning!,
                ),
              if ((activity.bufferMinutes ?? 0) > 0)
                _DetailSection(
                  'Transition',
                  '${_minutes(activity.bufferMinutes!)} planned before this activity.',
                ),
              if (activity.actualMinutes != null)
                _DetailSection(
                  'Recorded duration',
                  _minutes(activity.actualMinutes!),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final DayActivity activity;
  final bool next;

  const _ActivityRow({
    required this.activity,
    required this.next,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          '/plan/activity/${Uri.encodeComponent(activity.id)}',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                activity.isCompleted
                    ? Icons.check_circle_outline
                    : activity.isWork
                        ? Icons.task_alt
                        : Icons.event_outlined,
                color: activity.isCompleted
                    ? const Color(0xFF73D6AE)
                    : _accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.timeLabel,
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activity.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${next ? 'Up next · ' : ''}${activity.status}'
                      '${activity.minutes == null ? '' : ' · ${_minutes(activity.minutes!)}'}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: _muted,
                size: 20,
              ),
            ],
          ),
        ),
      );
}

class _PlanCard extends StatelessWidget {
  final List<Widget> children;

  const _PlanCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _accent.withValues(alpha: 0.13),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String label, title;

  const _SectionTitle(this.label, this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _accent,
                fontSize: 11,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _DetailSection extends StatelessWidget {
  final String title, text;

  const _DetailSection(this.title, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _PlanCard(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  final bool done;

  const _Tag(this.text, {this.done = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: (done ? Colors.green : _accent)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: done ? const Color(0xFF73D6AE) : _accent,
            fontSize: 12,
          ),
        ),
      );
}

class _PlanError extends StatelessWidget {
  final VoidCallback onRetry;
  final bool compact;

  const _PlanError({
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 0 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load your plan.',
                style: TextStyle(color: _muted),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: _accent),
                ),
              ),
            ],
          ),
        ),
      );
}
