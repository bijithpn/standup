import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Color set every break template reads via BreakPalette.of(context); the named presets back the per-template looks.
@immutable
class BreakPalette {
  final Color canvas;
  final Color canvasRaised;
  final Color surface;
  final Color border;
  final Color track;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final bool isDark;

  const BreakPalette({
    required this.canvas,
    required this.canvasRaised,
    required this.surface,
    required this.border,
    required this.track,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.isDark,
  });

  static const BreakPalette dark = BreakPalette(
    canvas: Color(0xFF14181F),
    canvasRaised: Color(0xFF1B2029),
    surface: Color(0xFF1F2530),
    border: Color(0x1FFFFFFF),
    track: Color(0x24FFFFFF),
    textPrimary: Color(0xFFF2F4F7),
    textSecondary: Color(0xFFB4BCC8),
    textMuted: Color(0xFF8A93A1),
    isDark: true,
  );

  static const BreakPalette light = BreakPalette(
    canvas: Color(0xFFF4F2EE),
    canvasRaised: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    border: Color(0x1A1C1F24),
    track: Color(0x1F1C1F24),
    textPrimary: Color(0xFF1C1F24),
    textSecondary: Color(0xFF4A515C),
    textMuted: Color(0xFF646B76),
    isDark: false,
  );

  static const BreakPalette onPhoto = BreakPalette(
    canvas: Color(0xFF1E2A3A),
    canvasRaised: Color(0xFF26364A),
    surface: Color(0xFF1F2530),
    border: Color(0x1FFFFFFF),
    track: Color(0x33FFFFFF),
    textPrimary: Color(0xFFF2F4F7),
    textSecondary: Color(0xFFD0D6DE),
    textMuted: Color(0xFFB4BCC8),
    isDark: true,
  );

  static const BreakPalette twilight = BreakPalette(
    canvas: Color(0xFF1B1530),
    canvasRaised: Color(0xFF281F45),
    surface: Color(0xFF281F45),
    border: Color(0x33C4B5FD),
    track: Color(0x33C4B5FD),
    textPrimary: Color(0xFFEEEAFB),
    textSecondary: Color(0xFFD6CFF3),
    textMuted: Color(0xFFBDB4E2),
    isDark: true,
  );

  static const BreakPalette paper = BreakPalette(
    canvas: Color(0xFFF5F3EE),
    canvasRaised: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    border: Color(0x1A1A1814),
    track: Color(0x1F1A1814),
    textPrimary: Color(0xFF1A1814),
    textSecondary: Color(0xFF4A4540),
    textMuted: Color(0xFF6B6560),
    isDark: false,
  );

  static const BreakPalette field = BreakPalette(
    canvas: Color(0xFF20324A),
    canvasRaised: Color(0xFF2B4258),
    surface: Color(0xFF1F2F40),
    border: Color(0x33FFFFFF),
    track: Color(0x33FFFFFF),
    textPrimary: Color(0xFFF2F4F7),
    textSecondary: Color(0xFFD7DEE6),
    textMuted: Color(0xFFC3CCD6),
    isDark: true,
  );

  static const BreakPalette night = BreakPalette(
    canvas: Color(0xFF0A0E27),
    canvasRaised: Color(0xFF141A3A),
    surface: Color(0xFF141A3A),
    border: Color(0x33FFFFFF),
    track: Color(0x33FFFFFF),
    textPrimary: Color(0xFFF2F4F7),
    textSecondary: Color(0xFFD0D6E6),
    textMuted: Color(0xFFB4BCD2),
    isDark: true,
  );

  static const BreakPalette sunset = BreakPalette(
    canvas: Color(0xFF1A120A),
    canvasRaised: Color(0xFF2A1A0D),
    surface: Color(0xFF2A1A0D),
    border: Color(0x33D4A55A),
    track: Color(0x33D4A55A),
    textPrimary: Color(0xFFF3E9DA),
    textSecondary: Color(0xFFC9B79C),
    textMuted: Color(0xFFC9B79C),
    isDark: true,
  );

