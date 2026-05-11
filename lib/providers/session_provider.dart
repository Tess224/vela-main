// lib/providers/session_provider.dart
//
// Build 6.3 + Build 4 streaming integration.
// Voice session lifecycle and state machine for the session screen.
//
// Flow:
//   startSession()
//     -> voice pipeline starts (VAD listening)
//     -> immediately fires a kickoff turn with empty text
//     -> Claude opens the session via /session/stream
//     -> first SSE event captures session_id
//     -> opening text streams in, speaks via TTS, user sees it
//     -> returns to listening
//   user speaks
//     -> VAD detects end of speech -> STT -> /session/stream -> stream + speak
//     -> loop
//   endSession() -> /session/end -> transcript saved, post-processing runs

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';


import '../models/session_model.dart';
import '../services/session_pipeline_service.dart';
import '../voice/audio_player.dart';
import '../voice/stream_handler.dart';
import '../voice/stt_client.dart';
import '../voice/tts_client.dart';
import '../voice/voice_activity_detector.dart';

final sessionNotifierProvider =
    StateNotifierProvider<SessionNotifier, SessionModel>(
  (ref) => SessionNotifier(ref),
);

class SessionNotifier extends StateNotifier<SessionModel> {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceActivityDetector _vad = VoiceActivityDetector();
  final STTClient _stt = STTClient();
  final TTSClient _tts = TTSClient();
  final VelaAudioPlayer _audioPlayer = VelaAudioPlayer();
  late final StreamHandler _streamHandler;
  final SessionPipelineService _pipelineService = SessionPipelineService();

  StreamSubscription<VADEvent>? _vadSubscription;
  Timer? _amplitudeTimer;

  SessionNotifier(Ref ref) : super(SessionModel.idle()) {
    _streamHandler = StreamHandler(
      tts: _tts,
      audioPlayer: _audioPlayer,
      onAmplitude: _updateAmplitude,
    );
  }

  // ---------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------

  Future<void> startSession(SessionType type) async {
    state = state.copyWith(
      sessionState: SessionState.loading,
      sessionType: type,
      audioState: AudioState.processing,
      sessionId: null,
      recentExchanges: const [],
    );

    try {
      state = state.copyWith(sessionState: SessionState.active);

      // Fire the opening turn. Empty text + empty history tells the backend
      // to auto-inject "Start the session." and have Claude generate the
      // greeting. This replaces the old /brief + _speakResponse flow.
      await _runSessionTurn(userText: '', isKickoff: true);

      // After the opening is spoken, begin listening for the user
      await _beginVoicePipeline();
    } catch (error) {
      debugPrint('Session start error: $error');
      state = state.copyWith(sessionState: SessionState.idle);
    }
  }

  Future<void> endSession() async {
    state = state.copyWith(sessionState: SessionState.ending);
    await _stopVoicePipeline();
    await _saveTranscriptAndTriggerExtraction();
    state = SessionModel.idle();
  }

  void toggleTextMode() {
    if (state.audioState == AudioState.textMode) {
      state = state.copyWith(audioState: AudioState.listening);
      _beginVoicePipeline();
    } else {
      _stopVoicePipeline();
      state = state.copyWith(audioState: AudioState.textMode);
    }
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;
    await _runSessionTurn(userText: text, isKickoff: false);
    // Stay in text mode after sending (user explicitly chose text mode)
    if (state.audioState != AudioState.textMode) {
      state = state.copyWith(audioState: AudioState.textMode);
    }
  }

  // ---------------------------------------------------------------------
  // Core turn runner — used by opening, voice, and text paths
  // ---------------------------------------------------------------------

  /// Runs a single turn against the session pipeline.
  /// - On kickoff (userText empty, no sessionId), triggers the opening.
  /// - On subsequent turns, appends the new user message to recentExchanges,
  ///   streams the assistant response, and updates the exchange with it.
  Future<void> _runSessionTurn({
    required String userText,
    required bool isKickoff,
  }) async {
    // Append user turn to exchanges (unless kickoff — backend auto-injects)
    if (!isKickoff && userText.isNotEmpty) {
      final exchanges = List<Exchange>.from(state.recentExchanges)
        ..add(Exchange(userText: userText));
      state = state.copyWith(recentExchanges: exchanges);
    }

    state = state.copyWith(audioState: AudioState.processing);

    // Build conversation history from *completed* exchanges only.
    // The current user turn we just added has empty avatarText, so it's
    // excluded here — the backend will see it via the `message` field instead.
    final history = _buildConversationHistory(excludeIncomplete: true);

    _streamHandler.reset();
    state = state.copyWith(audioState: AudioState.speaking);

    try {
      final tokenStream = _pipelineService.sendMessage(
        userText,
        sessionType: state.sessionType?.name ?? 'morning',
        sessionId: state.sessionId,
        conversationHistory: history,
        onSessionStart: (metadata) {
          // Capture session_id on turn 1, reuse on later turns
          if (state.sessionId == null) {
            state = state.copyWith(sessionId: metadata.sessionId);
          }
        },
      );

      final fullResponse = await _streamHandler.handleStream(tokenStream);

      // Attach the response to the appropriate exchange
      if (isKickoff) {
        // Kickoff: the opening is a standalone assistant turn with no user text
        final exchanges = List<Exchange>.from(state.recentExchanges)
          ..add(Exchange(avatarText: fullResponse));
        state = state.copyWith(recentExchanges: exchanges);
      } else {
        // Normal turn: update the last exchange (user-only) with the response
        final updated = List<Exchange>.from(state.recentExchanges);
        if (updated.isNotEmpty) {
          final last = updated.removeLast();
          updated.add(Exchange(
            userText: last.userText,
            avatarText: fullResponse,
          ));
        }
        state = state.copyWith(recentExchanges: updated);
      }

      state = state.copyWith(waveformAmplitude: 0.0);
    } catch (error) {
      debugPrint('Session turn error: $error');
      state = state.copyWith(
        waveformAmplitude: 0.0,
        audioState: AudioState.listening,
      );
    }
  }

