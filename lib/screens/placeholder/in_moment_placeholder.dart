// lib/screens/placeholder/in_moment_placeholder.dart
// Temporary — replaced in Build 6.4 with in-moment popup card.

import 'package:flutter/material.dart';

class InMomentPlaceholder extends StatelessWidget {
  final String? eventId;
  final String? metricType;

  const InMomentPlaceholder({super.key, this.eventId, this.metricType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text(
            'In-moment card coming in Build 6.4\n${metricType ?? ""}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}