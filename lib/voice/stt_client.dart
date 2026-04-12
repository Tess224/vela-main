import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/env.dart';

/// Client for the session pipeline's /voice/transcribe endpoint.
///
/// The backend expects raw audio bytes (NOT multipart form data) with the
/// Content-Type header indicating the audio container format. The backend
/// reads the raw request body and forwards it to ElevenLabs STT.
///
/// We POST the m4a/AAC bytes directly because that's what the recorder
/// produces (AudioEncoder.aacLc → AAC in MP4 container).
class STTClient {
  Future<String> transcribe(Uint8List audioBytes) async {
    final uri = Uri.parse('${Env.sessionPipelineUrl}/voice/transcribe');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'audio/mp4'},
      body: audioBytes,
    );

    if (response.statusCode != 200) {
      throw STTException(
        'STT failed: ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = json['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw STTException('STT returned empty transcript');
    }
    return text.trim();
  }
}

class STTException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  STTException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'STTException: $message';
}
