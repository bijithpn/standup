import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  AppTheme._();

  static const _accentColor = Color(0xFF4A90D9);
  static const _breakOverlayBg = Color(0xE6000000);
  static const _cardBg = Color(0xFF1E1E2A);
  static const _textPrimary = Color(0xFFF0F0F5);
  static const _textSecondary = Color(0xFF8E8EA0);

  static MacosThemeData get macosTheme {
    return MacosThemeData.dark().copyWith(
      primaryColor: _accentColor,
    );
  }

  // Break overlay styles
  static const overlayBackground = _breakOverlayBg;
  static const countdownStyle = TextStyle(
    fontSize: 96,
    fontWeight: FontWeight.w200,
    color: _textPrimary,
    letterSpacing: -2,
  );

  static const breakTitleStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: _textPrimary,
  );

  static const tipStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: _textSecondary,
    height: 1.5,
  );

  static const skipButtonStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _textSecondary,
  );

  // Settings page
  static const sectionTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: _textSecondary,
    letterSpacing: 0.5,
  );

  // Progress ring colors
  static const shortBreakColor = Color(0xFF4ADE80);
  static const longBreakColor = Color(0xFF60A5FA);
  static const progressTrack = Color(0xFF2A2A3A);

  // Card styling
  static const cardBackground = _cardBg;
  static final cardDecoration = BoxDecoration(
    color: _cardBg,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFF2A2A3A), width: 1),
  );
}
