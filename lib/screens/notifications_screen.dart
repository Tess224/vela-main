// lib/screens/notifications_screen.dart — Notification inbox.
// Tabbed view: Signals (monitoring_events), Nudges (scheduled_nudges), Check-ins (ambient_checkins).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/monitoring_event_model.dart';

class NotificationsScreen extends StatefulWidget {
  final int initialTab;

  const NotificationsScreen({super.key, this.initialTab = 0});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

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
                border: Border(bottom: BorderSide(color: Color(0x0FFFFFFF))),
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
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFF0F2F8),
                      ),
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

            // Tab chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  _TabChip(label: 'Signals', index: 0, active: _activeTab, onTap: _setTab),
                  const SizedBox(width: 6),
                  _TabChip(label: 'Nudges', index: 1, active: _activeTab, onTap: _setTab),
                  const SizedBox(width: 6),
                  _TabChip(label: 'Check-ins', index: 2, active: _activeTab, onTap: _setTab),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _activeTab == 0
                  ? _SignalsTab()
                  : _activeTab == 1
                      ? _NudgesTab()
                      : _CheckinsTab(),
            ),
          ],
        ),
      ),
    );
  }

  void _setTab(int index) => setState(() => _activeTab = index);
}

// ---------------------------------------------------------------------------
// Tab chip
// ---------------------------------------------------------------------------

class _TabChip extends StatelessWidget {
  final String label;
  final int index;
  final int active;
  final ValueChanged<int> onTap;

  const _TabChip({required this.label, required this.index, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index == active;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isActive ? const Color(0x1AC9A6FF) : const Color(0x08FFFFFF),
          border: Border.all(color: isActive ? const Color(0x4DC9A6FF) : const Color(0x0FFFFFFF)),
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

// ---------------------------------------------------------------------------
// Signals tab (existing monitoring_events)
// ---------------------------------------------------------------------------

class _SignalsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MonitoringEventModel>>(
      future: _fetchSignals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A6FF)));
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const Center(child: Text('No signals yet', style: TextStyle(color: Color(0xFF4A5168), fontSize: 14, fontFamily: 'Rajdhani')));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: events.length,
          itemBuilder: (context, i) {
            final e = events[i];
            return _SignalRow(event: e, onTap: () => _showEventDetail(context, e));
          },
        );
      },
    );
  }

  Future<List<MonitoringEventModel>> _fetchSignals() async {
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

  void _showEventDetail(BuildContext context, MonitoringEventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0C10),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4A5168), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(event.metricLabel, style: const TextStyle(fontFamily: 'Rajdhani', color: Color(0xFFF0F2F8), fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nudges tab
// ---------------------------------------------------------------------------

class _NudgesTab extends StatefulWidget {
  @override
  State<_NudgesTab> createState() => _NudgesTabState();
}

class _NudgesTabState extends State<_NudgesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchNudges();
  }

  Future<List<Map<String, dynamic>>> _fetchNudges() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await Supabase.instance.client
          .from('scheduled_nudges')
          .select('nudge_id, message_title, message_body, response_options, response_value, responded_at, scheduled_for, sent_at, source, nudge_type')
          .eq('user_id', userId)
          .not('sent_at', 'is', 'null')
          .order('sent_at', ascending: false)
          .limit(50);
      debugPrint('Nudges fetch: got ${(rows as List).length} rows');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Nudges fetch error: $e');
      return [];
    }
  }

  void _refresh() => setState(() => _future = _fetchNudges());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A6FF)));
        }
        final nudges = snapshot.data ?? [];
        if (nudges.isEmpty) {
          return const Center(child: Text('No nudges yet', style: TextStyle(color: Color(0xFF4A5168), fontSize: 14, fontFamily: 'Rajdhani')));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: nudges.length,
          itemBuilder: (context, i) => _NudgeRow(nudge: nudges[i], onResponded: _refresh),
        );
      },
    );
  }
}

class _NudgeRow extends StatelessWidget {
  final Map<String, dynamic> nudge;
  final VoidCallback onResponded;

  const _NudgeRow({required this.nudge, required this.onResponded});

