import 'package:flutter/material.dart';

/// Central design tokens for all break overlay templates.
/// Every template and overlay widget must reference these constants
/// instead of hardcoding magic colors, font sizes, or padding values.
abstract final class BreakOverlayTheme {
  // Backgrounds
  static const Color background = Color(0xFF0A0A0F);
  static const Color surfaceSubtle = Color(0xFF0F1115);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0x99FFFFFF); // 60 % white
  static const Color textMuted = Color(0x61FFFFFF); // 38 % white
  static const Color textDim = Color(0x59FFFFFF); // 35 % white

  // Accents
  static const Color accentShort = Color(0xFF7EC8E3); // eye-rest / short break
  static const Color accentLong = Color(0xFF86EFAC); // long / recovery break
  static const Color accentAmber = Color(0xFFC49A4A); // warm-amber / wind-down
  static const Color accentZen = Color(0xFF7EC8E3); // zen / breathe

  // Borders / surfaces
  static const Color borderSubtle = Color(0x0DFFFFFF); // 5 % white
  static const Color surfaceOverlay = Color(0x80000000); // 50 % black

  // Skip button
  static const double skipFontSize = 13.0;
  static const double skipBottom = 36.0;
  static const double skipRight = 40.0;

  // Typography
  static const String fontFamily = 'Inter';
  static const double timerFontSizeLg = 64.0;
  static const double timerFontSizeMd = 54.0;
  static const double timerFontSizeSm = 20.0;
  static const double labelFontSize = 13.0;
  static const double headingFontSize = 16.0;
}
