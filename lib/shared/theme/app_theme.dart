import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF18181B); // Zinc 900
  static const Color primaryLight = Color(0xFF3F3F46); // Zinc 700
  static const Color primaryDark = Color(0xFF09090B); // Zinc 950

  static const Color accent = Color(0xFF5f68e9);

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

  static const Color surface = Color(0xFF09090B); // Pure dark
  static const Color surfaceElevated = Color(0xFF18181B); // Slight elevation
  static const Color surfaceCard = Color(0xFF121214); // Distinct card back
  static const Color border = Color(0xFF27272A);
  static const Color borderSubtle = Color(0xFF18181B);

  static const Color textPrimary = Color(0xFFF4F4F5); // Zinc 100
  static const Color textSecondary = Color(0xFFA1A1AA); // Zinc 400
  static const Color textMuted = Color(0xFF71717A); // Zinc 500

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const Color shortBreak = Color(0xFF0EA5E9); // Restrained Cyan
  static const Color longBreak = Color(0xFF8B5CF6); // Soft Purple

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  static MacosThemeData get macosTheme {
    final base = MacosThemeData.dark();
    return base.copyWith(
      primaryColor: accent,
      brightness: Brightness.dark,
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
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      cardColor: surfaceCard,
      colorScheme: const ColorScheme.dark(
        primary: accent,
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
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),
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

  static Color get accentColor => accent;
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

  static const TextStyle sidebarItemStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: -0.1,
    fontFamily: 'Inter',
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    fontFamily: 'Inter',
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0,
    fontFamily: 'Inter',
  );

  static const TextStyle headerStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
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
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.8,
    fontFamily: 'Inter',
  );

  static const TextStyle tipStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
    letterSpacing: 0.1,
    fontFamily: 'Inter',
  );

  static const TextStyle skipButtonStyle = TextStyle(
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
