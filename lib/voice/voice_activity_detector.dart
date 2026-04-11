import 'dart:async';
import 'dart:math';

enum VADEvent { speechStart, speechEnd }

class VoiceActivityDetector {
  static const double _energyThreshold = 0.01;
  static const int _silenceWindowMs = 800;

  final StreamController<VADEvent> _eventController =
      StreamController<VADEvent>.broadcast();

  Stream<VADEvent> get events => _eventController.stream;

  Timer? _silenceTimer;
  bool _isRecording = false;

  void processAudioChunk(List<double> samples) {
    final energy = _rmsEnergy(samples);

    if (energy > _energyThreshold && !_isRecording) {
      _isRecording = true;
      _silenceTimer?.cancel();
      _eventController.add(VADEvent.speechStart);
    }

    if (energy <= _energyThreshold && _isRecording) {
      _silenceTimer?.cancel();
      _silenceTimer = Timer(
        Duration(milliseconds: _silenceWindowMs),
        () {
          _isRecording = false;
          _eventController.add(VADEvent.speechEnd);
        },
      );
    }

    if (energy > _energyThreshold && _isRecording) {
      _silenceTimer?.cancel();
    }
  }

  double _rmsEnergy(List<double> samples) {
    if (samples.isEmpty) return 0;
    final sumSq = samples.fold(0.0, (s, x) => s + x * x);
    return sqrt(sumSq / samples.length);
  }

  bool get isRecording => _isRecording;

  void dispose() {
    _silenceTimer?.cancel();
    _eventController.close();
  }
}
