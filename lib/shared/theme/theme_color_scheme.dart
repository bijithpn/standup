import 'package:flutter/material.dart';

/// Complete Material color roles from the app palette. Explicit surfaces and
/// containers prevent defaults or elevation tints from changing a preset's hue.
ColorScheme themeColorScheme({
  required Brightness brightness,
  required Color accent,
  required Color surface,
  required Color card,
  required Color elevated,
  required Color text,
  required Color secondaryText,
  required Color border,
  required Color separator,
}) {
  final onAccent = accent.computeLuminance() > 0.179
      ? Colors.black
      : Colors.white;
  final selected = Color.alphaBlend(accent.withValues(alpha: 0.12), card);
  const error = Color(0xFFEF4444);
  return ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: selected,
    onPrimaryContainer: text,
    secondary: accent,
    onSecondary: onAccent,
    secondaryContainer: selected,
    onSecondaryContainer: text,
    tertiary: accent,
    onTertiary: onAccent,
    tertiaryContainer: selected,
    onTertiaryContainer: text,
    error: error,
    onError: Colors.white,
    errorContainer: Color.alphaBlend(error.withValues(alpha: 0.12), card),
    onErrorContainer: text,
    surface: card,
    onSurface: text,
    onSurfaceVariant: secondaryText,
    surfaceDim: surface,
    surfaceBright: elevated,
    surfaceContainerLowest: surface,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: elevated,
    surfaceContainerHighest: elevated,
    outline: border,
    outlineVariant: separator,
    inverseSurface: text,
    onInverseSurface: surface,
    inversePrimary: accent,
    surfaceTint: Colors.transparent,
  );
}
