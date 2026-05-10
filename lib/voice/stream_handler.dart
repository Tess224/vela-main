import 'package:flutter/foundation.dart';
import 'dart:async';

import 'tts_client.dart';
import 'audio_player.dart';

class StreamHandler {
  final TTSClient _tts;
  final VelaAudioPlayer _audioPlayer;
  final void Function(double amplitude) _onAmplitude;

  final _sentenceBoundary = RegExp(r'[.!?](?=\s|$)');

  String _buffer = '';
  String _fullResponse = '';
  final List<String> debugLog = [];

  StreamHandler({
    required TTSClient tts,
    required VelaAudioPlayer audioPlayer,
    required void Function(double amplitude) onAmplitude,
  })  : _tts = tts,
        _audioPlayer = audioPlayer,
        _onAmplitude = onAmplitude;

  Future<String> handleStream(Stream<String> tokenStream) async {
    debugLog.add('STREAM: started');

    await for (final token in tokenStream) {
      _buffer += token;
      _fullResponse += token;

      final match = _sentenceBoundary.firstMatch(_buffer);
      if (match != null) {
        final sentence = _buffer.substring(0, match.end).trim();
        _buffer = _buffer.substring(match.end).trim();
        _speakSentence(sentence);
      }
    }

    debugLog.add('STREAM: tokens done');

    if (_buffer.trim().isNotEmpty) {
      await _speakSentenceAndWait(_buffer.trim());
    }

    debugLog.add('STREAM: complete');
    return _fullResponse;
  }

  void _speakSentence(String sentence) {
    final preview = sentence.length > 30 ? '${sentence.substring(0, 30)}...' : sentence;
    debugLog.add('TTS: "$preview"');
    _tts.synthesize(sentence).then((audioBytes) {
      debugLog.add('TTS: ${audioBytes.length} bytes');
      _audioPlayer.playBytes(audioBytes, onAmplitude: _onAmplitude);
    }).catchError((error) {
      debugLog.add('TTS FAIL: $error');
    });
  }

  Future<void> _speakSentenceAndWait(String sentence) async {
    final preview = sentence.length > 30 ? '${sentence.substring(0, 30)}...' : sentence;
    debugLog.add('TTS-W: "$preview"');
    try {
      final audioBytes = await _tts.synthesize(sentence);
      debugLog.add('TTS-W: ${audioBytes.length} bytes, playing');
      await _audioPlayer.playBytes(audioBytes, onAmplitude: _onAmplitude);
      debugLog.add('TTS-W: done');
    } catch (error) {
      debugLog.add('TTS-W FAIL: $error');
    }
  }

  String get fullResponse => _fullResponse;

  void reset() {
    _buffer = '';
    _fullResponse = '';
  }
}