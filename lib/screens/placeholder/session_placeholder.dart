// lib/screens/placeholder/session_placeholder.dart
// Temporary — replaced in Build 6.3 with voice session screen.

import 'package:flutter/material.dart';

class SessionPlaceholder extends StatelessWidget {
  final String? sessionType;
  final String? eventId;

  const SessionPlaceholder({super.key, this.sessionType, this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text(
            'Session screen coming in Build 6.3\n${sessionType ?? ""}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}