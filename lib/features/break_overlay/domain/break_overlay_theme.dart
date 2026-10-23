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

  /// Serif for Haiku Card and Paper Light. The project bundles no serif, so
  /// this uses Georgia with platform serif fallbacks.
  static const TextStyle serif = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: ['Times New Roman', 'Times', 'serif'],
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

  // ── Deprecated aliases (kept so unmigrated code still compiles) ──
  @Deprecated('Use BreakPalette.of(context).canvas')
  static const Color background = Color(0xFF14181F);
  @Deprecated('Use BreakPalette.of(context).canvasRaised')
  static const Color surfaceSubtle = Color(0xFF1B2029);
  @Deprecated('Use BreakPalette.of(context).textPrimary')
  static const Color textPrimary = Color(0xFFF2F4F7);
  @Deprecated('Use BreakPalette.of(context).textSecondary')
  static const Color textSecondary = Color(0xFFB4BCC8);
  @Deprecated('Use BreakPalette.of(context).textMuted')
  static const Color textMuted = Color(0xFF8A93A1);
  @Deprecated('Use BreakPalette.of(context).textMuted')
  static const Color textDim = Color(0xFF8A93A1);
  @Deprecated('Use BreakOverlayTheme.eyeRest')
  static const Color accentShort = eyeRest;
  @Deprecated('Use BreakOverlayTheme.recovery')
  static const Color accentLong = recovery;
  @Deprecated('Use BreakOverlayTheme.amber')
  static const Color accentAmber = Color(0xFFC49A4A);
  @Deprecated('Use BreakOverlayTheme.eyeRest')
  static const Color accentZen = eyeRest;
  @Deprecated('Use BreakOverlayTheme.nature')
  static const Color accentNature = nature;
  @Deprecated('Use BreakPalette.of(context).border')
  static const Color borderSubtle = Color(0x1FFFFFFF);
  @Deprecated('Use BreakPalette.of(context).canvas with alpha')
  static const Color surfaceOverlay = Color(0x80000000);
  @Deprecated('Use BreakSkipButton')
  static const double skipFontSize = 13.0;
  @Deprecated('Use BreakOverlayTheme.hero')
  static const double timerFontSizeLg = 64.0;
  @Deprecated('Use BreakOverlayTheme.display')
  static const double timerFontSizeMd = 54.0;
  @Deprecated('Use BreakOverlayTheme.title')
  static const double timerFontSizeSm = 20.0;
  @Deprecated('Use BreakOverlayTheme.micro')
  static const double labelFontSize = 13.0;
  @Deprecated('Use BreakOverlayTheme.body')
  static const double headingFontSize = 16.0;
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
