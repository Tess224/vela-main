// lib/screens/onboarding/welcome_screen.dart — First impression.
// Explains what Vela does and why wearable access matters.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Image.asset(
                'assets/icon/vela_logo.png',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 16),
              Text(
                'Your AI health companion',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 48),
              _InfoItem(
                text: 'Vela learns your body\'s unique patterns from your wearable data.',
              ),
              const SizedBox(height: 20),
              _InfoItem(
                text: 'Morning and evening voice check-ins that get smarter over time.',
              ),
              const SizedBox(height: 20),
              _InfoItem(
                text: 'Real-time alerts when something shifts — with context, not alarms.',
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/permissions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E75B6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Get started',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String text;
  const _InfoItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 8, right: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF2E75B6),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}