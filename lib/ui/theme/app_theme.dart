import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color accentColor = Color(0xFF0A84FF); // macOS Blue
  static const Color sidebarBackground = Color(0xFF141414);
  static const Color contentBackground = Color(0xFF0D0D0D);
  static const Color cardBackground = Color(0xFF1F1F1F);
  static const Color borderColor = Color(0xFF2A2A2A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC5C5C5);
  static const Color textMuted = Color(0xFF717171);

  static const Color shortBreakColor = Color(0xFF32D74B); // macOS Green
  static const Color longBreakColor = Color(0xFF0A84FF); // macOS Blue
  static const Color upcomingBreakColor = Color(0xFFFF9F0A); // macOS Orange

  static MacosThemeData get macosTheme {
    return MacosThemeData.dark().copyWith(
      primaryColor: accentColor,
      brightness: Brightness.dark,
      canvasColor: sidebarBackground,
    );
  }

  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static const TextStyle sidebarItemStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: textMuted,
    letterSpacing: 2.0,
  );

  static const TextStyle headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static const TextStyle breakTitleStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle tipStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static final overlayBackground = Colors.black.withValues(alpha: 0.85);
  static const skipButtonStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
}
