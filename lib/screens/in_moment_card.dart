// lib/screens/in_moment_card.dart — Popup card for class_3 monitoring events.
// User has 10 seconds. 22pt text, single Got It button, secondary context input.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InMomentCard extends StatefulWidget {
  final String interventionText;
  final String eventId;

  const InMomentCard({
    super.key,
    required this.interventionText,
    required this.eventId,
  });

  @override
  State<InMomentCard> createState() => _InMomentCardState();
}

class _InMomentCardState extends State<InMomentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _dismiss({required bool confirmed}) async {
    try {
      await Supabase.instance.client
          .from('monitoring_events')
          .update({
            'context_response': confirmed ? 'confirmed' : 'dismissed',
            'response_received': true,
          })
          .eq('event_id', widget.eventId);
    } catch (error) {
      debugPrint('In-moment dismiss error: $error');
    }

    if (mounted) {
      context.go('/dashboard');
    }
  }

  Future<void> _showAlternativeContextInput() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A2533),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "What's going on?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'A few words...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF0F1923),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onSubmitted: (text) =>
                    Navigator.of(sheetContext).pop(text.trim()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E75B6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('monitoring_events')
            .update({
              'context_response': result,
              'response_received': true,
            })
            .eq('event_id', widget.eventId);
      } catch (error) {
        debugPrint('Alternative context save error: $error');
      }

      if (mounted) {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: Dismissible(
            key: const Key('in_moment_card'),
            direction: DismissDirection.up,
            onDismissed: (_) => _dismiss(confirmed: false),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 40,
              ),
              child: Column(
                children: [
                  // Small label — does not alarm
                  Text(
                    'Right now',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Intervention text — large, readable, centred
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.interventionText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Primary action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _dismiss(confirmed: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E75B6),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Secondary — something else caused this
                  TextButton(
                    onPressed: _showAlternativeContextInput,
                    child: Text(
                      'Something else is causing this',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
