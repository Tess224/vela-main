// lib/screens/session_detail_screen.dart — View a past session transcript.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/session_record_model.dart';
import '../services/session_pipeline_service.dart';

class SessionDetailScreen extends StatelessWidget {
  final SessionRecordModel session;

  const SessionDetailScreen({super.key, required this.session});

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
        title: Text(
          session.typeLabel,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _sessionIcon(session.sessionType),
                    color: const Color(0xFFC9A6FF),
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      session.dateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    session.durationLabel,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (session.insightDelivered != null &&
                session.insightDelivered!.isNotEmpty) ...[
              const Text(
                'INSIGHT',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  color: Color(0xFFC9A6FF),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC9A6FF).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  session.insightDelivered!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (session.endedAt != null)
              _RecoverResearchButton(sessionId: session.sessionId),
            const Text(
              'TRANSCRIPT',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                color: Color(0xFF8A92A8),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                session.transcript ?? 'No transcript available.',
                style: TextStyle(
                  color: session.transcript != null
                      ? Colors.white
                      : Colors.grey[600],
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _sessionIcon(String type) {
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
class _RecoverResearchButton extends StatefulWidget {
  final String sessionId;

  const _RecoverResearchButton({required this.sessionId});

  @override
  State<_RecoverResearchButton> createState() =>
      _RecoverResearchButtonState();
}

class _RecoverResearchButtonState extends State<_RecoverResearchButton> {
  bool _busy = false;
  bool _checked = false;

  Future<void> _recover() async {
    if (_busy || _checked) return;
    setState(() => _busy = true);

    try {
      await SessionPipelineService().endSession(
        sessionId: widget.sessionId,
        transcript: '',
      );

      if (!mounted) return;
      setState(() => _checked = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Research context checked from your saved messages. '
            'Research may still need details.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not check research context: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OutlinedButton(
          onPressed: _busy || _checked ? null : _recover,
          child: Text(
            _busy
                ? 'Checking saved context…'
                : _checked
                    ? 'Context checked'
                    : 'Recover research context',
          ),
        ),
      );
}
