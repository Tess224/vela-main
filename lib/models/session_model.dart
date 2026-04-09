// lib/models/session_model.dart — Session state model.
// Tracks session lifecycle, audio state, exchanges, and waveform amplitude.

enum SessionState { idle, loading, active, ending }

enum AudioState { listening, processing, speaking, textMode }

enum SessionType { morning, evening, inMoment }

class Exchange {
  final String speaker; // 'user' or 'avatar'
  final String text;
  final DateTime timestamp;

  const Exchange({
    required this.speaker,
    required this.text,
    required this.timestamp,
  });
}

class SessionModel {
  final SessionState sessionState;
  final AudioState audioState;
  final SessionType? sessionType;
  final String? sessionId;
  final List<Exchange> exchanges;
  final double waveformAmplitude;
  final String? brief; // from reasoning layer
  final String? deviationContext; // for in-moment sessions

  const SessionModel({
    this.sessionState = SessionState.idle,
    this.audioState = AudioState.listening,
    this.sessionType,
    this.sessionId,
    this.exchanges = const [],
    this.waveformAmplitude = 0.0,
    this.brief,
    this.deviationContext,
  });

  factory SessionModel.idle() => const SessionModel();

  List<Exchange> get recentExchanges =>
      exchanges.length > 6 ? exchanges.sublist(exchanges.length - 6) : exchanges;

  SessionModel copyWith({
    SessionState? sessionState,
    AudioState? audioState,
    SessionType? sessionType,
    String? sessionId,
    List<Exchange>? exchanges,
    double? waveformAmplitude,
    String? brief,
    String? deviationContext,
  }) {
    return SessionModel(
      sessionState: sessionState ?? this.sessionState,
      audioState: audioState ?? this.audioState,
      sessionType: sessionType ?? this.sessionType,
      sessionId: sessionId ?? this.sessionId,
      exchanges: exchanges ?? this.exchanges,
      waveformAmplitude: waveformAmplitude ?? this.waveformAmplitude,
      brief: brief ?? this.brief,
      deviationContext: deviationContext ?? this.deviationContext,
    );
  }
}