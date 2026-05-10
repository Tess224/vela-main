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

  StreamHandler({
    required TTSClient tts,
    required VelaAudioPlayer audioPlayer,
    required void Function(double amplitude) onAmplitude,
  })  : _tts = tts,
        _audioPlayer = audioPlayer,
        _onAmplitude = onAmplitude;

  final List<Future<void>> _pendingAudio = [];

  Future<String> handleStream(Stream<String> tokenStream) async {
    await for (final token in tokenStream) {
      _buffer += token;
      _fullResponse += token;

      final match = _sentenceBoundary.firstMatch(_buffer);
      if (match != null) {
        final sentence = _buffer.substring(0, match.end).trim();
        _buffer = _buffer.substring(match.end).trim();
        _queueSentence(sentence);
      }
    }

    if (_buffer.trim().isNotEmpty) {
      _queueSentence(_buffer.trim());
    }

    // Wait for ALL queued audio to finish playing before returning
    await Future.wait(_pendingAudio);
    _pendingAudio.clear();

    return _fullResponse;
  }

  void _queueSentence(String sentence) {
    final future = _speakSentenceAsync(sentence);
    _pendingAudio.add(future);
  }

  Future<void> _speakSentenceAsync(String sentence) async {
    try {
      final audioBytes = await _tts.synthesize(sentence);
      await _audioPlayer.playBytes(audioBytes, onAmplitude: _onAmplitude);
    } catch (error) {
      debugPrint('TTS error for sentence "$sentence": $error');
    }
  }

  String get fullResponse => _fullResponse;

  void reset() {
    _buffer = '';
    _fullResponse = '';
    _pendingAudio.clear();
  }
}
