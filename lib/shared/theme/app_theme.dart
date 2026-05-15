import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color accentColor = Color(0xFF0A84FF); // macOS Blue
  static const Color sidebarBackground = Color(0xFF111111);
  static const Color contentBackground = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color borderColor = Color(0xFF222222);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF999999);
  static const Color textMuted = Color(0xFF555555);

  static const Color shortBreakColor = Color(0xFF30D158); // macOS Green
  static const Color longBreakColor = Color(0xFF0A84FF); // macOS Blue
  static const Color upcomingBreakColor = Color(0xFFFF9F0A); // macOS Orange

  static MacosThemeData get macosTheme {
    return MacosThemeData.dark().copyWith(
      primaryColor: accentColor,
      brightness: Brightness.dark,
      canvasColor: sidebarBackground,
      typography: MacosTypography(
        color: textPrimary,
      ),
    );
  }

  /// Premium Glassmorphic card decoration
  static BoxDecoration get glassCardDecoration {
    return BoxDecoration(
      color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  /// Premium Glassmorphic container with optional gradient
  static Widget glassContainer({
    required Widget child,
    double opacity = 0.5,
    BorderRadius? borderRadius,
    bool hasGradient = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: opacity),
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
        gradient: hasGradient ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ) : null,
      ),
      child: child,
    );
  }

  static const TextStyle sidebarItemStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textMuted,
    letterSpacing: 1.5,
  );

  static const TextStyle headerStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle subHeaderStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: -0.3,
  );

  static const TextStyle breakTitleStyle = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -1.0,
  );

  static const TextStyle tipStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.6,
    letterSpacing: 0.1,
  );

  static final overlayBackground = Colors.black.withValues(alpha: 0.9);
  
  static const skipButtonStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.5,
  );
}
