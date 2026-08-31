import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:breakmate/features/themes/domain/app_theme_preset.dart';

class AppTheme {
  AppTheme._();

  static AppThemePreset _activePreset = AppThemePreset.nordicSlate;
  static Color? _customAccent;

  static AppThemePreset get activePreset => _activePreset;
  static Color? get customAccent => _customAccent;

  static void applyPreset(AppThemePreset preset, {Color? customAccent}) {
    _activePreset = preset;
    _customAccent = customAccent;
  }

  static void applyCustomAccent(Color? customAccent) {
    _customAccent = customAccent;
  }

  // Core Theme Palette
  static Color get primary => _activePreset.primary;
  static Color get primaryLight => _activePreset.primaryLight;
  static Color get primaryDark => _activePreset.primaryDark;

  static Color get accent => _customAccent ?? _activePreset.accent;
  static Color get accentColor => accent;

  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF4F4F5);
  static const Color gray200 = Color(0xFFE4E4E7);
  static const Color gray300 = Color(0xFFD4D4D8);
  static const Color gray400 = Color(0xFFA1A1AA);
  static const Color gray500 = Color(0xFF71717A);
  static const Color gray600 = Color(0xFF52525B);
  static const Color gray700 = Color(0xFF3F3F46);
  static const Color gray800 = Color(0xFF27272A);
  static const Color gray900 = Color(0xFF18181B);
  static const Color gray950 = Color(0xFF09090B);

  static Color get surface => _activePreset.surface;
  static Color get surfaceElevated => _activePreset.surfaceElevated;
  static Color get surfaceCard => _activePreset.surfaceCard;
  static Color get border => _activePreset.border;
  static Color get borderSubtle => _activePreset.borderSubtle;

  static Color get textPrimary => _activePreset.textPrimary;
  static Color get textSecondary => _activePreset.textSecondary;
  static Color get textMuted => _activePreset.textMuted;

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static Color get shortBreak => _activePreset.shortBreak;
  static Color get longBreak => _activePreset.longBreak;

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  static MacosThemeData get macosTheme {
    final base = _activePreset.isDark
        ? MacosThemeData.dark()
        : MacosThemeData.light();
    return base.copyWith(
      primaryColor: accent,
      brightness: _activePreset.isDark ? Brightness.dark : Brightness.light,
      canvasColor: surface,
      typography: MacosTypography(
        color: textPrimary,
        title1: base.typography.title1.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: textPrimary,
        ),
        title2: base.typography.title2.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
        title3: base.typography.title3.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          color: textPrimary,
        ),
        headline: base.typography.headline.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        subheadline: base.typography.subheadline.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        body: base.typography.body.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        callout: base.typography.callout.copyWith(
          fontFamily: 'Inter',
          color: textSecondary,
        ),
        footnote: base.typography.footnote.copyWith(
          fontFamily: 'Inter',
          color: textMuted,
        ),
        caption1: base.typography.caption1.copyWith(
          fontFamily: 'Inter',
          color: textMuted,
        ),
        caption2: base.typography.caption2.copyWith(
          fontFamily: 'Inter',
          color: textMuted,
        ),
      ),
    );
  }

  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: _activePreset.isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'Inter',
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      cardColor: surfaceCard,
      colorScheme: ColorScheme(
        brightness: _activePreset.isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surfaceCard,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
          fontFamily: 'Inter',
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          fontFamily: 'Inter',
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
          fontFamily: 'Inter',
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          fontFamily: 'Inter',
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: 'Inter',
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          fontFamily: 'Inter',
        ),
      ),
      dividerTheme: DividerThemeData(color: borderSubtle, thickness: 1),
    );
  }

  static BoxDecoration cardDecoration({bool elevated = false}) {
    return BoxDecoration(
      color: elevated ? surfaceElevated : surfaceCard,
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(color: border, width: 1),
    );
  }

  static BoxDecoration glassDecoration({double opacity = 0.03}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
    );
  }

  static BoxDecoration get cleanCardDecoration => cardDecoration();
  static BoxDecoration get glassCardDecoration =>
      cardDecoration(elevated: true);
  static Color get overlayBackground => Colors.black.withValues(alpha: 0.85);

  static Color get sidebarBackground => surface;
  static Color get contentBackground => surface;
  static Color get cardBackground => surfaceCard;
  static Color get cardBackgroundElevated => surfaceElevated;
  static Color get borderColor => border;
  static Color get separatorColor => borderSubtle;
  static Color get shortBreakColor => shortBreak;
  static Color get longBreakColor => longBreak;
  static Color get upcomingBreakColor => warning;
  static Color get destructiveColor => error;

  static TextStyle get sidebarItemStyle => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: -0.1,
        fontFamily: 'Inter',
      );

  static TextStyle get sectionTitle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.2,
        fontFamily: 'Inter',
      );

  static TextStyle get sectionSubtitle => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        letterSpacing: 0,
        fontFamily: 'Inter',
      );

  static TextStyle get headerStyle => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.5,
        fontFamily: 'Inter',
      );

  static TextStyle get subHeaderStyle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        letterSpacing: -0.1,
        fontFamily: 'Inter',
      );

  static TextStyle get breakTitleStyle => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.8,
        fontFamily: 'Inter',
      );

  static TextStyle get tipStyle => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
        letterSpacing: 0.1,
        fontFamily: 'Inter',
      );

  static TextStyle get skipButtonStyle => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        letterSpacing: 0.2,
        fontFamily: 'Inter',
      );

  static Widget glassContainer({
    required Widget child,
    double opacity = 0.05,
    BorderRadius? borderRadius,
    bool hasGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceCard.withValues(alpha: opacity + 0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(radiusMd),
        border: Border.all(color: border, width: 0.5),
      ),
      child: child,
    );
  }
}