  /// Converts recentExchanges into a flat conversation history for the backend.
  /// Each Exchange with non-empty userText emits a user turn.
  /// Each Exchange with non-empty avatarText emits an assistant turn.
  /// If excludeIncomplete is true, exchanges missing avatarText (i.e. the
  /// current pending turn) are filtered out — used when we're about to
  /// send the user message via the `message` field rather than as history.
  List<ConversationTurn> _buildConversationHistory({
    required bool excludeIncomplete,
  }) {
    final history = <ConversationTurn>[];
    for (final exchange in state.recentExchanges) {
      final isIncomplete = exchange.avatarText.isEmpty;
      if (excludeIncomplete && isIncomplete) continue;

      if (exchange.userText.isNotEmpty) {
        history.add(ConversationTurn(
          role: ConversationRole.user,
          content: exchange.userText,
        ));
      }
      if (exchange.avatarText.isNotEmpty) {
        history.add(ConversationTurn(
          role: ConversationRole.assistant,
          content: exchange.avatarText,
        ));
      }
    }
    return history;
  }

  // ---------------------------------------------------------------------
  // Voice pipeline (private)
  // ---------------------------------------------------------------------

  Future<void> _beginVoicePipeline() async {
    final micStatus = await Permission.microphone.request();

    debugPrint('Microphone status: $micStatus');

    if (!micStatus.isGranted) {
      debugPrint('Voice pipeline: microphone permission denied');
      state = state.copyWith(audioState: AudioState.textMode);
      return;
    }

    // Cancel any stale subscription before starting a new one
    await _vadSubscription?.cancel();
    _vadSubscription = null;

    state = state.copyWith(audioState: AudioState.listening);
    _vadSubscription = _vad.events.listen(_onVADEvent);

    final tempDir = Directory.systemTemp;
    final tempPath = '${tempDir.path}/vela_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    debugPrint('STARTING RECORDER');

await _audioPlayer.stop();

await Future.delayed(const Duration(milliseconds: 1200));

await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: tempPath,
    );
      
    _startAmplitudePolling();
  }

  Future<void> _stopVoicePipeline() async {
    await _vadSubscription?.cancel();
    _vadSubscription = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // Recorder may not be running — ignore
    }
    await _audioPlayer.stop();
  }

  void _startAmplitudePolling() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (state.sessionState != SessionState.active) {
        timer.cancel();
        return;
      }
      _recorder.getAmplitude().then((amp) {
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        _vad.processAudioChunk([normalized]);
      }).catchError((_) {});
    });
  }

  Future<void> _onVADEvent(VADEvent event) async {
    debugPrint('VAD EVENT: $event');

    switch (event) {

      case VADEvent.speechStart:
        // Recording is already active — nothing to do here
        break;

      case VADEvent.speechEnd:
        try {
          final path = await _recorder.stop();
          if (path == null) {
            await _beginVoicePipeline();
            return;
          }

          final audioBytes = await File(path).readAsBytes();
          if (audioBytes.isEmpty) {
            await _beginVoicePipeline();
            return;
          }

          debugPrint('Sending audio to STT: ${audioBytes.length} bytes');

          final transcript = await _stt.transcribe(audioBytes);

          debugPrint('STT TRANSCRIPT: $transcript');
          if (transcript.trim().isEmpty) {
            await _beginVoicePipeline();
            return;
          }

          await _runSessionTurn(userText: transcript, isKickoff: false);

          // After speaking response, resume listening for next turn
          await Future.delayed(const Duration(milliseconds: 400));
          await _beginVoicePipeline();
        } catch (error) {
          debugPrint('Voice pipeline error: $error');
          await _beginVoicePipeline();
        }
        break;
    }
  }

  // ---------------------------------------------------------------------
  // Session end — build transcript, call backend
  // ---------------------------------------------------------------------

  Future<void> _saveTranscriptAndTriggerExtraction() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.recentExchanges.isEmpty) {
      debugPrint('Session end: no session_id or no exchanges — skipping');
      return;
    }

    final transcript = _buildTranscriptText(state.recentExchanges);

    try {
      await _pipelineService.endSession(
        sessionId: sessionId,
        transcript: transcript,
      );
    } catch (error) {
      debugPrint('Save transcript error: $error');
    }
  }

  String _buildTranscriptText(List<Exchange> exchanges) {
    return exchanges.map((e) {
      final parts = <String>[];
      if (e.userText.isNotEmpty) parts.add('USER: ${e.userText}');
      if (e.avatarText.isNotEmpty) parts.add('VELA: ${e.avatarText}');
      return parts.join('\n\n');
    }).join('\n\n');
  }


  void _updateAmplitude(double amplitude) {
    state = state.copyWith(waveformAmplitude: amplitude);
  }

  @override
  void dispose() {
    _vadSubscription?.cancel();
    _amplitudeTimer?.cancel();
    _vad.dispose();
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }
}
