import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/constellation_layout.dart';

/// Constellation resonance save animation (Option B): main star ignites,
/// emerald ripple spreads along lines to context stars, then all collapse
/// into the galaxy center.
class ConstellationResonanceOverlay extends StatelessWidget {
  final Animation<double> animation;
  final Color mainStarColor;
  final List<Color> contextStarColors;

  static const Color _emeraldCore = Color(0xFF3DDC97);
  static const Color _emeraldGlow = Color(0xFF50C878);
  static const Color _emeraldBright = Color(0xFF9FFFD4);

  static const double _igniteEnd = 0.12;
  static const double _rippleEnd = 0.52;
  static const double _resonateEnd = 0.72;

  const ConstellationResonanceOverlay({
    super.key,
    required this.animation,
    required this.mainStarColor,
    this.contextStarColors = const [],
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hub = Offset(size.width / 2, size.height * 0.36);
    final radius = min(118.0, size.width * 0.28);
    final contextPositions = constellationLayoutSlots(
      contextStarColors.length,
      hub,
      radius: radius,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final collapseT = t <= _resonateEnd
            ? 0.0
            : Curves.easeInCubic.transform(
                ((t - _resonateEnd) / (1.0 - _resonateEnd)).clamp(0.0, 1.0),
              );
        final sceneOpacity = collapseT > 0.82
            ? (1.0 - ((collapseT - 0.82) / 0.18)).clamp(0.0, 1.0)
            : 1.0;

        return IgnorePointer(
          child: Opacity(
            opacity: sceneOpacity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ResonanceLinesPainter(
                    hub: hub,
                    contextPositions: contextPositions,
                    progress: t,
                    contextCount: contextStarColors.length,
                  ),
                ),
                _buildMainStar(hub, t, collapseT),
                for (var i = 0; i < contextStarColors.length; i++)
                  _buildContextStar(
                    contextPositions[i],
                    hub,
                    contextStarColors[i],
                    i,
                    t,
                    collapseT,
                  ),
                if (collapseT > 0.05)
                  CustomPaint(
                    painter: _CollapseBurstPainter(
                      center: hub,
                      progress: collapseT,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainStar(Offset hub, double t, double collapseT) {
    final ignite = Curves.easeOut.transform((t / _igniteEnd).clamp(0.0, 1.0));
    final resonatePulse = t >= _rippleEnd && t < _resonateEnd
        ? 1.0 +
            sin(((t - _rippleEnd) / (_resonateEnd - _rippleEnd)) * pi * 3) *
                0.12
        : 1.0;
    final glow = (ignite * 0.35 + (t >= _igniteEnd ? 0.65 : 0.0)) *
        resonatePulse *
        (1.0 - collapseT * 0.85);
    final starSize = lerpDouble(34, 8, collapseT)! * (1.0 + ignite * 0.18);
    final pos = Offset.lerp(hub, hub, collapseT)!;

    return Positioned(
      left: pos.dx - starSize,
      top: pos.dy - starSize,
      child: _ResonanceStar(
        size: starSize * 2,
        baseColor: mainStarColor,
        emeraldMix: (0.55 + ignite * 0.45).clamp(0.0, 1.0),
        glow: glow,
        isMain: true,
      ),
    );
  }

  Widget _buildContextStar(
    Offset slot,
    Offset hub,
    Color baseColor,
    int index,
    double t,
    double collapseT,
  ) {
    final rippleStart = _igniteEnd + index * 0.09;
    final rippleReach =
        Curves.easeOut.transform(((t - rippleStart) / 0.14).clamp(0.0, 1.0));
    final lit = rippleReach > 0.02;
    final resonatePulse = t >= _rippleEnd && t < _resonateEnd && lit
        ? 1.0 +
            sin(((t - _rippleEnd) / (_resonateEnd - _rippleEnd)) * pi * 3 +
                    index * 0.8) *
                0.1
        : 1.0;
    final glow = lit ? rippleReach * 0.85 * resonatePulse * (1 - collapseT) : 0.0;
    final starSize = lerpDouble(20, 6, collapseT)!;
    final pos = Offset.lerp(slot, hub, collapseT)!;

    if (!lit && collapseT <= 0) return const SizedBox.shrink();

    return Positioned(
      left: pos.dx - starSize,
      top: pos.dy - starSize,
      child: Opacity(
        opacity: lit ? 1.0 : 0.0,
        child: _ResonanceStar(
          size: starSize * 2,
          baseColor: baseColor,
          emeraldMix: lit ? (0.35 + rippleReach * 0.65) : 0.0,
          glow: glow,
          isMain: false,
        ),
      ),
    );
  }
}

class _ResonanceStar extends StatelessWidget {
  final double size;
  final Color baseColor;
  final double emeraldMix;
  final double glow;
  final bool isMain;

  const _ResonanceStar({
    required this.size,
    required this.baseColor,
    required this.emeraldMix,
    required this.glow,
    required this.isMain,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = Color.lerp(baseColor, ConstellationResonanceOverlay._emeraldCore,
            emeraldMix.clamp(0.0, 1.0)) ??
        ConstellationResonanceOverlay._emeraldCore;
    final blur = (isMain ? 22.0 : 14.0) * glow;
    final spread = (isMain ? 3.0 : 1.5) * glow;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ConstellationResonanceOverlay._emeraldGlow
                .withValues(alpha: 0.6 * glow),
            blurRadius: blur,
            spreadRadius: spread,
          ),
          BoxShadow(
            color: ConstellationResonanceOverlay._emeraldBright
                .withValues(alpha: 0.35 * glow),
            blurRadius: blur * 0.5,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.25 * glow),
            blurRadius: blur * 0.35,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.star_rounded,
          color: starColor,
          size: size * (isMain ? 0.52 : 0.48),
        ),
      ),
    );
  }
}

class _ResonanceLinesPainter extends CustomPainter {
  final Offset hub;
  final List<Offset> contextPositions;
  final double progress;
  final int contextCount;

  const _ResonanceLinesPainter({
    required this.hub,
    required this.contextPositions,
    required this.progress,
    required this.contextCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const igniteEnd = ConstellationResonanceOverlay._igniteEnd;
    const rippleEnd = ConstellationResonanceOverlay._rippleEnd;
    const resonateEnd = ConstellationResonanceOverlay._resonateEnd;

    final baseLineAlpha = progress >= igniteEnd ? 0.22 : 0.0;
    final collapseT = progress <= resonateEnd
        ? 0.0
        : ((progress - resonateEnd) / (1.0 - resonateEnd)).clamp(0.0, 1.0);

    for (var i = 0; i < contextPositions.length; i++) {
      final end = Offset.lerp(contextPositions[i], hub, collapseT)!;
      final rippleStart = igniteEnd + i * 0.09;
      final rippleT =
          Curves.easeOut.transform(((progress - rippleStart) / 0.14).clamp(0.0, 1.0));

      // Static faint line once main ignites
      if (baseLineAlpha > 0) {
        canvas.drawLine(
          hub,
          end,
          Paint()
            ..color = const Color(0xFF50C878).withValues(alpha: baseLineAlpha * (1 - collapseT))
            ..strokeWidth = 0.8
            ..strokeCap = StrokeCap.round,
        );
      }

      // Ripple pulse traveling along the line
      if (rippleT > 0.02 && rippleT < 1.0) {
        final head = Offset.lerp(hub, contextPositions[i], rippleT)!;
        _drawRippleHead(canvas, hub, head, rippleT);
      }

      // Full line glow when ripple completes
      if (rippleT >= 0.98 && progress < resonateEnd + 0.05) {
        final glowAlpha = (0.15 + sin(progress * pi * 4) * 0.05).clamp(0.0, 0.25);
        canvas.drawLine(
          hub,
          contextPositions[i],
          Paint()
            ..color = const Color(0xFF9FFFD4).withValues(alpha: glowAlpha)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
            ..blendMode = BlendMode.plus,
        );
      }
    }

    // Resonate ring at hub
    if (progress >= rippleEnd && progress < resonateEnd + 0.08) {
      final ringT = ((progress - rippleEnd) / (resonateEnd - rippleEnd)).clamp(0.0, 1.0);
      final ringRadius = 28 + ringT * 90;
      canvas.drawCircle(
        hub,
        ringRadius,
        Paint()
          ..color = const Color(0xFF50C878)
              .withValues(alpha: (0.35 * (1 - ringT)).clamp(0.0, 0.35))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  void _drawRippleHead(Canvas canvas, Offset start, Offset head, double rippleT) {
    final fade = sin(rippleT * pi);
    final glow = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF50C878).withValues(alpha: 0.2 * fade),
          const Color(0xFF9FFFD4).withValues(alpha: 0.85 * fade),
        ],
      ).createShader(Rect.fromPoints(start, head))
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..blendMode = BlendMode.plus;
    final core = Paint()
      ..color = const Color(0xFFB8FFE8).withValues(alpha: 0.9 * fade)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;

    canvas.drawLine(start, head, glow);
    canvas.drawLine(start, head, core);
    canvas.drawCircle(
      head,
      3.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _ResonanceLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CollapseBurstPainter extends CustomPainter {
  final Offset center;
  final double progress;

  const _CollapseBurstPainter({
    required this.center,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rng = Random(31);
    for (var i = 0; i < 14; i++) {
      final angle = (i / 14.0) * 2 * pi + rng.nextDouble() * 0.4;
      final dist = (8 + rng.nextDouble() * 24) * (1 - progress);
      final p = Offset(
        center.dx + cos(angle) * dist,
        center.dy + sin(angle) * dist,
      );
      canvas.drawCircle(
        p,
        1.0 + rng.nextDouble() * 1.5,
        Paint()
          ..color = const Color(0xFF9FFFD4)
              .withValues(alpha: (1 - progress) * 0.7)
          ..blendMode = BlendMode.plus,
      );
    }
    canvas.drawCircle(
      center,
      6 * (1 - progress) + 2,
      Paint()
        ..color = Colors.white.withValues(alpha: (1 - progress) * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _CollapseBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
