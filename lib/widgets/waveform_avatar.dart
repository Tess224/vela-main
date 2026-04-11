import 'dart:math';

import 'package:flutter/material.dart';

enum AvatarState { speaking, listening, idle }

class WaveformAvatar extends StatefulWidget {
  final double amplitude;
  final AvatarState state;

  const WaveformAvatar({
    super.key,
    required this.amplitude,
    required this.state,
  });

  @override
  State<WaveformAvatar> createState() => _WaveformAvatarState();
}

class _WaveformAvatarState extends State<WaveformAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _smoothAmplitude = 0.0;
  double _targetAmplitude = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_interpolateAmplitude);
    _controller.repeat();
  }

  void _interpolateAmplitude() {
    setState(() {
      _smoothAmplitude += (_targetAmplitude - _smoothAmplitude) * 0.15;
    });
  }

  @override
  void didUpdateWidget(WaveformAvatar old) {
    super.didUpdateWidget(old);
    _targetAmplitude = widget.amplitude;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(240, 240),
      painter: _WaveformPainter(
        amplitude: _smoothAmplitude,
        state: widget.state,
        tick: _controller.value,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double amplitude;
  final AvatarState state;
  final double tick;

  _WaveformPainter({
    required this.amplitude,
    required this.state,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const bars = 32;

    for (int i = 0; i < bars; i++) {
      final angle = (i / bars) * 2 * pi;
      final noise = sin(angle * 3 + amplitude * 10) * 0.4 + 0.6;

      final double barLen;
      switch (state) {
        case AvatarState.speaking:
          barLen = 20.0 + amplitude * 60.0 * noise;
        case AvatarState.listening:
          barLen = 8.0 + sin(angle + tick * 2 * pi) * 4;
        case AvatarState.idle:
          barLen = 6.0 + sin(i * 0.5 + tick * 2 * pi) * 3;
      }

      const r1 = 70.0;
      final r2 = r1 + barLen;

      final x1 = cx + cos(angle) * r1;
      final y1 = cy + sin(angle) * r1;
      final x2 = cx + cos(angle) * r2;
      final y2 = cy + sin(angle) * r2;

      final paint = Paint()
        ..color = _barColor(state).withValues(alpha: 0.7 + amplitude * 0.3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  Color _barColor(AvatarState state) {
    switch (state) {
      case AvatarState.speaking:
        return const Color(0xFF2E75B6);
      case AvatarState.listening:
        return const Color(0xFF375623);
      case AvatarState.idle:
        return const Color(0xFF595959);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.amplitude != amplitude || old.state != state || old.tick != tick;
}
