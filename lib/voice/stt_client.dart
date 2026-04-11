import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/env.dart';

class STTClient {
  Future<String> transcribe(Uint8List audioBytes) async {
    final uri = Uri.parse('${Env.sessionPipelineUrl}/voice/transcribe');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      audioBytes,
      filename: 'audio.m4a',
      contentType: MediaType('audio', 'm4a'),
    ));

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw STTException(
        'STT failed: ${streamedResponse.statusCode}',
        statusCode: streamedResponse.statusCode,
        body: body,
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
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
