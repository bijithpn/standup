import 'dart:ui';
import 'package:breakmate/features/companion/domain/custom_environment_layer.dart';

class ThemeAssetConfig {
  final String path;
  final bool isSpriteSheet;
  final int frameCount;
  final double spriteWidth;
  final double spriteHeight;
  final double srcX;
  final double srcY;

  const ThemeAssetConfig({
    required this.path,
    this.isSpriteSheet = false,
    this.frameCount = 1,
    this.spriteWidth = 32.0,
    this.spriteHeight = 32.0,
    this.srcX = 0.0,
    this.srcY = 0.0,
  });
}

class EnvironmentThemeConfig {
  final String id;
  final String name;
  final String skyPath;
  final String cloudPath;
  final String groundPath;
  final Color groundTint;
  final Color cloudTint;
  final Color baseColor;
  final bool isGroundTiled;
  final double skyOpacity;
  final double cloudOpacity;
  final double groundOpacity;
  final double mountainOpacity;
  final double rockOpacity;
  final double birdScale;
  final double rabbitScale;

  // Dynamic theme assets
  final ThemeAssetConfig birdAsset;
  final ThemeAssetConfig rabbitIdleAsset;
  final ThemeAssetConfig rabbitRunAsset;
  final ThemeAssetConfig mountainLeftAsset;
  final ThemeAssetConfig mountainRightAsset;
  final ThemeAssetConfig rockLeftAsset;
  final ThemeAssetConfig rockRightAsset;
  final List<CustomEnvironmentLayer> layers;
  final Map<String, ThemeAssetConfig> toyAssets;
  final Map<String, ThemeAssetConfig> foodAssets;

  // asset-migration: bird/rabbit/environment sprite assets removed
  static const _defaultBird = ThemeAssetConfig(path: '');
  static const _defaultRabbitIdle = ThemeAssetConfig(path: '');
  static const _defaultRabbitRun = ThemeAssetConfig(path: '');
  static const _defaultMountainLeft = ThemeAssetConfig(path: '');
  static const _defaultMountainRight = ThemeAssetConfig(path: '');
  static const _defaultRockLeft = ThemeAssetConfig(path: '');
  static const _defaultRockRight = ThemeAssetConfig(path: '');

  // asset-migration: throw_particles/throwable assets removed
  static const _defaultToys = <String, ThemeAssetConfig>{};
  static const _defaultFoods = <String, ThemeAssetConfig>{};

  const EnvironmentThemeConfig({
    required this.id,
    required this.name,
    required this.skyPath,
    required this.cloudPath,
    required this.groundPath,
    required this.groundTint,
    required this.cloudTint,
    required this.baseColor,
    this.isGroundTiled = true,
    this.skyOpacity = 1.0,
    this.cloudOpacity = 1.0,
    this.groundOpacity = 1.0,
    this.mountainOpacity = 1.0,
    this.rockOpacity = 1.0,
    this.birdScale = 1.0,
    this.rabbitScale = 1.0,
    this.birdAsset = _defaultBird,
    this.rabbitIdleAsset = _defaultRabbitIdle,
    this.rabbitRunAsset = _defaultRabbitRun,
    this.mountainLeftAsset = _defaultMountainLeft,
    this.mountainRightAsset = _defaultMountainRight,
    this.rockLeftAsset = _defaultRockLeft,
    this.rockRightAsset = _defaultRockRight,
    this.layers = const [],
    this.toyAssets = _defaultToys,
    this.foodAssets = _defaultFoods,
  });

  // asset-migration: all background/environment asset paths removed
  static const List<EnvironmentThemeConfig> themes = [
    EnvironmentThemeConfig(
      id: 'forest',
      name: 'Forest',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFFFFFFFF),
      cloudTint: Color(0xFFFFFFFF),
      baseColor: Color(0xFF2E2625),
    ),
    EnvironmentThemeConfig(
      id: 'autumn',
      name: 'Autumn',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFFD47A3B),
      cloudTint: Color(0xFFFFECB3),
      baseColor: Color(0xFF5D4037),
    ),
    EnvironmentThemeConfig(
      id: 'winter',
      name: 'Winter',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFFE0F7FA),
      cloudTint: Color(0xFFE0F2F1),
      baseColor: Color(0xFFECEFF1),
    ),
    EnvironmentThemeConfig(
      id: 'beach',
      name: 'Beach',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFFFFE082),
      cloudTint: Color(0xFFFFFFFF),
      baseColor: Color(0xFFFFF8E1),
    ),
    EnvironmentThemeConfig(
      id: 'desert',
      name: 'Desert',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFFFFCC80),
      cloudTint: Color(0xFFFFF9C4),
      baseColor: Color(0xFFFFE0B2),
    ),
    EnvironmentThemeConfig(
      id: 'sky',
      name: 'Sky',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFFFFFFFF),
      cloudTint: Color(0xFFFFFFFF),
      baseColor: Color(0xFF2E2625),
    ),
    EnvironmentThemeConfig(
      id: 'night_town',
      name: 'Night Town',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFF263238),
      cloudTint: Color(0xFF37474F),
      baseColor: Color(0xFF37474F),
    ),
    EnvironmentThemeConfig(
      id: 'mist_forest',
      name: 'Mist Forest',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFF90A4AE),
      cloudTint: Color(0xFFB0BEC5),
      baseColor: Color(0xFF455A64),
    ),
    EnvironmentThemeConfig(
      id: 'urban',
      name: 'Urban',
      skyPath: '',
      cloudPath: '',
      groundPath: '',
      groundTint: Color(0xFF757575),
      cloudTint: Color(0xFFCFD8DC),
      baseColor: Color(0xFF9E9E9E),
    ),
  ];

  static List<EnvironmentThemeConfig> customThemes = [];

  static EnvironmentThemeConfig getByPath(String path) {
    final lower = path.toLowerCase();

    // 1. Prioritize exact match by id (case-insensitive)
    for (final theme in customThemes) {
      if (theme.id.toLowerCase() == lower) return theme;
    }
    for (final theme in themes) {
      if (theme.id.toLowerCase() == lower) return theme;
    }

    // 2. Exact match by skyPath (case-insensitive)
    for (final theme in customThemes) {
      if (theme.skyPath.toLowerCase() == lower) return theme;
    }
    for (final theme in themes) {
      if (theme.skyPath.toLowerCase() == lower) return theme;
    }

    // 3. Fallback to contains match, sorted by ID length descending to prevent shorter prefix collisions (e.g. 'forest' matching 'mist_forest')
    final sortedCustom = List<EnvironmentThemeConfig>.from(customThemes)
      ..sort((a, b) => b.id.length.compareTo(a.id.length));
    for (final theme in sortedCustom) {
      if (lower.contains(theme.id.toLowerCase()) ||
          lower.contains(theme.skyPath.toLowerCase())) {
        return theme;
      }
    }

    final sortedPredefined = List<EnvironmentThemeConfig>.from(themes)
      ..sort((a, b) => b.id.length.compareTo(a.id.length));
    for (final theme in sortedPredefined) {
      if (lower.contains(theme.id.toLowerCase()) ||
          lower.contains(theme.skyPath.toLowerCase())) {
        return theme;
      }
    }

    return themes.first; // Default is Forest
  }
}
