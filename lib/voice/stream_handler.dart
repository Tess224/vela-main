import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:collection';

import 'tts_client.dart';
import 'audio_player.dart';

class StreamHandler {
  final TTSClient _tts;
  final VelaAudioPlayer _audioPlayer;
  final void Function(double amplitude) _onAmplitude;

  final _sentenceBoundary = RegExp(r'[.!?](?=\s|$)');

  String _buffer = '';
  String _fullResponse = '';

  // Sequential audio queue
  final Queue<Uint8List> _audioQueue = Queue();
  bool _isPlaying = false;
  Completer<void>? _queueDrained;

  StreamHandler({
    required TTSClient tts,
    required VelaAudioPlayer audioPlayer,
    required void Function(double amplitude) onAmplitude,
  })  : _tts = tts,
        _audioPlayer = audioPlayer,
        _onAmplitude = onAmplitude;

  Future<String> handleStream(Stream<String> tokenStream) async {
    _queueDrained = Completer<void>();

    await for (final token in tokenStream) {
      _buffer += token;
      _fullResponse += token;

      final match = _sentenceBoundary.firstMatch(_buffer);
      if (match != null) {
        final sentence = _buffer.substring(0, match.end).trim();
        _buffer = _buffer.substring(match.end).trim();
        _synthesizeAndEnqueue(sentence);
      }
    }

    // Flush remaining buffer
    if (_buffer.trim().isNotEmpty) {
      _synthesizeAndEnqueue(_buffer.trim());
    }

    // Wait for all queued audio to finish playing
    if (_isPlaying || _audioQueue.isNotEmpty) {
      await _queueDrained?.future;
    }

    return _fullResponse;
  }

  void _synthesizeAndEnqueue(String sentence) {
    _tts.synthesize(sentence).then((audioBytes) {
      _audioQueue.add(audioBytes);
      _playNext();
    }).catchError((error) {
      debugPrint('TTS error for sentence "$sentence": $error');
      _checkDrained();
    });
  }

  Future<void> _playNext() async {
    if (_isPlaying || _audioQueue.isEmpty) return;

    _isPlaying = true;

    while (_audioQueue.isNotEmpty) {
      final bytes = _audioQueue.removeFirst();
      try {
        await _audioPlayer.playBytes(bytes, onAmplitude: _onAmplitude);
      } catch (error) {
        debugPrint('Audio playback error: $error');
      }
    }

    _isPlaying = false;
    _checkDrained();
  }

  void _checkDrained() {
    if (!_isPlaying && _audioQueue.isEmpty) {
      if (_queueDrained != null && !_queueDrained!.isCompleted) {
        _queueDrained!.complete();
      }
    }
  }

  String get fullResponse => _fullResponse;

  void reset() {
    _buffer = '';
    _fullResponse = '';
    _audioQueue.clear();
    _isPlaying = false;
    if (_queueDrained != null && !_queueDrained!.isCompleted) {
      _queueDrained!.complete();
    }
    _queueDrained = null;
  }
}