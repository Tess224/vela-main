import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../models/session_model.dart';
import '../services/session_pipeline_service.dart';
import '../voice/audio_player.dart';
import '../voice/stt_client.dart';
import '../voice/stream_handler.dart';
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

  // -- Public API --

  Future<void> startSession(SessionType type) async {
    state = state.copyWith(
      sessionState: SessionState.loading,
      sessionType: type,
      audioState: AudioState.processing,
    );

    try {
      final brief = await _pipelineService.fetchBrief(type.name);

      state = state.copyWith(
        sessionState: SessionState.active,
        brief: brief,
      );

      await _speakResponse(brief);
      await _beginVoicePipeline();
    } catch (error) {
      state = state.copyWith(sessionState: SessionState.idle);
      debugPrint('Session start error: $error');
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

    state = state.copyWith(audioState: AudioState.processing);

    final exchanges = List<Exchange>.from(state.recentExchanges)
      ..add(Exchange(userText: text));
    state = state.copyWith(recentExchanges: exchanges);

    try {
      final tokenStream = _pipelineService.sendMessage(
        text,
        sessionType: state.sessionType?.name ?? 'morning',
      );

      _streamHandler.reset();
      state = state.copyWith(audioState: AudioState.speaking);

      final fullResponse = await _streamHandler.handleStream(tokenStream);

      final updated = List<Exchange>.from(state.recentExchanges);
      if (updated.isNotEmpty) {
        final last = updated.removeLast();
        updated.add(Exchange(userText: last.userText, avatarText: fullResponse));
      }

      state = state.copyWith(
        recentExchanges: updated,
        audioState: AudioState.textMode,
        waveformAmplitude: 0.0,
      );
    } catch (error) {
      state = state.copyWith(audioState: AudioState.textMode);
      debugPrint('Send text error: $error');
    }
  }

  // -- Voice pipeline (private) --

  Future<void> _beginVoicePipeline() async {
    if (!await _recorder.hasPermission()) return;

    state = state.copyWith(audioState: AudioState.listening);
    _vadSubscription = _vad.events.listen(_onVADEvent);

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: '',
    );

    _startAmplitudePolling();
  }

  Future<void> _stopVoicePipeline() async {
    _vadSubscription?.cancel();
    _vadSubscription = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    await _recorder.stop();
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
    switch (event) {
      case VADEvent.speechStart:
        break;

      case VADEvent.speechEnd:
        state = state.copyWith(audioState: AudioState.processing);

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

          final transcript = await _stt.transcribe(Uint8List.fromList(audioBytes));

          final exchanges = List<Exchange>.from(state.recentExchanges)
            ..add(Exchange(userText: transcript));
          state = state.copyWith(recentExchanges: exchanges);

          final tokenStream = _pipelineService.sendMessage(
            transcript,
            sessionType: state.sessionType?.name ?? 'morning',
          );

          _streamHandler.reset();
          state = state.copyWith(audioState: AudioState.speaking);

          final fullResponse = await _streamHandler.handleStream(tokenStream);

          final updated = List<Exchange>.from(state.recentExchanges);
          if (updated.isNotEmpty) {
            final last = updated.removeLast();
            updated.add(
              Exchange(userText: last.userText, avatarText: fullResponse),
            );
          }

          state = state.copyWith(
            recentExchanges: updated,
            waveformAmplitude: 0.0,
          );

          await _beginVoicePipeline();
        } catch (error) {
          debugPrint('Voice pipeline error: $error');
          await _beginVoicePipeline();
        }
        break;
    }
  }

  Future<void> _speakResponse(String text) async {
    state = state.copyWith(audioState: AudioState.speaking);

    try {
      final audioBytes = await _tts.synthesize(text);
      await _audioPlayer.playBytes(audioBytes, onAmplitude: _updateAmplitude);
    } catch (error) {
      debugPrint('Speak response error: $error');
    }

    state = state.copyWith(
      audioState: AudioState.listening,
      waveformAmplitude: 0.0,
    );
  }

  void _updateAmplitude(double amplitude) {
    state = state.copyWith(waveformAmplitude: amplitude);
  }

  Future<void> _saveTranscriptAndTriggerExtraction() async {
    if (state.recentExchanges.isEmpty) return;

    try {
      await _pipelineService.endSession(
        exchanges: state.recentExchanges,
        sessionType: state.sessionType?.name ?? 'morning',
      );
    } catch (error) {
      debugPrint('Save transcript error: $error');
    }
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
