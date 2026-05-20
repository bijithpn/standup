import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  // Core Colors — matches DeskRest dark macOS palette
  static const Color accentColor = Color(0xFF007AFF); // macOS San Francisco Blue
  static const Color sidebarBackground = Color(0xFF1E1E1E);
  static const Color contentBackground = Color(0xFF1C1C1E);
  static const Color cardBackground = Color(0xFF2C2C2E);
  static const Color cardBackgroundElevated = Color(0xFF3A3A3C);
  static const Color borderColor = Color(0xFF3A3A3C);
  static const Color separatorColor = Color(0xFF38383A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93); // iOS secondary
  static const Color textMuted = Color(0xFF636366);

  // System colors matching macOS
  static const Color shortBreakColor = Color(0xFF32D74B); // macOS Green
  static const Color longBreakColor = Color(0xFF0A84FF);  // macOS Blue
  static const Color upcomingBreakColor = Color(0xFFFF9F0A); // macOS Orange
  static const Color destructiveColor = Color(0xFFFF453A); // macOS Red

  static const double cardRadius = 12.0;
  static const double innerRadius = 8.0;

  static MacosThemeData get macosTheme {
    final base = MacosThemeData.dark();
    return base.copyWith(
      primaryColor: accentColor,
      brightness: Brightness.dark,
      canvasColor: sidebarBackground,
      typography: MacosTypography(
        color: textPrimary,
        title1: base.typography.title1.copyWith(fontFamily: 'Satoshi', fontWeight: FontWeight.w700),
        title2: base.typography.title2.copyWith(fontFamily: 'Satoshi', fontWeight: FontWeight.w700),
        title3: base.typography.title3.copyWith(fontFamily: 'Satoshi', fontWeight: FontWeight.w600),
        headline: base.typography.headline.copyWith(fontFamily: 'Satoshi', fontWeight: FontWeight.w600),
        subheadline: base.typography.subheadline.copyWith(fontFamily: 'Satoshi', fontWeight: FontWeight.w500),
        body: base.typography.body.copyWith(fontFamily: 'Satoshi', fontWeight: FontWeight.w400),
        callout: base.typography.callout.copyWith(fontFamily: 'Satoshi'),
        footnote: base.typography.footnote.copyWith(fontFamily: 'Satoshi'),
        caption1: base.typography.caption1.copyWith(fontFamily: 'Satoshi'),
        caption2: base.typography.caption2.copyWith(fontFamily: 'Satoshi'),
      ),
    );
  }

  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Satoshi',
      primaryColor: accentColor,
      scaffoldBackgroundColor: contentBackground,
      cardColor: cardBackground,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: cardBackground,
        error: destructiveColor,
        onPrimary: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),
      textTheme: const TextTheme(
        headlineLarge: headerStyle,
        headlineMedium: sectionTitle,
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15, fontFamily: 'Satoshi'),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13, fontFamily: 'Satoshi'),
      ),
      dividerTheme: const DividerThemeData(
        color: separatorColor,
        thickness: 0.5,
      ),
    );
  }

  /// Clean card decoration — solid dark background, no blur
  static BoxDecoration get cleanCardDecoration {
    return BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: borderColor,
        width: 0.5,
      ),
    );
  }

  /// Subtle glass container — kept minimal for overlays only
  static Widget glassContainer({
    required Widget child,
    double opacity = 0.3,
    BorderRadius? borderRadius,
    bool hasGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBackground.withValues(alpha: opacity + 0.4),
        borderRadius: borderRadius ?? BorderRadius.circular(cardRadius),
        border: Border.all(
          color: borderColor,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }

  /// Legacy glass card decoration — now maps to clean card
  static BoxDecoration get glassCardDecoration => cleanCardDecoration;

  static const TextStyle sidebarItemStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: -0.1,
    fontFamily: 'Satoshi',
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
    fontFamily: 'Satoshi',
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0,
    fontFamily: 'Satoshi',
  );

  static const TextStyle headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    fontFamily: 'Satoshi',
  );

  static const TextStyle subHeaderStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: -0.1,
    fontFamily: 'Satoshi',
  );

  static const TextStyle breakTitleStyle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.8,
    fontFamily: 'Satoshi',
  );

  static const TextStyle tipStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
    letterSpacing: 0.1,
    fontFamily: 'Satoshi',
  );

  static final Color overlayBackground = Colors.black.withValues(alpha: 0.85);

  static const skipButtonStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.3,
    fontFamily: 'Satoshi',
  );
}
