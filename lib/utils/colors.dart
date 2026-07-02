import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Colors.black;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  /// Deep space surfaces (settings, panels).
  static const Color surfaceDeep = Color(0xFF080E1A);
  static const Color surfacePanel = Color(0xFF0D1322);

  /// Stellar accent — meteors, glow, input focus (unified cool blue).
  static const Color stellarAccent = Color(0xFF9CF8FF);
  static const Color stellarAccentSoft = Color(0xFF8FB0E8);

  /// Input field borders on dark backgrounds.
  static const Color inputBorder = Color(0xFF3D4F66);
  static const Color inputFocus = stellarAccentSoft;
}
