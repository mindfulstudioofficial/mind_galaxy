import 'dart:math';
import 'package:flutter/material.dart';

/// Geometric slot positions for constellation members around [center].
/// Index 0 is the primary (top / first-magnitude) slot.
List<Offset> constellationLayoutSlots(int count, Offset center, {double radius = 108}) {
  if (count <= 0) return const [];
  switch (count) {
    case 1:
      return [_polar(center, radius, -pi / 2)];
    case 2:
      return [
        _polar(center, radius, -pi / 2),
        _polar(center, radius, pi / 2),
      ];
    case 3:
      return List.generate(
        3,
        (i) => _polar(center, radius, -pi / 2 + (2 * pi / 3) * i),
      );
    default:
      return [
        _polar(center, radius, -pi / 2),
        _polar(center, radius, 0),
        _polar(center, radius, pi / 2),
        _polar(center, radius, pi),
      ].take(count.clamp(1, 4)).toList();
  }
}

Offset _polar(Offset center, double radius, double angle) {
  return Offset(
    center.dx + cos(angle) * radius,
    center.dy + sin(angle) * radius,
  );
}

/// Line segments to draw: each star connects to [hub] (central star UI).
List<(Offset, Offset)> constellationLineSegments(
  Offset hub,
  List<Offset> memberPositions,
) {
  return [for (final p in memberPositions) (hub, p)];
}
