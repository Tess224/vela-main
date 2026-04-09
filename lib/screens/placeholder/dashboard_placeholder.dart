// lib/screens/placeholder/dashboard_placeholder.dart
// Temporary — replaced in Build 6.4 with full dashboard.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardPlaceholder extends StatelessWidget {
  final String? highlightEventId;
  final String? recoveryEventId;

  const DashboardPlaceholder({super.key, this.highlightEventId, this.recoveryEventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, color: Colors.grey[600]),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Full dashboard coming in Build 6.4',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
              if (highlightEventId != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Event: $highlightEventId',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}