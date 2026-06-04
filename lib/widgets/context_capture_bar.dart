// lib/widgets/context_capture_bar.dart
// Persistent dashboard widget for reporting current activity.
// Text input + mic button + quick chips.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class ContextCaptureBar extends StatefulWidget {
  const ContextCaptureBar({super.key});

  @override
  State<ContextCaptureBar> createState() => _ContextCaptureBarState();
}

class _ContextCaptureBarState extends State<ContextCaptureBar> {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  bool _sending = false;
  bool _recording = false;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _submit(String text) async {
    if (text.trim().length < 2 || _sending || _userId == null) return;

    setState(() => _sending = true);
    try {
      final resp = await http.post(
        Uri.parse('${Env.sessionPipelineUrl}/context-capture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId, 'text': text.trim()}),
      );

      if (resp.statusCode == 200 && mounted) {
        _controller.clear();
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged: ${data['activity_type'] ?? 'activity'}',
                style: const TextStyle(fontFamily: 'Rajdhani')),
            backgroundColor: const Color(0xFF1A1A2E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitAudio(String audioBase64) async {
    if (_sending || _userId == null) return;

    setState(() => _sending = true);
    try {
      final resp = await http.post(
        Uri.parse('${Env.sessionPipelineUrl}/context-capture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId, 'audio_base64': audioBase64}),
      );

      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged: ${data['activity_type'] ?? 'activity'}',
                style: const TextStyle(fontFamily: 'Rajdhani')),
            backgroundColor: const Color(0xFF1A1A2E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice failed: $e'), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final tempDir = Directory.systemTemp;
    final tempPath = '${tempDir.path}/vela_capture_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: tempPath);
    setState(() => _recording = true);
  }

  Future<void> _stopAndSend() async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (path == null) return;

    try {
      final audioBytes = await File(path).readAsBytes();
      if (audioBytes.isEmpty) return;
      final base64Audio = base64Encode(audioBytes);
      await _submitAudio(base64Audio);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Studying', 'Resting', 'Walking', 'Working', 'Exercising']
                .map((label) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(label, style: const TextStyle(
                          fontSize: 12, color: Color(0xFFF0F2F8), fontFamily: 'Rajdhani',
                        )),
                        backgroundColor: const Color(0xFF0C0C10),
                        side: const BorderSide(color: Color(0xFF1A1A2E)),
                        onPressed: _sending ? null : () => _submit(label),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Color(0xFFF0F2F8), fontSize: 14, fontFamily: 'Rajdhani'),
                decoration: InputDecoration(
                  hintText: 'What are you doing right now?',
                  hintStyle: const TextStyle(color: Color(0xFF4A5168), fontSize: 14, fontFamily: 'Rajdhani'),
                  filled: true,
                  fillColor: const Color(0xFF0C0C10),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1A1A2E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC9A6FF), width: 0.5),
                  ),
                ),
                onSubmitted: _sending ? null : _submit,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _toggleRecording,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _recording
                      ? const Color(0xFFC9A6FF).withValues(alpha: 0.2)
                      : const Color(0xFF0C0C10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _recording ? const Color(0xFFC9A6FF) : const Color(0xFF1A1A2E),
                  ),
                ),
                child: Icon(
                  _recording ? Icons.stop : Icons.mic_outlined,
                  color: _recording ? const Color(0xFFC9A6FF) : const Color(0xFF4A5168),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : () => _submit(_controller.text),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A6FF).withValues(alpha: _sending ? 0.3 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _sending
                    ? const Center(child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC9A6FF)),
                      ))
                    : const Icon(Icons.send, color: Color(0xFFC9A6FF), size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}