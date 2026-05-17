// lib/screens/signals_screen.dart — Signals tab.
// Shows monitoring events from Supabase, styled per prototype.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monitoring_event_model.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIGNALS',
                          style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 8,
                            letterSpacing: 1.5,
                            color: Color(0xFFC9A6FF),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Signals',
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
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0x0AFFFFFF),
                      border: Border.all(color: const Color(0x0FFFFFFF)),
                    ),
                    child: const Icon(Icons.search, color: Color(0xFF8A92A8), size: 14),
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
                  _FilterChip(label: 'All', id: 'all', active: _filter, onTap: _setFilter),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Critical', id: 'class_4', active: _filter, onTap: _setFilter),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Significant', id: 'class_3', active: _filter, onTap: _setFilter),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Notable', id: 'class_2', active: _filter, onTap: _setFilter),
                ],
              ),
            ),

            // Events list
            Expanded(
              child: FutureBuilder<List<MonitoringEventModel>>(
                future: _fetchEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFC9A6FF)),
                    );
                  }

                  final all = snapshot.data ?? [];
                  final events = _filter == 'all'
                      ? all
                      : all.where((e) => e.classification == _filter).toList();

                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        'No signals yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontFamily: 'Rajdhani',
                        ),
                      ),
                    );
                  }

                  // Split into today vs earlier
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  final today = events.where((e) => e.detectedAt.isAfter(todayStart)).toList();
                  final earlier = events.where((e) => !e.detectedAt.isAfter(todayStart)).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    children: [
                      if (today.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 10, bottom: 6),
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
                        ...today.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SignalCard(event: e, onTap: () => _showEventDetail(context, e)),
                        )),
                      ],
                      if (earlier.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 14, bottom: 6),
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
                        ...earlier.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SignalCard(event: e, onTap: () => _showEventDetail(context, e)),
                        )),
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

  void _showEventDetail(BuildContext context, MonitoringEventModel event) {
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
            _detailRow('Deviation', event.deviationScore.toStringAsFixed(1)),
            const SizedBox(height: 10),
            _detailRow('Detected', _timeAgo(event.detectedAt)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontFamily: 'SpaceMono', color: Color(0xFF4A5168), fontSize: 10)),
        ),
        Text(value, style: const TextStyle(fontFamily: 'Rajdhani', color: Color(0xFFF0F2F8), fontSize: 14)),
      ],
    );
  }

  String _timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<List<MonitoringEventModel>> _fetchEvents() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await Supabase.instance.client
          .from('monitoring_events')
          .select()
          .eq('user_id', userId)
          .order('detected_at', ascending: false)
          .limit(30);
      return (rows as List).map((r) => MonitoringEventModel.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String id;
  final String active;
  final ValueChanged<String> onTap;

  const _FilterChip({
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

class _SignalCard extends StatelessWidget {
  final MonitoringEventModel event;
  final VoidCallback onTap;

  const _SignalCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _classColor(event.classification);
    final isActive = event.isUnresolved && event.classification == 'class_4';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isActive ? color.withValues(alpha: 0.05) : const Color(0xFF0C0C10),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.2) : const Color(0x0FFFFFFF),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity bar
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: color,
                boxShadow: isActive
                    ? [BoxShadow(color: color, blurRadius: 12)]
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.metricLabel,
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFF0F2F8),
                          ),
                        ),
                      ),
                      Text(
                        event.deviationScore.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _contextLabel(event),
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: Color(0xFF8A92A8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0x0FFFFFFF)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _classLabel(event.classification),
                          style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: Color(0xFF4A5168),
                          ),
                        ),
                        Text(
                          _timeAgo(event.detectedAt),
                          style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: Color(0xFF4A5168),
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
    );
  }

  Color _classColor(String cls) {
    switch (cls) {
      case 'class_4': return const Color(0xFFC9A6FF);
      case 'class_3': return const Color(0xFFB79AF0);
      case 'class_2': return const Color(0xFF9B7FE0);
      default: return const Color(0xFF6B4FB0);
    }
  }

  String _classLabel(String cls) {
    switch (cls) {
      case 'class_4': return 'Critical';
      case 'class_3': return 'Significant';
      case 'class_2': return 'Notable';
      default: return 'Minor';
    }
  }

  String _contextLabel(MonitoringEventModel e) {
    if (e.contextResponse == 'confirmed') return 'Context confirmed';
    if (e.contextResponse == 'dismissed') return 'Dismissed';
    if (e.responseReceived) return 'Responded';
    return 'No context yet';
  }

  String _timeAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}