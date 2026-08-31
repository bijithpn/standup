import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';

class AppThemePreset {
  final String id;
  final String name;
  final String description;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color surface;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color border;
  final Color borderSubtle;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color shortBreak;
  final Color longBreak;
  final bool isDark;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.surface,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.border,
    required this.borderSubtle,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shortBreak,
    required this.longBreak,
    this.isDark = true,
  });

  static const nordicSlate = AppThemePreset(
    id: 'nordic_slate',
    name: 'Nordic Slate',
    description: 'Clean zinc and slate dark mode with crisp cyan accents.',
    primary: Color(0xFF18181B),
    primaryDark: Color(0xFF09090B),
    primaryLight: Color(0xFF3F3F46),
    surface: Color(0xFF09090B),
    surfaceCard: Color(0xFF121214),
    surfaceElevated: Color(0xFF18181B),
    border: Color(0xFF27272A),
    borderSubtle: Color(0xFF18181B),
    accent: Color(0xFF38BDF8),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    shortBreak: Color(0xFF0EA5E9),
    longBreak: Color(0xFF8B5CF6),
    isDark: true,
  );

  static const solarizedAmber = AppThemePreset(
    id: 'solarized_amber',
    name: 'Solarized Amber',
    description: 'Warm espresso background and golden amber circadian tones.',
    primary: Color(0xFF221A15),
    primaryDark: Color(0xFF14100D),
    primaryLight: Color(0xFF3B2E24),
    surface: Color(0xFF14100D),
    surfaceCard: Color(0xFF1C1612),
    surfaceElevated: Color(0xFF2B211B),
    border: Color(0xFF3B2E24),
    borderSubtle: Color(0xFF241C16),
    accent: Color(0xFFF59E0B),
    textPrimary: Color(0xFFFDF6E3),
    textSecondary: Color(0xFFC7B89E),
    textMuted: Color(0xFF8C7A65),
    shortBreak: Color(0xFFF59E0B),
    longBreak: Color(0xFFD97706),
    isDark: true,
  );

  static const tokyoMidnight = AppThemePreset(
    id: 'tokyo_midnight',
    name: 'Tokyo Midnight',
    description: 'Deep midnight indigo with radiant violet and neon sakura.',
    primary: Color(0xFF161626),
    primaryDark: Color(0xFF0D0D18),
    primaryLight: Color(0xFF26263D),
    surface: Color(0xFF0D0D18),
    surfaceCard: Color(0xFF131322),
    surfaceElevated: Color(0xFF1B1B30),
    border: Color(0xFF282845),
    borderSubtle: Color(0xFF1B1B2F),
    accent: Color(0xFFC084FC),
    textPrimary: Color(0xFFF1F1F8),
    textSecondary: Color(0xFFA5A5CE),
    textMuted: Color(0xFF70709C),
    shortBreak: Color(0xFF38BDF8),
    longBreak: Color(0xFFF472B6),
    isDark: true,
  );

  static const forestMatcha = AppThemePreset(
    id: 'forest_matcha',
    name: 'Forest Matcha',
    description: 'Organic botanical moss surfaces with jade and sage highlights.',
    primary: Color(0xFF141D16),
    primaryDark: Color(0xFF0B120C),
    primaryLight: Color(0xFF253327),
    surface: Color(0xFF0B120C),
    surfaceCard: Color(0xFF121B13),
    surfaceElevated: Color(0xFF1B281D),
    border: Color(0xFF263A29),
    borderSubtle: Color(0xFF18241A),
    accent: Color(0xFF34D399),
    textPrimary: Color(0xFFE8EFE9),
    textSecondary: Color(0xFFA3B8A6),
    textMuted: Color(0xFF6B806E),
    shortBreak: Color(0xFF10B981),
    longBreak: Color(0xFF059669),
    isDark: true,
  );

  static const eInkPaper = AppThemePreset(
    id: 'e_ink_paper',
    name: 'E-Ink Minimal',
    description: 'High-contrast monochrome editorial layout for distraction-free focus.',
    primary: Color(0xFF202020),
    primaryDark: Color(0xFF0F0F0F),
    primaryLight: Color(0xFF404040),
    surface: Color(0xFF0A0A0A),
    surfaceCard: Color(0xFF141414),
    surfaceElevated: Color(0xFF222222),
    border: Color(0xFF333333),
    borderSubtle: Color(0xFF1E1E1E),
    accent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCCCCCC),
    textMuted: Color(0xFF888888),
    shortBreak: Color(0xFFE5E5E5),
    longBreak: Color(0xFFFFFFFF),
    isDark: true,
  );

  static const cyberpunk = AppThemePreset(
    id: 'cyberpunk',
    name: 'Cyberpunk HUD',
    description: 'Pitch obsidian black with high-voltage lime and circuit orange.',
    primary: Color(0xFF121212),
    primaryDark: Color(0xFF050505),
    primaryLight: Color(0xFF242424),
    surface: Color(0xFF050505),
    surfaceCard: Color(0xFF0F0F0F),
    surfaceElevated: Color(0xFF1A1A1A),
    border: Color(0xFF2C2C2C),
    borderSubtle: Color(0xFF191919),
    accent: Color(0xFF84CC16),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    shortBreak: Color(0xFF84CC16),
    longBreak: Color(0xFFF97316),
    isDark: true,
  );

  static const List<AppThemePreset> allPresets = [
    nordicSlate,
    solarizedAmber,
    tokyoMidnight,
    forestMatcha,
    eInkPaper,
    cyberpunk,
  ];

  static AppThemePreset findById(String? id) {
    if (id == null) return nordicSlate;
    return allPresets.firstWhere(
      (p) => p.id == id,
      orElse: () => nordicSlate,
    );
  }

  ThemeData toMaterialTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'Inter',
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      cardColor: surfaceCard,
      colorScheme: ColorScheme.dark(
        primary: accent,
        surface: surfaceCard,
        error: const Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),
      dividerTheme: DividerThemeData(color: borderSubtle, thickness: 1),
    );
  }

  MacosThemeData toMacosTheme() {
    final base = MacosThemeData.dark();
    return base.copyWith(
      primaryColor: accent,
      brightness: Brightness.dark,
      canvasColor: surface,
    );
  }
}
