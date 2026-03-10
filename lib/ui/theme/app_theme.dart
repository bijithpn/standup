import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  static const Color accentColor = Color(0xFF0A84FF); // macOS Blue
  static const Color sidebarBackground = Color(0xFF1E1E1E);
  static const Color contentBackground = Color(0xFF161616);
  static const Color cardBackground = Color(0xFF242424);
  static const Color borderColor = Color(0xFF333333);

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
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
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
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textMuted,
    letterSpacing: 1.2,
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

  static final overlayBackground = Colors.black.withOpacity(0.85);
  static const skipButtonStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
}
