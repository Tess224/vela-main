import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'tts_client.dart';
import 'audio_player.dart';

class StreamHandler {
  final TTSClient _tts;
  final VelaAudioPlayer _audioPlayer;
  final void Function(double amplitude) _onAmplitude;

  final _sentenceBoundary = RegExp(r'[.!?](?=\s|$)');

  String _buffer = '';
  String _fullResponse = '';

  final Queue<Future<Uint8List>> _ttsQueue = Queue();
  bool _isPlaying = false;
  Completer<void>? _allPlayed;

  StreamHandler({
    required TTSClient tts,
    required VelaAudioPlayer audioPlayer,
    required void Function(double amplitude) onAmplitude,
  })  : _tts = tts,
        _audioPlayer = audioPlayer,
        _onAmplitude = onAmplitude;

  Future<String> handleStream(Stream<String> tokenStream) async {
    _allPlayed = Completer<void>();

    await for (final token in tokenStream) {
      _buffer += token;
      _fullResponse += token;

      final match = _sentenceBoundary.firstMatch(_buffer);
      if (match != null) {
        final sentence = _buffer.substring(0, match.end).trim();
        _buffer = _buffer.substring(match.end).trim();
        _enqueueSentence(sentence);
      }
    }

    if (_buffer.trim().isNotEmpty) {
      _enqueueSentence(_buffer.trim());
    }

    // Wait for all audio to finish playing
    if (_isPlaying || _ttsQueue.isNotEmpty) {
      await _allPlayed?.future;
    }

    return _fullResponse;
  }

  void _enqueueSentence(String sentence) {
    // Start TTS immediately (parallel synthesis)
    final future = _tts.synthesize(sentence);
    _ttsQueue.add(future);
    // Kick off playback if not already running
    _playLoop();
  }

  Future<void> _playLoop() async {
    if (_isPlaying) return;
    _isPlaying = true;

    while (_ttsQueue.isNotEmpty) {
      final future = _ttsQueue.removeFirst();
      try {
        final audioBytes = await future;
        await _audioPlayer.playBytes(audioBytes, onAmplitude: _onAmplitude);
      } catch (error) {
        debugPrint('TTS/playback error: $error');
      }
    }

    _isPlaying = false;
    if (_allPlayed != null && !_allPlayed!.isCompleted) {
      _allPlayed!.complete();
    }
  }

  String get fullResponse => _fullResponse;

  void reset() {
    _buffer = '';
    _fullResponse = '';
    _ttsQueue.clear();
    _isPlaying = false;
    if (_allPlayed != null && !_allPlayed!.isCompleted) {
      _allPlayed!.complete();
    }
    _allPlayed = null;
  }
}