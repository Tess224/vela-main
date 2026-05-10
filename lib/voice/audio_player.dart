import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class VelaAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  final Queue<_PlayRequest> _queue = Queue();
  bool _isPlaying = false;

  Future<void> playBytes(
    Uint8List audioBytes, {
    required void Function(double amplitude) onAmplitude,
  }) async {
    final completer = Completer<void>();
    _queue.add(_PlayRequest(audioBytes, onAmplitude, completer));
    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_isPlaying || _queue.isEmpty) return;

    _isPlaying = true;

    while (_queue.isNotEmpty) {
      final request = _queue.removeFirst();
      try {
        debugPrint('AudioPlayer: playing ${request.bytes.length} bytes');
        final amplitude = _computeAmplitude(request.bytes);
        request.onAmplitude(amplitude);

        final source = _BytesAudioSource(request.bytes);
        await _player.setAudioSource(source);
        await _player.play();
        await _player.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );

        request.onAmplitude(0.0);
        request.completer.complete();
      } catch (error) {
        debugPrint('AudioPlayer error: $error');
        request.onAmplitude(0.0);
        request.completer.completeError(error);
      }
    }

    _isPlaying = false;
  }

  double _computeAmplitude(Uint8List audioBytes) {
    if (audioBytes.isEmpty) return 0.0;
    final sampleSize = audioBytes.length.clamp(0, 1024);
    int sum = 0;
    for (int i = 0; i < sampleSize; i++) {
      sum += (audioBytes[i] - 128).abs();
    }
    return (sum / sampleSize / 128.0).clamp(0.0, 1.0);
  }

  Future<void> stop() async {
    _queue.clear();
    await _player.stop();
  }

  void dispose() {
    _queue.clear();
    _player.dispose();
  }
}

class _PlayRequest {
  final Uint8List bytes;
  final void Function(double amplitude) onAmplitude;
  final Completer<void> completer;

  _PlayRequest(this.bytes, this.onAmplitude, this.completer);
}

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? _bytes.length;

    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: effectiveEnd - effectiveStart,
      offset: effectiveStart,
      stream: Stream.value(
        _bytes.sublist(effectiveStart, effectiveEnd),
      ),
      contentType: 'audio/mpeg',
    );
  }
}