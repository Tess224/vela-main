import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class VelaAudioPlayer {
  AudioPlayer _player = AudioPlayer();

  Future<void> playBytes(
    Uint8List audioBytes, {
    required void Function(double amplitude) onAmplitude,
  }) async {
    debugPrint('AudioPlayer: playing ${audioBytes.length} bytes');
    final amplitude = _computeAmplitude(audioBytes);
    onAmplitude(amplitude);

    final tempFile = File(
      '${Directory.systemTemp.path}/vela_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await tempFile.writeAsBytes(audioBytes);

    try {
      await _player.setFilePath(tempFile.path);
      await _player.play();
      await _player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } finally {
      onAmplitude(0.0);
      try { await tempFile.delete(); } catch (_) {}
    }
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