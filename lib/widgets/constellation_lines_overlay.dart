import 'dart:math';
import 'package:flutter/material.dart';

/// Animated light lines connecting constellation members to the hub.
class ConstellationLinesOverlay extends StatefulWidget {
  final Offset hub;
  final List<Offset> memberPositions;
  final VoidCallback? onComplete;
  final VoidCallback? onLineConnected;

  const ConstellationLinesOverlay({
    super.key,
    required this.hub,
    required this.memberPositions,
    this.onComplete,
    this.onLineConnected,
  });

  @override
  State<ConstellationLinesOverlay> createState() =>
      _ConstellationLinesOverlayState();
}

class _ConstellationLinesOverlayState extends State<ConstellationLinesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<(Offset, Offset)> _segments;
  final Set<int> _hapticFired = {};
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _segments = [
      for (final p in widget.memberPositions) (widget.hub, p),
    ];
    final lineMs = 420;
    final pauseMs = 120;
    final totalMs = _segments.isEmpty
        ? 400
        : _segments.length * (lineMs + pauseMs) + 380;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..addListener(_checkLineHaptics);
    _controller.forward().whenComplete(_finish);
  }

  void _checkLineHaptics() {
    if (!mounted) return;
    final n = _segments.length;
    if (n == 0) return;
    const lineMs = 420.0;
    const pauseMs = 120.0;
    const cycle = lineMs + pauseMs;
    final durationMs = _controller.duration!.inMilliseconds.toDouble();
    for (var i = 0; i < n; i++) {
      if (_hapticFired.contains(i)) continue;
      final end = (i * cycle + lineMs) / durationMs;
      if (_controller.value >= end) {
        _hapticFired.add(i);
        widget.onLineConnected?.call();
      }
    }
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConstellationLinesPainter(
              segments: _segments,
              progress: _controller.value,
              burstT: ((_controller.value - 0.82) / 0.18).clamp(0.0, 1.0),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _ConstellationLinesPainter extends CustomPainter {
  final List<(Offset, Offset)> segments;
  final double progress;
  final double burstT;

  const _ConstellationLinesPainter({
    required this.segments,
    required this.progress,
    required this.burstT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) {
      _paintBurstOnly(canvas);
      return;
    }
    final n = segments.length;
    final lineShare = 0.72 / n;
    final pauseShare = 0.04;

    for (var i = 0; i < n; i++) {
      final segStart = i * (lineShare + pauseShare);
      final segEnd = segStart + lineShare;
      final local = ((progress - segStart) / (segEnd - segStart)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final (a, b) = segments[i];
      final head = Offset.lerp(a, b, Curves.easeOutCubic.transform(local))!;
      _paintMeteorLine(canvas, a, head, local);
      if (local >= 0.98) {
        _paintStaticLine(canvas, a, b, alpha: 0.55);
      }
    }

    if (progress > 0.78) {
      _paintBurst(canvas, segments.map((s) => s.$2).toList());
    }
  }

  void _paintMeteorLine(Canvas canvas, Offset a, Offset head, double t) {
    final dir = (head - a);
    final len = dir.distance;
    if (len < 1) return;
    final angle = atan2(dir.dy, dir.dx);
    final tailLen = min(56.0, len * 0.45);
    final tail = Offset(
      head.dx - cos(angle) * tailLen,
      head.dy - sin(angle) * tailLen,
    );
    final fade = sin(pi * t.clamp(0.0, 1.0));

    final glow = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withValues(alpha: 0.35 * fade),
          Colors.white.withValues(alpha: 0.95 * fade),
        ],
      ).createShader(Rect.fromPoints(tail, head))
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..blendMode = BlendMode.plus;
    final core = Paint()
      ..color = Colors.white.withValues(alpha: 0.92 * fade)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;

    canvas.drawLine(tail, head, glow);
    canvas.drawLine(tail, head, core);
    canvas.drawCircle(
      head,
      3.2,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  void _paintStaticLine(Canvas canvas, Offset a, Offset b, {required double alpha}) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, paint);
  }

  void _paintBurst(Canvas canvas, List<Offset> points) {
    if (burstT <= 0) return;
    final rng = Random(7);
    for (final p in points) {
      for (var i = 0; i < 10; i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final dist = (4 + rng.nextDouble() * 18) * burstT;
        final particle = Offset(
          p.dx + cos(angle) * dist,
          p.dy + sin(angle) * dist,
        );
        canvas.drawCircle(
          particle,
          1.1 * (1 - burstT * 0.6),
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - burstT) * 0.85)
            ..blendMode = BlendMode.plus,
        );
      }
    }
  }

  void _paintBurstOnly(Canvas canvas) {
    if (burstT <= 0) return;
    _paintBurst(canvas, const []);
  }

  @override
  bool shouldRepaint(covariant _ConstellationLinesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.burstT != burstT;
  }
}
