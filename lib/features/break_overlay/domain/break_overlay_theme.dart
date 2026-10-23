import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Resolved colors for a break overlay surface. Obtain with
/// [BreakPalette.of]; templates marked "fixed" in the design spec use their
/// own colors and ignore this.
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
    border: Color(0x1FFFFFFF), // white 12 %
    track: Color(0x24FFFFFF), // white 14 %
    textPrimary: Color(0xFFF2F4F7),
    textSecondary: Color(0xFFB4BCC8),
    textMuted: Color(0xFF8A93A1),
    isDark: true,
  );

  static const BreakPalette light = BreakPalette(
    canvas: Color(0xFFF4F2EE),
    canvasRaised: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    border: Color(0x1A1C1F24), // ink 10 %
    track: Color(0x1F1C1F24), // ink 12 %
    textPrimary: Color(0xFF1C1F24),
    textSecondary: Color(0xFF4A515C),
    textMuted: Color(0xFF646B76),
    isDark: false,
  );

  /// Photos are shown over a fixed dark treatment, so this template ignores
  /// the light/dark theme.
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

  /// Twilight is always violet, so this ignores the light/dark theme.
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

  static const BreakPalette terminal = BreakPalette(
    canvas: Color(0xFF0B0F0A),
    canvasRaised: Color(0xFF121910),
    surface: Color(0xFF141A12),
    border: Color(0x33B5CC7A),
    track: Color(0x33B5CC7A),
    textPrimary: BreakOverlayTheme.phosphor,
    textSecondary: Color(0xFFA9BE72),
    textMuted: Color(0xFF8FA25F),
    isDark: true,
  );

  /// A printed page is always light, whatever the theme.
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

  /// Light text over a landscape, whatever the theme.
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

  /// The night is always dark, so this ignores the light/dark theme.
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

  /// A sunset is always warm and blue-free, so this ignores the theme.
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

  /// The end of the day is always warm, whatever the theme.
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

  /// [accent] adjusted so strokes and glyphs stay visible on this palette:
  /// unchanged on dark, deepened on light (the pastel accents are under 2:1
  /// on cream).
  Color accentOn(Color accent) {
    if (isDark) return accent;
    final hsl = HSLColor.fromColor(accent);
    if (hsl.lightness <= 0.42) return accent;
    return hsl
        .withLightness(0.42)
        .withSaturation(math.min(1.0, hsl.saturation + 0.1))
        .toColor();
  }

  /// The palette in effect: a [BreakPaletteScope] override if one exists,
  /// otherwise dark.
  ///
  /// Templates must read colors from here (or the fixed palettes in
  /// [BreakOverlayTheme]) and never from `Theme.of(context)`.
  ///
  /// This deliberately does not follow `Theme.of(context).brightness`: the
  /// standalone overlay window runs a bare `MaterialApp`, whose default theme
  /// is light, and break screens have always been dark. Wrap a subtree in
  /// `BreakPaletteScope(palette: BreakPalette.light, ...)` to opt in to light.
  static BreakPalette of(BuildContext context) {
    final scoped = context
        .dependOnInheritedWidgetOfExactType<BreakPaletteScope>();
    return scoped?.palette ?? dark;
  }
}

/// Pins a [BreakPalette] for a subtree, regardless of the ambient theme.
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

/// Marks a subtree as a static gallery thumbnail: animated templates park
/// their loops at a representative mid-break frame and run no tickers.
class BreakPreviewScope extends InheritedWidget {
  const BreakPreviewScope({super.key, required super.child});

  static bool isPreview(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BreakPreviewScope>() != null;

  @override
  bool updateShouldNotify(BreakPreviewScope old) => false;
}

/// Central design tokens for all break overlay templates.
/// Every template and overlay widget must reference these constants
/// instead of hardcoding magic colors, font sizes, or padding values.
abstract final class BreakOverlayTheme {
  // ── Accents (template identity; hues are kept from the original design) ──
  static const Color eyeRest = Color(0xFF7EC8E3);
  static const Color recovery = Color(0xFF86EFAC);
  static const Color amber = Color(0xFFD4A55A);
  static const Color nature = Color(0xFF74C69D);
  static const Color mint = Color(0xFF6EE7B7);
  static const Color periwinkle = Color(0xFFA5B4FC);
  static const Color sage = Color(0xFF5BB898);
  static const Color sky = Color(0xFF93C5FD);
  static const Color dusk = Color(0xFFC4B5FD);
  static const Color phosphor = Color(0xFFB5CC7A);

  /// Accent at 18 % alpha, for halos.
  static Color accentGlow(Color c) => c.withValues(alpha: 0.18);

  // ── Spacing / radii ──
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 16;
  static const double space4 = 24;
  static const double space5 = 40;

  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 22;
  static const double radiusPill = 999;

  // ── Typography ──
  static const String fontFamily = 'Inter';
  static const String monoFamily = 'JetBrains Mono';
  static const String serifFamily = 'Source Serif 4';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 64,
    fontWeight: FontWeight.w200,
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
    fontWeight: FontWeight.w500,
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

  /// Serif for Haiku Card and Paper Light (bundled Source Serif 4).
  static const TextStyle serif = TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: ['Georgia', 'Times New Roman', 'Times', 'serif'],
  );

  // ── Depth ──
  static const List<BoxShadow> surfaceShadow = [
    BoxShadow(color: Color(0x47000000), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static const double glassBlur = 20;

  // ── Skip button placement ──
  static const double skipBottom = 36.0;
  static const double skipRight = 40.0;

  /// Resolves the accent color for [templateId], honoring a user-pinned
  /// override from `SettingsModel.templateAccentOverrides` when present and
  /// falling back to the template's built-in [fallback] accent otherwise.
  static Color resolveAccent(
    Map<String, int> overrides,
    String templateId,
    Color fallback,
  ) {
    final override = overrides[templateId];
    return override != null ? Color(override) : fallback;
  }
}

/// Motion tokens shared by every template.
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

  /// True when the OS asks apps to minimise motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
