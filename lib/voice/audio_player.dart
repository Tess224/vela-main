import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:just_audio/just_audio.dart';

class VelaAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playBytes(
    Uint8List audioBytes, {
    required void Function(double amplitude) onAmplitude,
  }) async {
    debugPrint('AudioPlayer: playing ${audioBytes.length} bytes');
    final amplitude = _computeAmplitude(audioBytes);
    onAmplitude(amplitude);

    final source = _BytesAudioSource(audioBytes);
    await _player.setAudioSource(source);
    await _player.play();

    await _player.playerStateStream.firstWhere(
      (state) => state.processingState == ProcessingState.completed,
    );

    onAmplitude(0.0);
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
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
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
