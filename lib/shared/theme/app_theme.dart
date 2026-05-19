import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color accentColor = Color(
    0xFF007AFF,
  ); // macOS San Francisco Blue
  static const Color sidebarBackground = Color(0xFF1E1E1E);
  static const Color contentBackground = Color(0xFF151515);
  static const Color cardBackground = Color(0xFF252525);
  static const Color borderColor = Color(0xFF333333);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF666666);

  static const Color shortBreakColor = Color(0xFF32D74B); // macOS Green
  static const Color longBreakColor = Color(0xFF0A84FF); // macOS Blue
  static const Color upcomingBreakColor = Color(0xFFFF9F0A); // macOS Orange

  static const double cardRadius = 16.0;
  static const double innerRadius = 12.0;

  static MacosThemeData get macosTheme {
    return MacosThemeData.dark().copyWith(
      primaryColor: accentColor,
      brightness: Brightness.dark,
      canvasColor: sidebarBackground,
    );
  }

  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accentColor,
      scaffoldBackgroundColor: contentBackground,
      cardColor: cardBackground,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        surface: cardBackground,
        error: const Color(0xFFFF453A), // macOS Red
        onPrimary: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),
      textTheme: const TextTheme(
        headlineLarge: headerStyle,
        headlineMedium: subHeaderStyle,
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(color: borderColor, thickness: 0.5,
      ),
    );
  }

  /// Premium Glassmorphic card decoration
  static BoxDecoration get glassCardDecoration {
    return BoxDecoration(
      color: const Color(0xFF2A2A2A).withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.05),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Premium Glassmorphic container with optional gradient
  static Widget glassContainer({
    required Widget child,
    double opacity = 0.3,
    BorderRadius? borderRadius,
    bool hasGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C).withValues(alpha: opacity),
        borderRadius: borderRadius ?? BorderRadius.circular(cardRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.5,
        ),
        gradient: hasGradient ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ) : null,
      ),
      child: child,
    );
  }

  static const TextStyle sidebarItemStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: -0.1,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.1,
  );

  static const TextStyle headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle subHeaderStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: -0.2,
  );

  static const TextStyle breakTitleStyle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.8,
  );

  static const TextStyle tipStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static final overlayBackground = Colors.black.withValues(alpha: 0.85);
  
  static const skipButtonStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.3,
  );
}
