// lib/providers/session_provider.dart — Session state management.
// Manual riverpod StateNotifier — no code generation.
// Manages session lifecycle: start → active → end.
// Voice pipeline coordination lives here.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../services/session_pipeline_service.dart';

class SessionNotifier extends StateNotifier<SessionModel> {
  SessionNotifier() : super(SessionModel.idle());

  final _pipeline = SessionPipelineService.instance;
  String? _userId;

  void setUserId(String userId) => _userId = userId;

  Future<void> startSession(SessionType type, {Map<String, dynamic>? deviationContext}) async {
    if (_userId == null) return;

    state = state.copyWith(
      sessionState: SessionState.loading,
      sessionType: type,
    );

    try {
      final brief = await _pipeline.startSession(
        userId: _userId!,
        sessionType: type,
        deviationContext: deviationContext,
      );

      state = state.copyWith(
        sessionState: SessionState.active,
        sessionId: brief['session_id'] as String?,
        brief: brief['opening_message'] as String?,
      );
    } catch (e) {
      // Fall back to idle on failure
      state = SessionModel.idle();
      rethrow;
    }
  }

  // Send text message (used in text mode and as final step after STT)
  Future<String> sendText(String text) async {
    if (_userId == null || state.sessionId == null) return '';

    // Add user exchange
    final userExchange = Exchange(
      speaker: 'user',
      text: text,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      exchanges: [...state.exchanges, userExchange],
      audioState: AudioState.processing,
    );

    // Collect streamed response
    final buffer = StringBuffer();
    try {
      await for (final token in _pipeline.sendMessage(
        userId: _userId!,
        sessionId: state.sessionId!,
        text: text,
      )) {
        buffer.write(token);
      }
    } catch (e) {
      buffer.write('I had trouble connecting just now. Can you try that again?');
    }

    final response = buffer.toString();

    // Add avatar exchange
    final avatarExchange = Exchange(
      speaker: 'avatar',
      text: response,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      exchanges: [...state.exchanges, avatarExchange],
      audioState: AudioState.listening,
    );

    return response;
  }

  void updateWaveformAmplitude(double amplitude) {
    state = state.copyWith(waveformAmplitude: amplitude);
  }

  void setAudioState(AudioState audioState) {
    state = state.copyWith(audioState: audioState);
  }

  void toggleTextMode() {
    final current = state.audioState;
    state = state.copyWith(
      audioState: current == AudioState.textMode
          ? AudioState.listening
          : AudioState.textMode,
    );
  }

  Future<void> endSession() async {
    if (_userId == null || state.sessionId == null) return;

    state = state.copyWith(sessionState: SessionState.ending);

    try {
      await _pipeline.endSession(
        userId: _userId!,
        sessionId: state.sessionId!,
      );
    } catch (e) {
      // Log but don't block — session data is already on the server
    }

    state = SessionModel.idle();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionModel>((ref) {
  return SessionNotifier();
});