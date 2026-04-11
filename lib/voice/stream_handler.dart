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

  Future<String> handleStream(Stream<String> tokenStream) async {
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

    if (_buffer.trim().isNotEmpty) {
      await _speakSentenceAndWait(_buffer.trim());
    }

    return _fullResponse;
  }

  void _speakSentence(String sentence) {
    _tts.synthesize(sentence).then((audioBytes) {
      _audioPlayer.playBytes(audioBytes, onAmplitude: _onAmplitude);
    }).catchError((error) {
      debugPrint('TTS error for sentence: $error');
    });
  }

  Future<void> _speakSentenceAndWait(String sentence) async {
    try {
      final audioBytes = await _tts.synthesize(sentence);
      await _audioPlayer.playBytes(audioBytes, onAmplitude: _onAmplitude);
    } catch (error) {
      debugPrint('TTS error for final sentence: $error');
    }
  }

  String get fullResponse => _fullResponse;

  void reset() {
    _buffer = '';
    _fullResponse = '';
  }
}
