import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_model.dart';
import '../providers/session_provider.dart';
import '../widgets/waveform_avatar.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final SessionType sessionType;

  const SessionScreen({super.key, required this.sessionType});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionNotifierProvider.notifier).startSession(widget.sessionType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _SessionTopBar(
              sessionType: widget.sessionType,
              isTextMode: session.audioState == AudioState.textMode,
              onToggleTextMode: () {
                ref.read(sessionNotifierProvider.notifier).toggleTextMode();
              },
              onEndSession: () {
                ref.read(sessionNotifierProvider.notifier).endSession();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            Expanded(
              flex: 6,
              child: Center(
                child: WaveformAvatar(
                  amplitude: session.waveformAmplitude,
                  state: _mapAudioState(session.audioState),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: _ExchangeDisplay(
                exchanges: session.recentExchanges,
                isTextMode: session.audioState == AudioState.textMode,
              ),
            ),
            if (session.audioState != AudioState.textMode)
              _MicStatusIndicator(audioState: session.audioState),
            if (session.audioState == AudioState.textMode)
              _TextInputBar(
                onSubmit: (text) {
                  ref.read(sessionNotifierProvider.notifier).sendText(text);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  AvatarState _mapAudioState(AudioState audioState) {
    switch (audioState) {
      case AudioState.speaking:
        return AvatarState.speaking;
      case AudioState.listening:
        return AvatarState.listening;
      case AudioState.processing:
      case AudioState.textMode:
        return AvatarState.idle;
    }
  }
}

class _SessionTopBar extends StatelessWidget {
  final SessionType sessionType;
  final bool isTextMode;
  final VoidCallback onToggleTextMode;
  final VoidCallback onEndSession;

  const _SessionTopBar({
    required this.sessionType,
    required this.isTextMode,
    required this.onToggleTextMode,
    required this.onEndSession,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            _label(sessionType),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onToggleTextMode,
            icon: Icon(
              isTextMode ? Icons.mic : Icons.keyboard,
              color: Colors.grey[400],
              size: 22,
            ),
          ),
          IconButton(
            onPressed: onEndSession,
            icon: Icon(
              Icons.close,
              color: Colors.grey[400],
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  String _label(SessionType type) {
    switch (type) {
      case SessionType.morning:
        return 'Morning check-in';
      case SessionType.evening:
        return 'Evening review';
      case SessionType.inMoment:
        return 'In the moment';
    }
  }
}

class _ExchangeDisplay extends StatelessWidget {
  final List<Exchange> exchanges;
  final bool isTextMode;

  const _ExchangeDisplay({
    required this.exchanges,
    required this.isTextMode,
  });

  @override
  Widget build(BuildContext context) {
    if (exchanges.isEmpty) {
      return Center(
        child: Text(
          isTextMode ? 'Type a message below' : 'Listening...',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      reverse: true,
      itemCount: exchanges.length,
      itemBuilder: (context, index) {
        final exchange = exchanges[exchanges.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exchange.userText.isNotEmpty)
                _TranscriptBubble(text: exchange.userText, isUser: true),
              if (exchange.avatarText.isNotEmpty)
                _TranscriptBubble(text: exchange.avatarText, isUser: false),
            ],
          ),
        );
      },
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _TranscriptBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: isUser ? Colors.grey[400] : Colors.white,
          fontSize: isUser ? 14 : 16,
          fontStyle: isUser ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class _MicStatusIndicator extends StatelessWidget {
  final AudioState audioState;

  const _MicStatusIndicator({required this.audioState});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;

    switch (audioState) {
      case AudioState.listening:
        color = const Color(0xFF375623);
        icon = Icons.mic;
      case AudioState.processing:
        color = const Color(0xFFD4A843);
        icon = Icons.hourglass_top;
      case AudioState.speaking:
        color = const Color(0xFF2E75B6);
        icon = Icons.volume_up;
      case AudioState.textMode:
        color = Colors.grey;
        icon = Icons.mic_off;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

class _TextInputBar extends StatefulWidget {
  final void Function(String text) onSubmit;

  const _TextInputBar({required this.onSubmit});

  @override
  State<_TextInputBar> createState() => _TextInputBarState();
}

class _TextInputBarState extends State<_TextInputBar> {
  final _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _submit,
            icon: const Icon(Icons.send, color: Color(0xFF2E75B6)),
          ),
        ],
      ),
    );
  }
}