  static const BreakPalette evening = BreakPalette(
    canvas: Color(0xFF140D07),
    canvasRaised: Color(0xFF2E1C0C),
    surface: Color(0xFF2E1C0C),
    border: Color(0x1AFFFFFF),
    track: Color(0x33C49A4A),
    textPrimary: Color(0xFFF3E9DA),
    textSecondary: Color(0xFFC9B79C),
    textMuted: Color(0xFFC9B79C),
    isDark: true,
  );

  /// Darkens a bright accent on light palettes so it stays readable.
  Color accentOn(Color accent) {
    if (isDark) return accent;
    final hsl = HSLColor.fromColor(accent);
    if (hsl.lightness <= 0.42) return accent;
    return hsl
        .withLightness(0.42)
        .withSaturation(math.min(1.0, hsl.saturation + 0.1))
        .toColor();
  }

  /// Resolves the user's overlay appearance setting ('light' / 'system' / otherwise dark) to a palette.
  static BreakPalette forMode(String mode, Brightness system) => switch (mode) {
    'light' => light,
    'system' => system == Brightness.light ? light : dark,
    _ => dark,
  };

  static BreakPalette of(BuildContext context) {
    final scoped = context
        .dependOnInheritedWidgetOfExactType<BreakPaletteScope>();
    return scoped?.palette ?? dark;
  }
}

/// Injects the active palette so descendants can find it with BreakPalette.of.
class BreakPaletteScope extends InheritedWidget {
  final BreakPalette palette;

  const BreakPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  @override
  bool updateShouldNotify(BreakPaletteScope old) => palette != old.palette;
}

/// Marks a subtree as a settings preview so templates can skip side effects like timers and audio.
class BreakPreviewScope extends InheritedWidget {
  const BreakPreviewScope({super.key, required super.child});

  static bool isPreview(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BreakPreviewScope>() != null;

  @override
  bool updateShouldNotify(BreakPreviewScope old) => false;
}

/// Signals the overlay is in its finishing state so templates can play their exit animation.
class BreakCompletionScope extends InheritedWidget {
  final bool completing;

  const BreakCompletionScope({
    super.key,
    required this.completing,
    required super.child,
  });

  static bool isCompleting(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BreakCompletionScope>()
          ?.completing ??
      false;

  @override
  bool updateShouldNotify(BreakCompletionScope old) =>
      completing != old.completing;
}

/// Shared design tokens (accents, radii, type styles) for the break overlay templates.
abstract final class BreakOverlayTheme {
  static const Color eyeRest = Color(0xFF7EC8E3);
  static const Color recovery = Color(0xFF86EFAC);
  static const Color amber = Color(0xFFD4A55A);
  static const Color nature = Color(0xFF74C69D);
  static const Color mint = Color(0xFF6EE7B7);
  static const Color sage = Color(0xFF5BB898);
  static const Color sky = Color(0xFF93C5FD);
  static const Color dusk = Color(0xFFC4B5FD);

  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 22;
  static const double radiusPill = 999;

  static const String fontFamily = 'Inter';
  static const String monoFamily = 'JetBrains Mono';
  static const String serifFamily = 'Source Serif 4';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 64,
    fontWeight: FontWeight.w300,
    letterSpacing: -2,
    height: 1.0,
    fontFeatures: tabular,
  );
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w300,
    letterSpacing: -1,
    fontFeatures: tabular,
  );
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFeatures: tabular,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
  );

  static const TextStyle serif = TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: ['Georgia', 'Times New Roman', 'Times', 'serif'],
  );

  static const List<BoxShadow> surfaceShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const double glassBlur = 20;

  static const double skipBottom = 36.0;
  static const double skipRight = 40.0;

  static Color resolveAccent(
    Map<String, int> overrides,
    String templateId,
    Color fallback,
  ) {
    final override = overrides[templateId];
    return override != null ? Color(override) : fallback;
  }
}

/// Shared durations, curves and the reduced-motion check for overlay animations.
abstract final class BreakMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 900);
  static const Duration breath = Duration(seconds: 4);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve breathe = Curves.easeInOutSine;

  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 18,
  );

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
