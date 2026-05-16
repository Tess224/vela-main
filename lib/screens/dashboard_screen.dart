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
import '../core/health/health_data_manager.dart';
import '../services/supabase_service.dart';

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
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFC9A6FF),
          backgroundColor: const Color(0xFF0C0C10),
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
              const SizedBox(height: 12),

              // Next upcoming event
              const _UpcomingEventCard(),
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
                      color: Color(0xFFC9A6FF),
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
        // Vela "V" mark
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 10),
          child: CustomPaint(painter: _VelaMarkPainter()),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting().toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 8,
                  letterSpacing: 1.5,
                  color: Color(0xFF4A5168),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  color: Color(0xFFF0F2F8),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/notifications'),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.notifications_outlined, color: Color(0xFF8A92A8), size: 18),
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: onSettingsTap,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.settings_outlined, color: Color(0xFF8A92A8), size: 18),
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

class _VelaMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9A6FF)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.2)
      ..lineTo(size.width * 0.5, size.height * 0.8)
      ..lineTo(size.width * 0.85, size.height * 0.2);
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.07,
      Paint()..color = const Color(0xFFC9A6FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      children.add(const SizedBox(height: 16));
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bedtime_outlined, color: Color(0xFFC9A6FF), size: 13),
              SizedBox(width: 8),
              Text(
                'LAST NIGHT',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: Color(0xFFC9A6FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: const TextStyle(
              fontFamily: 'Rajdhani',
              color: Color(0xFF8A92A8),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}



// _MonitoringEventCard removed — signals now displayed in SignalsScreen tab.

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
            color: const Color(0xFFC9A6FF).withValues(alpha: 0.4),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your patterns will appear here',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              color: Color(0xFF8A92A8),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'after a few sessions',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              color: Color(0xFF4A5168),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          // Manual session start — also serves as the only entry point
          // until time-of-day auto-open is added in Build 6.5.
          ElevatedButton.icon(
            onPressed: () async {
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return;
              final logs = <String>[];
              final manager = HealthDataManager();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => StatefulBuilder(
                  builder: (ctx, setDialogState) {
                    if (logs.isEmpty) {
                      // Start sync
                      manager.requestPermissions().then((granted) {
                        setDialogState(() => logs.add('Permissions: \$granted'));
                        manager.syncHealthData(
                          userId: userId,
                          onLog: (msg) => setDialogState(() => logs.add(msg)),
                        ).then((_) {
                          setDialogState(() => logs.add('--- DONE ---'));
                        });
                      });
                      logs.add('Starting health sync...');
                    }
                    return AlertDialog(
                      backgroundColor: const Color(0xFF0C0C10),
                      title: const Text('Health Sync Log',
                          style: TextStyle(color: Colors.white, fontSize: 16)),

                      content: SizedBox(
                        width: double.maxFinite,
                        height: 300,
                        child: ListView(
                          children: logs.map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(l,
                                style: TextStyle(
                                    color: Colors.grey[300], fontSize: 12)),
                          )).toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                         child: const Text('Close',
                              style: TextStyle(color: Color(0xFFC9A6FF))),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.monitor_heart, size: 18),
            label: const Text('Sync health data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C0C10),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              final hour = DateTime.now().hour;
              final sessionType = hour < 14 ? 'morning' : 'evening';
              context.push('/session', extra: {'sessionType': sessionType});
            },
            icon: const Icon(Icons.mic, size: 18),
            label: const Text('Start a session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC9A6FF),
              foregroundColor: const Color(0xFF0A0010),
              
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
          style: const TextStyle(
            fontFamily: 'Rajdhani',
            color: Color(0xFF8A92A8),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming event card
// ---------------------------------------------------------------------------

class _UpcomingEventCard extends StatelessWidget {
  const _UpcomingEventCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchNextEvent(),
      builder: (context, snapshot) {
        final event = snapshot.data;
        if (event == null) return const SizedBox.shrink();

        final title = event['title'] as String? ?? 'Event';
        final startsAt = event['starts_at'] as String? ?? '';
        final stressRisk = event['stress_risk'] as String? ?? 'medium';
        final dt = DateTime.tryParse(startsAt)?.toLocal();
        final timeStr = dt != null
            ? (dt.hour.toString().padLeft(2, '0') + ':' + dt.minute.toString().padLeft(2, '0'))
            : '';

        return GestureDetector(
          onTap: () => context.push('/schedule'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0FFFFFFF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_outlined, color: Color(0xFF8A92A8), size: 20),
                
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT UP',
                        style: TextStyle(fontFamily: 'SpaceMono', color: Color(0xFF4A5168), fontSize: 9, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title + (timeStr.isNotEmpty ? ' at $timeStr' : ''),
                        style: const TextStyle(fontFamily: 'Rajdhani', color: Color(0xFFF0F2F8), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stressRisk == 'high'
                        ? const Color(0xFFE57373)
                        : stressRisk == 'medium'
                            ? const Color(0xFFD4A843)
                            : const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchNextEvent() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final events = await SupabaseService.instance.fetchUpcomingEvents(userId);
      if (events.isEmpty) return null;
      return events.first;
    } catch (_) {
      return null;
    }
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
              color: const Color(0xFF0C0C10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFC9A6FF).withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Color(0xFFC9A6FF),
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete your health profile',
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          color: Color(0xFFF0F2F8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$filled of 10 fields filled',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          color: Color(0xFF8A92A8),
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF4A5168),
                  size: 16,
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

class _ActiveGoalsCard extends StatelessWidget {
  const _ActiveGoalsCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchActiveGoals(),
      builder: (context, snapshot) {
        final goals = snapshot.data ?? [];
        if (goals.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => context.push('/goals'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.grey[500], size: 16),
                    const SizedBox(width: 8),
                    Text('Active goals', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: Colors.grey[700], size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                ...goals.take(3).map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _goalColor(g['category'] as String? ?? ''),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          g['title'] as String? ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _timeframeLabel(g['timeframe'] as String? ?? ''),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                )),
                if (goals.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${goals.length - 3} more',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchActiveGoals() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      return await SupabaseService.instance.fetchUserGoals(userId);
    } catch (_) {
      return [];
    }
  }

  Color _goalColor(String category) {
    switch (category) {
      case 'performance': return const Color(0xFFC9A6FF);
      case 'recovery': return const Color(0xFFB79AF0);
      case 'health': return const Color(0xFF9B7FE0);
      case 'skill': return const Color(0xFFA78AE5);
      case 'habit': return const Color(0xFFD4BFFF);
      case 'lifestyle': return const Color(0xFF7C5FCF);
      default: return Colors.grey;
    }
  }

  String _timeframeLabel(String timeframe) {
    switch (timeframe) {
      case 'short_term': return 'Short';
      case 'mid_term': return 'Mid';
      case 'long_term': return 'Long';
      default: return '';
    }
  }
}

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

        return _SectionDropdown(
          title: 'Recent sessions',
          children: sessions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SessionCard(session: s),
          )).toList(),
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
          color: const Color(0xFF0C0C10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x0FFFFFFF)),
        ),
        child: Row(
          children: [
            Icon(
              _icon(session.sessionType),
              color: const Color(0xFFC9A6FF),
              size: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.insightDelivered ?? session.typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      color: Color(0xFFF0F2F8),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              session.dateLabel.split(' at ').first,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                color: Color(0xFF4A5168),
                fontSize: 9,
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
    backgroundColor: const Color(0xFF0C0C10),
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
                color: const Color(0xFF4A5168),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            event.metricLabel,
            style: const TextStyle(
              fontFamily: 'Rajdhani',
              color: Color(0xFFF0F2F8),
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
            style: const TextStyle(fontFamily: 'SpaceMono', color: Color(0xFF4A5168), fontSize: 10, letterSpacing: 0.4),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'Rajdhani', color: Color(0xFFF0F2F8), fontSize: 14),
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

class _SectionDropdown extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionDropdown({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        title: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            color: Color(0xFF8A92A8),
            fontSize: 10,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w400,
          ),
        ),
        iconColor: const Color(0xFF8A92A8),
        collapsedIconColor: const Color(0xFF4A5168),
        initiallyExpanded: true,
        children: children,
      ),
    );
  }
}
