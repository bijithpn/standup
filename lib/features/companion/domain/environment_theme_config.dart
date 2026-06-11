import 'dart:ui';

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

  // Dynamic theme assets
  final ThemeAssetConfig birdAsset;
  final ThemeAssetConfig rabbitIdleAsset;
  final ThemeAssetConfig rabbitRunAsset;
  final ThemeAssetConfig mountainLeftAsset;
  final ThemeAssetConfig mountainRightAsset;
  final ThemeAssetConfig rockLeftAsset;
  final ThemeAssetConfig rockRightAsset;
  final Map<String, ThemeAssetConfig> toyAssets;
  final Map<String, ThemeAssetConfig> foodAssets;

  static const _defaultBird = ThemeAssetConfig(
    path: 'assets/animations/birds/flying_creature_cycle_2.png',
    isSpriteSheet: true,
    frameCount: 7,
    spriteWidth: 32.0,
    spriteHeight: 32.0,
  );

  static const _defaultRabbitIdle = ThemeAssetConfig(
    path: 'assets/animations/rabbit/rabbit_1.png',
    isSpriteSheet: true,
    frameCount: 12,
    spriteWidth: 32.0,
    spriteHeight: 32.0,
  );

  static const _defaultRabbitRun = ThemeAssetConfig(
    path: 'assets/animations/rabbit/rabbit_1_run.png',
    isSpriteSheet: true,
    frameCount: 8,
    spriteWidth: 32.0,
    spriteHeight: 32.0,
  );

  static const _defaultMountainLeft = ThemeAssetConfig(
    path: 'assets/environments/trees/tree_sunny_mountains.png',
  );

  static const _defaultMountainRight = ThemeAssetConfig(
    path: 'assets/environments/trees/tree_sunny_mountains.png',
  );

  static const _defaultRockLeft = ThemeAssetConfig(
    path: 'assets/environments/rocks/rock_shadow_1_1.png',
  );

  static const _defaultRockRight = ThemeAssetConfig(
    path: 'assets/environments/rocks/rock_shadow_2_2.png',
  );

  static const _defaultToys = {
    'tennis_ball': ThemeAssetConfig(path: 'assets/animations/throw_particles/tennis_ball.png'),
    'base_ball': ThemeAssetConfig(path: 'assets/animations/throw_particles/base_ball.png'),
    'basket_ball': ThemeAssetConfig(path: 'assets/animations/throw_particles/basket_ball.png'),
    'football': ThemeAssetConfig(path: 'assets/animations/throw_particles/football.png'),
  };

  static const _defaultFoods = {
    'carrot': ThemeAssetConfig(
      path: 'assets/environments/throwable/throwable_grass_wood_snacks.png',
      isSpriteSheet: true,
      frameCount: 1,
      spriteWidth: 16.0,
      spriteHeight: 16.0,
      srcX: 0.0,
      srcY: 0.0,
    ),
    'bone': ThemeAssetConfig(
      path: 'assets/environments/throwable/throwable_dog_items.png',
      isSpriteSheet: true,
      frameCount: 1,
      spriteWidth: 32.0,
      spriteHeight: 32.0,
      srcX: 0.0,
      srcY: 0.0,
    ),
  };

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
    this.birdAsset = _defaultBird,
    this.rabbitIdleAsset = _defaultRabbitIdle,
    this.rabbitRunAsset = _defaultRabbitRun,
    this.mountainLeftAsset = _defaultMountainLeft,
    this.mountainRightAsset = _defaultMountainRight,
    this.rockLeftAsset = _defaultRockLeft,
    this.rockRightAsset = _defaultRockRight,
    this.toyAssets = _defaultToys,
    this.foodAssets = _defaultFoods,
  });

  static const List<EnvironmentThemeConfig> themes = [
    EnvironmentThemeConfig(
      id: 'forest',
      name: 'Forest',
      skyPath: 'assets/background/forest/background.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_nature_4_3.png',
      groundTint: Color(0xFFFFFFFF),
      cloudTint: Color(0xFFFFFFFF),
      baseColor: Color(0xFF2E2625),
    ),
    EnvironmentThemeConfig(
      id: 'autumn',
      name: 'Autumn',
      skyPath: 'assets/background/autumn/background.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_nature_3_4.png',
      groundTint: Color(0xFFD47A3B),
      cloudTint: Color(0xFFFFECB3),
      baseColor: Color(0xFF5D4037),
      birdAsset: ThemeAssetConfig(
        path: 'assets/animations/birds/flying_creature_cycle_skin_2.png',
        isSpriteSheet: true,
        frameCount: 7,
      ),
      rabbitIdleAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_3.png',
        isSpriteSheet: true,
        frameCount: 12,
      ),
      rabbitRunAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_3_running.png',
        isSpriteSheet: true,
        frameCount: 8,
      ),
    ),
    EnvironmentThemeConfig(
      id: 'winter',
      name: 'Winter',
      skyPath: 'assets/background/winter/background.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_nature_6_3.png',
      groundTint: Color(0xFFE0F7FA),
      cloudTint: Color(0xFFE0F2F1),
      baseColor: Color(0xFFECEFF1),
      rabbitIdleAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_2.png',
        isSpriteSheet: true,
        frameCount: 12,
      ),
      rabbitRunAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_2_runing.png',
        isSpriteSheet: true,
        frameCount: 8,
      ),
    ),
    EnvironmentThemeConfig(
      id: 'beach',
      name: 'Beach',
      skyPath: 'assets/background/beach/background-light.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_summer_1_3.png',
      groundTint: Color(0xFFFFE082),
      cloudTint: Color(0xFFFFFFFF),
      baseColor: Color(0xFFFFF8E1),
      rabbitIdleAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_4.png',
        isSpriteSheet: true,
        frameCount: 12,
      ),
      rabbitRunAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_4_run.png',
        isSpriteSheet: true,
        frameCount: 8,
      ),
    ),
    EnvironmentThemeConfig(
      id: 'desert',
      name: 'Desert',
      skyPath: 'assets/background/desert/background.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_summer_5_4.png',
      groundTint: Color(0xFFFFCC80),
      cloudTint: Color(0xFFFFF9C4),
      baseColor: Color(0xFFFFE0B2),
      birdAsset: ThemeAssetConfig(
        path: 'assets/animations/birds/flying_creature_cycle_skin_2.png',
        isSpriteSheet: true,
        frameCount: 7,
      ),
      rockLeftAsset: ThemeAssetConfig(
        path: 'assets/environments/rocks/rock_shadow_3_1.png',
      ),
      rockRightAsset: ThemeAssetConfig(
        path: 'assets/environments/rocks/rock_shadow_1_4.png',
      ),
    ),
    EnvironmentThemeConfig(
      id: 'sky',
      name: 'Sky',
      skyPath: 'assets/environments/sky/sky_back.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_base.png',
      groundTint: Color(0xFFFFFFFF),
      cloudTint: Color(0xFFFFFFFF),
      baseColor: Color(0xFF2E2625),
    ),
    EnvironmentThemeConfig(
      id: 'night_town',
      name: 'Night Town',
      skyPath: 'assets/environments/background/bg_night_town.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_base.png',
      groundTint: Color(0xFF263238),
      cloudTint: Color(0xFF37474F),
      baseColor: Color(0xFF37474F),
      birdAsset: ThemeAssetConfig(
        path: 'assets/animations/birds/flying_creature_cycle_skin_2.png',
        isSpriteSheet: true,
        frameCount: 7,
      ),
      rabbitIdleAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_3.png',
        isSpriteSheet: true,
        frameCount: 12,
      ),
      rabbitRunAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_3_running.png',
        isSpriteSheet: true,
        frameCount: 8,
      ),
    ),
    EnvironmentThemeConfig(
      id: 'mist_forest',
      name: 'Mist Forest',
      skyPath: 'assets/environments/background/bg_mist_forest.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_nature_7_2.png',
      groundTint: Color(0xFF90A4AE),
      cloudTint: Color(0xFFB0BEC5),
      baseColor: Color(0xFF455A64),
      rabbitIdleAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_2.png',
        isSpriteSheet: true,
        frameCount: 12,
      ),
      rabbitRunAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_2_runing.png',
        isSpriteSheet: true,
        frameCount: 8,
      ),
    ),
    EnvironmentThemeConfig(
      id: 'urban',
      name: 'Urban',
      skyPath: 'assets/background/urban/background.png',
      cloudPath: 'assets/environments/sky/sky_cloud.png',
      groundPath: 'assets/environments/base/tile_base.png',
      groundTint: Color(0xFF757575),
      cloudTint: Color(0xFFCFD8DC),
      baseColor: Color(0xFF9E9E9E),
      rabbitIdleAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_4.png',
        isSpriteSheet: true,
        frameCount: 12,
      ),
      rabbitRunAsset: ThemeAssetConfig(
        path: 'assets/animations/rabbit/rabbit_4_run.png',
        isSpriteSheet: true,
        frameCount: 8,
      ),
    ),
  ];
  static List<EnvironmentThemeConfig> customThemes = [];

  static EnvironmentThemeConfig getByPath(String path) {
    final lower = path.toLowerCase();
    for (final theme in customThemes) {
      if (lower.contains(theme.id) || lower.contains(theme.skyPath.toLowerCase())) {
        return theme;
      }
    }
    for (final theme in themes) {
      if (lower.contains(theme.id) || lower.contains(theme.skyPath.toLowerCase())) {
        return theme;
      }
    }
    return themes.first; // Default is Forest
  }
}
