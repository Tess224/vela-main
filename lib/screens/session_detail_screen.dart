// lib/screens/session_detail_screen.dart — View a past session transcript.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/session_record_model.dart';

class SessionDetailScreen extends StatelessWidget {
  final SessionRecordModel session;

  const SessionDetailScreen({super.key, required this.session});

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
                color: const Color(0xFF1A2533),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _sessionIcon(session.sessionType),
                    color: Colors.grey[400],
                    size: 20,
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
              Text(
                'Insight',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2533),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2E75B6).withValues(alpha: 0.3),
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
            Text(
              'Transcript',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2533),
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
