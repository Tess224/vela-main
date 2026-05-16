// lib/screens/notifications_screen.dart — Notification inbox.
// Pulls monitoring events where notification_sent == true.
// Styled per prototype's NotificationsScreen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monitoring_event_model.dart';
import 'dashboard_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF000000),
                border: Border(
                  bottom: BorderSide(color: Color(0x0FFFFFFF)),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0x0AFFFFFF),
                        border: Border.all(color: const Color(0x0FFFFFFF)),
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFFC9A6FF), size: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF0F2F8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notification-settings'),
                    child: const Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: Color(0xFFC9A6FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  _NFilterChip(label: 'All', id: 'all', active: _filter, onTap: _setFilter),
                  const SizedBox(width: 6),
                  _NFilterChip(label: 'Signals', id: 'signal', active: _filter, onTap: _setFilter),
                  const SizedBox(width: 6),
                  _NFilterChip(label: 'Sessions', id: 'session', active: _filter, onTap: _setFilter),
                ],
              ),
            ),

            // List
            Expanded(
              child: FutureBuilder<List<MonitoringEventModel>>(
                future: _fetchNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFC9A6FF)),
                    );
                  }

                  final all = snapshot.data ?? [];
                  final events = _filter == 'all'
                      ? all
                      : _filter == 'signal'
                          ? all.where((e) => !e.fedToSession).toList()
                          : all.where((e) => e.fedToSession).toList();

                  if (events.isEmpty) {
                    return const Center(
                      child: Text(
                        'All caught up',
                        style: TextStyle(
                          color: Color(0xFF4A5168),
                          fontSize: 14,
                          fontFamily: 'Rajdhani',
                        ),
                      ),
                    );
                  }

                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  final today = events.where((e) => e.detectedAt.isAfter(todayStart)).toList();
                  final earlier = events.where((e) => !e.detectedAt.isAfter(todayStart)).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (today.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(6, 10, 0, 6),
                          child: Text(
                            'TODAY',
                            style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 10,
                              letterSpacing: 1.6,
                              color: Color(0xFF8A92A8),
                            ),
                          ),
                        ),
                        ...today.map((e) => _NotifRow(event: e, onTap: () => showEventDetail(context, e))),
                      ],
                      if (earlier.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(6, 10, 0, 6),
                          child: Text(
                            'EARLIER',
                            style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 10,
                              letterSpacing: 1.6,
                              color: Color(0xFF8A92A8),
                            ),
                          ),
                        ),
                        ...earlier.map((e) => _NotifRow(event: e, onTap: () => showEventDetail(context, e))),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setFilter(String id) => setState(() => _filter = id);

  Future<List<MonitoringEventModel>> _fetchNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await Supabase.instance.client
          .from('monitoring_events')
          .select()
          .eq('user_id', userId)
          .eq('notification_sent', true)
          .order('detected_at', ascending: false)
          .limit(30);
      return (rows as List).map((r) => MonitoringEventModel.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }
}

class _NFilterChip extends StatelessWidget {
  final String label;
  final String id;
  final String active;
  final ValueChanged<String> onTap;

  const _NFilterChip({
    required this.label,
    required this.id,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = id == active;
    return GestureDetector(
      onTap: () => onTap(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isActive ? const Color(0x1AC9A6FF) : const Color(0x08FFFFFF),
          border: Border.all(
            color: isActive ? const Color(0x4DC9A6FF) : const Color(0x0FFFFFFF),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 10,
            letterSpacing: 0.8,
            color: isActive ? const Color(0xFFC9A6FF) : const Color(0xFF8A92A8),
          ),
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final MonitoringEventModel event;
  final VoidCallback onTap;

  const _NotifRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = _tintColor(event);
    final isUnread = event.isUnresolved && !event.responseReceived;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isUnread ? const Color(0x0AC9A6FF) : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: Color(0x0FFFFFFF)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: tint.withValues(alpha: 0.1),
                border: Border.all(color: tint.withValues(alpha: 0.2)),
              ),
              child: Icon(
                event.fedToSession ? Icons.mic : Icons.show_chart,
                color: tint,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.metricLabel,
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF0F2F8),
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _body(event),
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF8A92A8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(event.detectedAt),
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      letterSpacing: 0.6,
                      color: Color(0xFF4A5168),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tintColor(MonitoringEventModel e) {
    if (e.fedToSession) return const Color(0xFFB79AF0);
    switch (e.classification) {
      case 'class_4': return const Color(0xFFC9A6FF);
      case 'class_3': return const Color(0xFFB79AF0);
      case 'class_2': return const Color(0xFF9B7FE0);
      default: return const Color(0xFF9B7FE0);
    }
  }

  String _body(MonitoringEventModel e) {
    if (e.contextResponse == 'confirmed') return 'Context confirmed — tap to review.';
    if (e.contextResponse == 'dismissed') return 'Dismissed.';
    if (e.responseReceived) return 'You responded — tap to see details.';
    return 'Tap to review and add context.';
  }

  String _timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 2) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}