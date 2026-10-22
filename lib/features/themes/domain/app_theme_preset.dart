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
    description:
        'Organic botanical moss surfaces with jade and sage highlights.',
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
    description:
        'High-contrast monochrome editorial layout for distraction-free focus.',
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
    description:
        'Pitch obsidian black with high-voltage lime and circuit orange.',
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

  static const crimsonEmber = AppThemePreset(
    id: 'crimson_ember',
    name: 'Crimson Ember',
    description:
        'Deep charcoal ruby base with vibrant scarlet and rose gold glow.',
    primary: Color(0xFF1E1418),
    primaryDark: Color(0xFF100A0C),
    primaryLight: Color(0xFF331F27),
    surface: Color(0xFF100A0C),
    surfaceCard: Color(0xFF1A1015),
    surfaceElevated: Color(0xFF261820),
    border: Color(0xFF3B2330),
    borderSubtle: Color(0xFF24151D),
    accent: Color(0xFFF43F5E),
    textPrimary: Color(0xFFFFF1F2),
    textSecondary: Color(0xFFFDA4AF),
    textMuted: Color(0xFF9F616D),
    shortBreak: Color(0xFFFB7185),
    longBreak: Color(0xFFE11D48),
    isDark: true,
  );

  static const oceanAbyss = AppThemePreset(
    id: 'ocean_abyss',
    name: 'Ocean Abyss',
    description:
        'Midnight sapphire depths with vivid cyan and aquamarine luminescence.',
    primary: Color(0xFF0C1929),
    primaryDark: Color(0xFF060E18),
    primaryLight: Color(0xFF172D47),
    surface: Color(0xFF060E18),
    surfaceCard: Color(0xFF0D1C2E),
    surfaceElevated: Color(0xFF132840),
    border: Color(0xFF1D395B),
    borderSubtle: Color(0xFF112338),
    accent: Color(0xFF06B6D4),
    textPrimary: Color(0xFFECFEFF),
    textSecondary: Color(0xFFA5F3FC),
    textMuted: Color(0xFF4B778D),
    shortBreak: Color(0xFF22D3EE),
    longBreak: Color(0xFF3B82F6),
    isDark: true,
  );

  static const auroraBorealis = AppThemePreset(
    id: 'aurora_borealis',
    name: 'Aurora Borealis',
    description:
        'Arctic polar night with radiant celestial emerald and violet flare.',
    primary: Color(0xFF0E1A1A),
    primaryDark: Color(0xFF070F0F),
    primaryLight: Color(0xFF192C2C),
    surface: Color(0xFF070F0F),
    surfaceCard: Color(0xFF0F1E1E),
    surfaceElevated: Color(0xFF172D2D),
    border: Color(0xFF234444),
    borderSubtle: Color(0xFF142727),
    accent: Color(0xFF2DD4BF),
    textPrimary: Color(0xFFF0FDF4),
    textSecondary: Color(0xFF99F6E4),
    textMuted: Color(0xFF5E8B85),
    shortBreak: Color(0xFF34D399),
    longBreak: Color(0xFFA855F7),
    isDark: true,
  );

  static const desertDusk = AppThemePreset(
    id: 'desert_dusk',
    name: 'Desert Dusk',
    description:
        'Warm terracotta and canyon clay with radiant twilight apricot.',
    primary: Color(0xFF221714),
    primaryDark: Color(0xFF140D0B),
    primaryLight: Color(0xFF382520),
    surface: Color(0xFF140D0B),
    surfaceCard: Color(0xFF1D1411),
    surfaceElevated: Color(0xFF2B1D19),
    border: Color(0xFF3E2B25),
    borderSubtle: Color(0xFF261915),
    accent: Color(0xFFFB923C),
    textPrimary: Color(0xFFFFF7ED),
    textSecondary: Color(0xFFFDBA74),
    textMuted: Color(0xFF9A7463),
    shortBreak: Color(0xFFF97316),
    longBreak: Color(0xFFEA580C),
    isDark: true,
  );

  static const lavenderMist = AppThemePreset(
    id: 'lavender_mist',
    name: 'Lavender Mist',
    description:
        'Serene twilight plum atmosphere with soft pastel lilac luminescence.',
    primary: Color(0xFF191624),
    primaryDark: Color(0xFF0F0D17),
    primaryLight: Color(0xFF2B253C),
    surface: Color(0xFF0F0D17),
    surfaceCard: Color(0xFF161321),
    surfaceElevated: Color(0xFF201C2F),
    border: Color(0xFF312B47),
    borderSubtle: Color(0xFF1D192B),
    accent: Color(0xFFA78BFA),
    textPrimary: Color(0xFFF5F3FF),
    textSecondary: Color(0xFFDDD6FE),
    textMuted: Color(0xFF8B82A6),
    shortBreak: Color(0xFFC084FC),
    longBreak: Color(0xFF818CF8),
    isDark: true,
  );

  static const monokaiPro = AppThemePreset(
    id: 'monokai_pro',
    name: 'Monokai Pro',
    description:
        'Classic anthracite developer aesthetic with vivid yellow and magenta highlights.',
    primary: Color(0xFF222227),
    primaryDark: Color(0xFF17171A),
    primaryLight: Color(0xFF36363D),
    surface: Color(0xFF17171A),
    surfaceCard: Color(0xFF1E1E23),
    surfaceElevated: Color(0xFF282830),
    border: Color(0xFF3B3B46),
    borderSubtle: Color(0xFF26262E),
    accent: Color(0xFFFFD866),
    textPrimary: Color(0xFFFCFCFA),
    textSecondary: Color(0xFFB5B5BE),
    textMuted: Color(0xFF72707E),
    shortBreak: Color(0xFFFF6188),
    longBreak: Color(0xFF78DCE8),
    isDark: true,
  );

  /// A soft, everyday light theme — warm-gray surface, muted slate accent —
  /// for people who want "not dark mode" without E-Ink's high-contrast
  /// newsprint look.
  static const softLight = AppThemePreset(
    id: 'soft_light',
    name: 'Soft Light',
    description: 'Warm-gray daylight surface with a muted slate accent.',
    primary: Color(0xFFF4F4F5),
    primaryDark: Color(0xFFE4E4E7),
    primaryLight: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAF9),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF4F4F5),
    border: Color(0xFFE4E4E7),
    borderSubtle: Color(0xFFEDEDEF),
    accent: Color(0xFF64748B),
    textPrimary: Color(0xFF27272A),
    textSecondary: Color(0xFF52525B),
    textMuted: Color(0xFF9294A0),
    shortBreak: Color(0xFF0EA5E9),
    longBreak: Color(0xFF8B5CF6),
    isDark: false,
  );

  /// Translucent preset that pairs with the OS's native window vibrancy
  /// (`WindowEffect.sidebar` on macOS, `WindowEffect.acrylic` on Windows 11 —
  /// see `ThemeController._applyWindowEffect`). Surface colors here carry
  /// low alpha so the blurred desktop shows through beneath the app chrome.
  static const nativeVibrancy = AppThemePreset(
    id: 'native_vibrancy',
    name: 'Native Vibrancy',
    description: 'Translucent frosted-glass chrome using native OS blur.',
    primary: Color(0x1A18181B),
    primaryDark: Color(0x2609090B),
    primaryLight: Color(0x143F3F46),
    surface: Color(0x0009090B),
    surfaceCard: Color(0x33121214),
    surfaceElevated: Color(0x4718181B),
    border: Color(0x3327272A),
    borderSubtle: Color(0x1A18181B),
    accent: Color(0xFF38BDF8),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    shortBreak: Color(0xFF0EA5E9),
    longBreak: Color(0xFF8B5CF6),
    isDark: true,
  );

  /// Meta-preset: not a static palette. [ThemeController] resolves this to
  /// a concrete preset at runtime — following the OS's dark/light setting
  /// where available, and otherwise a Nordic Slate (day) / Solarized Amber
  /// (evening) circadian split by time of day. Its own colors are unused for
  /// rendering; they only back the preset-picker card's default preview.
  static const auto = AppThemePreset(
    id: 'auto',
    name: 'Auto',
    description: 'Follows your system appearance, or day/evening rhythm.',
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

  static const List<AppThemePreset> allPresets = [
    nordicSlate,
    solarizedAmber,
    tokyoMidnight,
    forestMatcha,
    eInkPaper,
    cyberpunk,
    crimsonEmber,
    oceanAbyss,
    auroraBorealis,
    desertDusk,
    lavenderMist,
    monokaiPro,
    softLight,
    nativeVibrancy,
    auto,
  ];

  static AppThemePreset findById(String? id) {
    if (id == null) return nordicSlate;
    return allPresets.firstWhere((p) => p.id == id, orElse: () => nordicSlate);
  }

  ThemeData toMaterialTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'Inter',
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      cardColor: surfaceCard,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: accent,
              surface: surfaceCard,
              error: const Color(0xFFEF4444),
              onPrimary: Colors.white,
              onSurface: textPrimary,
              onSurfaceVariant: textSecondary,
            )
          : ColorScheme.light(
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
    final base = isDark ? MacosThemeData.dark() : MacosThemeData.light();
    return base.copyWith(
      primaryColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      canvasColor: surface,
    );
  }
}
