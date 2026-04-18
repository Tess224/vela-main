// lib/screens/dashboard_screen.dart — Dashboard with primary insight,
// recovery summary, and unresolved monitoring events. Single-surface design.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/monitoring_event_model.dart';
import '../models/user_memory_model.dart';
import '../models/session_record_model.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';

class DashboardScreen extends ConsumerWidget {
  final String? highlightEventId;
  final String? recoveryEventId;

  const DashboardScreen({
    super.key,
    this.highlightEventId,
    this.recoveryEventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final memoryAsync = ref.watch(userMemoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF2E75B6),
          backgroundColor: const Color(0xFF1A2533),
          onRefresh: () async {
            ref.invalidate(userProfileProvider);
            ref.invalidate(userMemoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header with greeting + settings icon
              profileAsync.when(
                data: (profile) => _DashboardHeader(
                  userName: profile?.firstName ?? 'there',
                  onSettingsTap: () => context.push('/settings'),
                ),
                loading: () => const _DashboardHeader(
                  userName: '...',
                  onSettingsTap: null,
                ),
                error: (_, __) => _DashboardHeader(
                  userName: 'there',
                  onSettingsTap: () => context.push('/settings'),
                ),
              ),
              const SizedBox(height: 24),

              // Profile completion prompt
              const _ProfileCompletionCard(),
              const SizedBox(height: 16),

              // Memory-driven content (primary insight + recovery + events)
              memoryAsync.when(
                data: (memory) => _DashboardBody(
                  memory: memory,
                  highlightEventId: highlightEventId,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2E75B6),
                    ),
                  ),
                ),
                error: (error, _) => _ErrorPlaceholder(
                  message: 'Could not load your data. Pull to refresh.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _DashboardHeader extends StatelessWidget {
  final String userName;
  final VoidCallback? onSettingsTap;

  const _DashboardHeader({
    required this.userName,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettingsTap,
          icon: Icon(
            Icons.settings_outlined,
            color: Colors.grey[400],
            size: 24,
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ---------------------------------------------------------------------------
// Body — primary insight + recovery + events
// ---------------------------------------------------------------------------

class _DashboardBody extends StatelessWidget {
  final UserMemoryModel memory;
  final String? highlightEventId;

  const _DashboardBody({
    required this.memory,
    required this.highlightEventId,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    // Primary insight card
    if (memory.hasActivePattern) {
      children.add(_PrimaryInsightCard(pattern: memory.topActivePattern!));
      children.add(const SizedBox(height: 16));
    }

    // Recovery summary card
    if (memory.hasOvernightSummary) {
      children.add(_RecoverySummaryCard(summary: memory.overnightSummary!));
      children.add(const SizedBox(height: 24));
    }

    // Unresolved monitoring events
    if (memory.hasUnresolvedEvents) {
      children.add(
        Text(
          'Recent signals',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
      for (final event in memory.unresolvedEvents) {
        children.add(GestureDetector(
          onTap: () => showEventDetail(context, event),
          child: _MonitoringEventCard(
            event: event,
            isHighlighted: event.eventId == highlightEventId,
          ),
        ));
        children.add(const SizedBox(height: 8));
      }
    }

    // Recent sessions
    children.add(const SizedBox(height: 16));
    children.add(const _RecentSessionsList());

    // Empty state (only if no memory content AND no sessions)
    if (children.length <= 2) {
      return const _EmptyDashboard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

// ---------------------------------------------------------------------------
// Primary insight card
// ---------------------------------------------------------------------------

class _PrimaryInsightCard extends StatelessWidget {
  final String pattern;

  const _PrimaryInsightCard({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2533),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E75B6).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2E75B6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Top pattern',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            pattern,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recovery summary card
// ---------------------------------------------------------------------------

class _RecoverySummaryCard extends StatelessWidget {
  final String summary;

  const _RecoverySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2533),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bedtime_outlined,
                color: Colors.grey[400],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Last night',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monitoring event card
// ---------------------------------------------------------------------------

class _MonitoringEventCard extends StatelessWidget {
  final MonitoringEventModel event;
  final bool isHighlighted;

  const _MonitoringEventCard({
    required this.event,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2533),
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(
                color: const Color(0xFF2E75B6),
                width: 2,
              )
            : null,
      ),
      child: Row(
        children: [
          // Severity dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _classificationColor(event.classification),
            ),
          ),
          const SizedBox(width: 12),
          // Metric label + context status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.metricLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _contextLabel(event),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Time
          Text(
            _timeAgo(event.detectedAt),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _classificationColor(String classification) {
    switch (classification) {
      case 'class_4':
        return const Color(0xFFE57373); // red — auto-session
      case 'class_3':
        return const Color(0xFFD4A843); // amber — context confirm
      case 'class_2':
        return const Color(0xFF2E75B6); // blue — quiet notify
      default:
        return const Color(0xFF595959); // grey — class_1 / unknown
    }
  }

  String _contextLabel(MonitoringEventModel event) {
    if (event.contextResponse == 'confirmed') return 'Context confirmed';
    if (event.contextResponse == 'dismissed') return 'Dismissed';
    if (event.responseReceived) return 'Responded';
    return 'No context yet';
  }

  String _timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ---------------------------------------------------------------------------
// Empty + error states
// ---------------------------------------------------------------------------

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            color: Colors.grey[700],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Your patterns will appear here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'after a few sessions',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          // Manual session start — also serves as the only entry point
          // until time-of-day auto-open is added in Build 6.5.
          ElevatedButton.icon(
            onPressed: () {
              final hour = DateTime.now().hour;
              final sessionType = hour < 14 ? 'morning' : 'evening';
              context.push('/session', extra: {'sessionType': sessionType});
            },
            icon: const Icon(Icons.mic, size: 18),
            label: const Text('Start a session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E75B6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  final String message;

  const _ErrorPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile completion card — shows when health profile is incomplete
// ---------------------------------------------------------------------------

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _fetchCompleteness(),
      builder: (context, snapshot) {
        final completeness = snapshot.data ?? 0;

        // Hide card if profile is fully complete
        if (completeness >= 100) return const SizedBox.shrink();

        final filled = (completeness / 10).round(); // 10 fields total

        return GestureDetector(
          onTap: () => context.push('/health-profile'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2533),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2E75B6).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Colors.grey[400],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete your health profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$filled of 10 fields filled',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _fetchCompleteness() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('profile_completeness')
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return 0;
      return (data['profile_completeness'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }
}


// ---------------------------------------------------------------------------
// Recent sessions list
// ---------------------------------------------------------------------------

class _RecentSessionsList extends StatelessWidget {
  const _RecentSessionsList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SessionRecordModel>>(
      future: _fetchSessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final sessions = snapshot.data;
        if (sessions == null || sessions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent sessions',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...sessions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SessionCard(session: s),
                )),
          ],
        );
      },
    );
  }

  Future<List<SessionRecordModel>> _fetchSessions() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await SupabaseService.instance.fetchRecentSessions(userId);
      return rows.map((r) => SessionRecordModel.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }
}

class _SessionCard extends StatelessWidget {
  final SessionRecordModel session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/session-detail', extra: session),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2533),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _icon(session.sessionType),
              color: Colors.grey[500],
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.typeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session.insightDelivered ?? 'No insight recorded',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              session.dateLabel,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'morning':
        return Icons.wb_sunny_outlined;
      case 'evening':
        return Icons.bedtime_outlined;
      case 'in_moment':
        return Icons.flash_on_outlined;
      default:
        return Icons.chat_outlined;
    }
  }
}

// ---------------------------------------------------------------------------
// Event detail bottom sheet
// ---------------------------------------------------------------------------

void showEventDetail(BuildContext context, MonitoringEventModel event) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            event.metricLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow('Deviation score', event.deviationScore.toStringAsFixed(1)),
          const SizedBox(height: 10),
          _DetailRow('Severity', _classLabel(event.classification)),
          const SizedBox(height: 10),
          _DetailRow('Detected', _formatTime(event.detectedAt)),
          const SizedBox(height: 10),
          _DetailRow('Status', _statusLabel(event)),
          if (event.contextResponse != null &&
              event.contextResponse!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailRow('Your response', event.contextResponse!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

String _classLabel(String classification) {
  switch (classification) {
    case 'class_4':
      return 'Critical';
    case 'class_3':
      return 'Significant';
    case 'class_2':
      return 'Notable';
    default:
      return 'Minor';
  }
}

String _statusLabel(MonitoringEventModel event) {
  if (event.resolution != null) return 'Resolved';
  if (event.contextResponse == 'confirmed') return 'Context confirmed';
  if (event.contextResponse == 'dismissed') return 'Dismissed';
  if (event.responseReceived) return 'Responded';
  return 'Awaiting context';
}

String _formatTime(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${dt.day}/${dt.month} at $hour:$minute';
}
