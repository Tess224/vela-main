import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/env.dart';

class TTSClient {
  Future<Uint8List> synthesize(String sentence) async {
    if (sentence.trim().isEmpty) {
      throw TTSException('Cannot synthesize empty text');
    }

    final uri = Uri.parse('${Env.sessionPipelineUrl}/voice/synthesize');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': sentence}),
    );

    if (response.statusCode != 200) {
      throw TTSException(
        'TTS failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final audioBytes = response.bodyBytes;
    if (audioBytes.isEmpty) {
      throw TTSException('TTS returned empty audio');
    }

    return audioBytes;
  }
}

class TTSException implements Exception {
  final String message;
  final int? statusCode;

  TTSException(this.message, {this.statusCode});

  @override
  String toString() => 'TTSException: $message';
}
