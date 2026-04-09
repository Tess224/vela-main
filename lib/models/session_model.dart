enum SessionType { morning, evening, inMoment }

enum SessionState { idle, loading, active, ending }

enum AudioState { listening, processing, speaking, textMode }

class Exchange {
  final String userText;
  final String avatarText;

  const Exchange({this.userText = '', this.avatarText = ''});
}

class SessionModel {
  final SessionState sessionState;
  final AudioState audioState;
  final SessionType? sessionType;
  final String? sessionId;
  final String? brief;
  final double waveformAmplitude;
  final List<Exchange> recentExchanges;

  const SessionModel({
    required this.sessionState,
    required this.audioState,
    this.sessionType,
    this.sessionId,
    this.brief,
    this.waveformAmplitude = 0.0,
    this.recentExchanges = const [],
  });

  factory SessionModel.idle() => const SessionModel(
        sessionState: SessionState.idle,
        audioState: AudioState.listening,
      );

  SessionModel copyWith({
    SessionState? sessionState,
    AudioState? audioState,
    SessionType? sessionType,
    String? sessionId,
    String? brief,
    double? waveformAmplitude,
    List<Exchange>? recentExchanges,
  }) {
    return SessionModel(
      sessionState: sessionState ?? this.sessionState,
      audioState: audioState ?? this.audioState,
      sessionType: sessionType ?? this.sessionType,
      sessionId: sessionId ?? this.sessionId,
      brief: brief ?? this.brief,
      waveformAmplitude: waveformAmplitude ?? this.waveformAmplitude,
      recentExchanges: recentExchanges ?? this.recentExchanges,
    );
  }
}