  @override
  Widget build(BuildContext context) {
    final body = nudge['message_body'] as String? ?? '';
    final response = nudge['response_value'] as String?;
    final sentAt = nudge['sent_at'] as String?;
    final hasResponded = response != null && response.isNotEmpty;

    return GestureDetector(
      onTap: hasResponded ? null : () => _showRespondSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: hasResponded ? const Color(0x05FFFFFF) : const Color(0x0AFFFFFF),
          border: Border.all(color: hasResponded ? const Color(0x08FFFFFF) : const Color(0x1AC9A6FF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: hasResponded ? const Color(0x0AFFFFFF) : const Color(0x1AC9A6FF),
              ),
              child: Icon(
                hasResponded ? Icons.check_circle_outline : Icons.notifications_active_outlined,
                color: hasResponded ? const Color(0xFF4A5168) : const Color(0xFFC9A6FF),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFFF0F2F8)),
                  ),
                  const SizedBox(height: 4),
                  if (hasResponded)
                    Text(
                      'You responded: $response',
                      style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, color: Color(0xFF4ADE80)),
                    )
                  else
                    const Text(
                      'Tap to respond',
                      style: TextStyle(fontFamily: 'Rajdhani', fontSize: 12, color: Color(0xFFC9A6FF)),
                    ),
                  const SizedBox(height: 4),
                  if (sentAt != null)
                    Text(
                      _timeAgo(DateTime.parse(sentAt)),
                      style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 9, letterSpacing: 0.6, color: Color(0xFF4A5168)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRespondSheet(BuildContext context) {
    final nudgeId = nudge['nudge_id'] as String;
    List<String> options = [];
    try {
      final raw = nudge['response_options'];
      if (raw is List) {
        options = raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    if (options.isEmpty) options = ['Yes', 'Not yet', 'Skipped'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0C10),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF4A5168), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(nudge['message_body'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', color: Color(0xFFF0F2F8), fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            ...options.map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _sendResponse(nudgeId, option);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendResponse(String nudgeId, String response) async {
    try {
      final pipelineUrl = Env.sessionPipelineUrl;
      await http.post(
        Uri.parse('$pipelineUrl/nudge/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nudge_id': nudgeId, 'response_value': response}),
      );
    } catch (e) {
      try {
        await Supabase.instance.client.from('scheduled_nudges').update({
          'response_value': response,
          'responded_at': DateTime.now().toIso8601String(),
        }).eq('nudge_id', nudgeId);
      } catch (_) {}
    }
    onResponded();
  }
}

// ---------------------------------------------------------------------------
// Check-ins tab
// ---------------------------------------------------------------------------

class _CheckinsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCheckins(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A6FF)));
        }
        final checkins = snapshot.data ?? [];
        if (checkins.isEmpty) {
          return const Center(child: Text('No check-ins yet', style: TextStyle(color: Color(0xFF4A5168), fontSize: 14, fontFamily: 'Rajdhani')));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: checkins.length,
          itemBuilder: (context, i) => _CheckinRow(checkin: checkins[i]),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCheckins() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await Supabase.instance.client
          .from('ambient_checkins')
          .select('checkin_id, question_text, response_value, responded_at, sent_at, metric_type, trigger_context')
          .eq('user_id', userId)
          .not('sent_at', 'is', 'null')
          .order('sent_at', ascending: false)
          .limit(50);
      debugPrint('Checkins fetch: got ${(rows as List).length} rows');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Checkins fetch error: $e');
      return [];
    }
  }
}

class _CheckinRow extends StatelessWidget {
  final Map<String, dynamic> checkin;

  const _CheckinRow({required this.checkin});

  @override
  Widget build(BuildContext context) {
    final question = checkin['question_text'] as String? ?? '';
    final response = checkin['response_value'] as String?;
    final sentAt = checkin['sent_at'] as String?;
    final hasResponded = response != null && response.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x05FFFFFF),
        border: Border.all(color: const Color(0x08FFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0x0AFFFFFF),
            ),
            child: Icon(
              hasResponded ? Icons.chat_bubble_outline : Icons.help_outline,
              color: hasResponded ? const Color(0xFF4ADE80) : const Color(0xFF8A92A8),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFFF0F2F8))),
                const SizedBox(height: 4),
                if (hasResponded)
                  Text('You responded: $response', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, color: Color(0xFF4ADE80)))
                else
                  const Text('No response', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 12, color: Color(0xFF4A5168))),
                const SizedBox(height: 4),
                if (sentAt != null)
                  Text(_timeAgo(DateTime.parse(sentAt)), style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 9, letterSpacing: 0.6, color: Color(0xFF4A5168))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signal row (from old _NotifRow)
// ---------------------------------------------------------------------------

class _SignalRow extends StatelessWidget {
  final MonitoringEventModel event;
  final VoidCallback onTap;

  const _SignalRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = _tintColor(event);
    final isUnread = event.isUnresolved && !event.responseReceived;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isUnread ? const Color(0x0AFFFFFF) : const Color(0x05FFFFFF),
          border: Border.all(color: isUnread ? const Color(0x1AC9A6FF) : const Color(0x08FFFFFF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0x0AFFFFFF)),
              child: Icon(event.fedToSession ? Icons.mic : Icons.show_chart, color: tint, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(event.metricLabel, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFFF0F2F8)))),
                      if (isUnread) Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFC9A6FF))),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(_body(event), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, height: 1.45, color: Color(0xFF8A92A8))),
                  const SizedBox(height: 6),
                  Text(_timeAgo(event.detectedAt), style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 9, letterSpacing: 0.6, color: Color(0xFF4A5168))),
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
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

String _timeAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}