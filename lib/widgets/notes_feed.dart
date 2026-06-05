// lib/widgets/notes_feed.dart
// Scrollable notes feed for dashboard. Shows recent vela_notes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class NotesFeed extends StatefulWidget {
  const NotesFeed({super.key});

  @override
  State<NotesFeed> createState() => _NotesFeedState();
}

class _NotesFeedState extends State<NotesFeed> {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final resp = await http.get(
        Uri.parse('${Env.sessionPipelineUrl}/notes?user_id=$userId&limit=10'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['notes'] as List).cast<Map<String, dynamic>>();
        if (mounted) setState(() { _notes = list; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String noteId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await http.post(
      Uri.parse('${Env.sessionPipelineUrl}/notes/$noteId/read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_notes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes from Vela',
            style: TextStyle(color: Colors.grey[400], fontSize: 13,
                fontFamily: 'SpaceMono', fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        ..._notes.map((note) => _NoteCard(
          note: note,
          onTap: () {
            if (note['read'] != true) _markRead(note['note_id'] as String);
            _showNoteDetail(note);
          },
        )),
      ],
    );
  }

  void _showNoteDetail(Map<String, dynamic> note) {
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
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _priorityColor(note['priority'] as String? ?? 'normal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(note['title'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                          fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(note['body'] as String,
                style: TextStyle(color: Colors.grey[300], fontSize: 14, fontFamily: 'Rajdhani')),
            const SizedBox(height: 16),
            Text(_formatType(note['note_type'] as String),
                style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'SpaceMono')),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onTap;

  const _NoteCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = note['read'] != true;
    final isPinned = note['pinned'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUnread
                  ? const Color(0xFFC9A6FF).withValues(alpha: 0.3)
                  : const Color(0xFF1A1A2E),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6, height: 6,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _priorityColor(note['priority'] as String? ?? 'normal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note['title'] as String,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnread ? Colors.white : Colors.grey[400],
                          fontSize: 14, fontFamily: 'Rajdhani', fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 2),
                    Text((note['body'] as String).length > 80
                        ? '${(note['body'] as String).substring(0, 80)}...'
                        : note['body'] as String,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'Rajdhani')),
                  ],
                ),
              ),
              if (isPinned)
                Icon(Icons.push_pin, size: 14, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'high': return const Color(0xFFC9A6FF);
    case 'normal': return const Color(0xFF4A5168);
    case 'low': return const Color(0xFF2A2D3A);
    default: return const Color(0xFF4A5168);
  }
}

String _formatType(String type) {
  return type.replaceAll('_', ' ').toUpperCase();
}