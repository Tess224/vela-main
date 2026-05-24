import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class NudgeResponseScreen extends StatelessWidget {
  final String nudgeId;
  final String messageBody;
  final List<String> responseOptions;
  final String type; // 'ambient_nudge' or 'ambient_checkin'
  final String? checkinId;

  const NudgeResponseScreen({
    super.key,
    required this.nudgeId,
    required this.messageBody,
    required this.responseOptions,
    required this.type,
    this.checkinId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vela',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                messageBody,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ...responseOptions.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _respond(context, option),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      option,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _respond(BuildContext context, String response) async {
    try {
      final pipelineUrl = Env.sessionPipelineUrl;
      if (type == 'ambient_checkin' && checkinId != null) {
        await http.post(
          Uri.parse('$pipelineUrl/checkin/respond'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'checkin_id': checkinId,
            'response_value': response,
          }),
        );
      } else {
        await http.post(
          Uri.parse('$pipelineUrl/nudge/respond'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nudge_id': nudgeId,
            'response_value': response,
          }),
        );
      }
    } catch (e) {
      debugPrint('Response failed: $e');
    }

    if (context.mounted) {
      context.go('/dashboard');
    }
  }
}