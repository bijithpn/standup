import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  // Minimal Modern Color Palette
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // Neutral Grays
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFE5E5E5);
  static const Color gray300 = Color(0xFFD4D4D4);
  static const Color gray400 = Color(0xFFA3A3A3);
  static const Color gray500 = Color(0xFF737373);
  static const Color gray600 = Color(0xFF525252);
  static const Color gray700 = Color(0xFF404040);
  static const Color gray800 = Color(0xFF262626);
  static const Color gray900 = Color(0xFF171717);
  static const Color gray950 = Color(0xFF0A0A0A);

  // Dark Mode Surfaces
  static const Color surface = Color(0xFF18181B);
  static const Color surfaceElevated = Color(0xFF27272A);
  static const Color surfaceCard = Color(0xFF1F1F23);
  static const Color border = Color(0xFF3F3F46);
  static const Color borderSubtle = Color(0xFF27272A);

  // Text
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Break Type Colors
  static const Color shortBreak = Color(0xFF06B6D4); // Cyan
  static const Color longBreak = Color(0xFF8B5CF6); // Purple

  // Radii
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  static MacosThemeData get macosTheme {
    final base = MacosThemeData.dark();
    return base.copyWith(
      primaryColor: primary,
      brightness: Brightness.dark,
      canvasColor: surface,
      typography: MacosTypography(
        color: textPrimary,
        title1: base.typography.title1.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        title2: base.typography.title2.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        title3: base.typography.title3.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
        headline: base.typography.headline.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
        subheadline: base.typography.subheadline.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
        body: base.typography.body.copyWith(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
        ),
        callout: base.typography.callout.copyWith(fontFamily: 'Inter'),
        footnote: base.typography.footnote.copyWith(fontFamily: 'Inter'),
        caption1: base.typography.caption1.copyWith(fontFamily: 'Inter'),
        caption2: base.typography.caption2.copyWith(fontFamily: 'Inter'),
      ),
    );
  }

  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      cardColor: surfaceCard,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surfaceCard,
        error: error,
        onPrimary: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
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
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          fontFamily: 'Inter',
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
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
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
      ),
    );
  }

  static BoxDecoration cardDecoration({bool elevated = false}) {
    return BoxDecoration(
      color: elevated ? surfaceElevated : surfaceCard,
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(color: borderSubtle, width: 1),
    );
  }

  static BoxDecoration glassDecoration({double opacity = 0.05}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1,
      ),
    );
  }

  // Legacy compatibility - old property names
  static BoxDecoration get cleanCardDecoration => cardDecoration();
  static BoxDecoration get glassCardDecoration => cardDecoration(elevated: true);
  static Color get overlayBackground => Colors.black.withValues(alpha: 0.9);
  
  // Legacy color names
  static Color get accentColor => primary;
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
  
  // Legacy text styles
  static const TextStyle sidebarItemStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: -0.1,
    fontFamily: 'Inter',
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
    fontFamily: 'Inter',
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0,
    fontFamily: 'Inter',
  );

  static const TextStyle headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    fontFamily: 'Inter',
  );

  static const TextStyle subHeaderStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: -0.1,
    fontFamily: 'Inter',
  );

  static const TextStyle breakTitleStyle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.8,
    fontFamily: 'Inter',
  );

  static const TextStyle tipStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
    letterSpacing: 0.1,
    fontFamily: 'Inter',
  );

  static const TextStyle skipButtonStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.3,
    fontFamily: 'Inter',
  );
  
  // Legacy glass container method
  static Widget glassContainer({
    required Widget child,
    double opacity = 0.3,
    BorderRadius? borderRadius,
    bool hasGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceCard.withValues(alpha: opacity + 0.4),
        borderRadius: borderRadius ?? BorderRadius.circular(radiusMd),
        border: Border.all(
          color: border,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
