import 'dart:ui';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';
import 'package:breakmate/features/companion/domain/custom_environment_layer.dart';

// Mutable, JSON-serialisable representation of a user-created environment theme.
// Built-in EnvironmentThemeConfig.themes remains const and untouched.
class CustomEnvironmentTheme {
  String id;
  String name;
  String skyPath;
  String groundPath;
  String cloudPath;
  int groundTintArgb;
  int cloudTintArgb;
  int baseColorArgb;
  bool isGroundTiled;
  double skyOpacity;
  double cloudOpacity;
  double groundOpacity;
  double mountainOpacity;
  double rockOpacity;
  double birdScale;
  double rabbitScale;
  // NPC and decoration asset paths – stored as plain path strings.
  // isSpriteSheet / frameCount come from the asset catalogue; here we only
  // persist the selected path. The controller resolves full ThemeAssetConfig
  // when building the EnvironmentThemeConfig.
  String birdPath;
  String rabbitIdlePath;
  String rabbitRunPath;
  String mountainLeftPath;
  String mountainRightPath;
  String rockLeftPath;
  String rockRightPath;
  // Dynamic custom layers
  List<CustomEnvironmentLayer> layers;
  // Key = toy/food identifier (e.g. 'tennis_ball'), value = asset path.
  Map<String, String> toyPaths;
  Map<String, String> foodPaths;

  CustomEnvironmentTheme({
    required this.id,
    required this.name,
    required this.skyPath,
    required this.groundPath,
    required this.cloudPath,
    required this.groundTintArgb,
    required this.cloudTintArgb,
    required this.baseColorArgb,
    required this.isGroundTiled,
    required this.skyOpacity,
    required this.cloudOpacity,
    required this.groundOpacity,
    required this.mountainOpacity,
    required this.rockOpacity,
    required this.birdScale,
    required this.rabbitScale,
    required this.birdPath,
    required this.rabbitIdlePath,
    required this.rabbitRunPath,
    required this.mountainLeftPath,
    required this.mountainRightPath,
    required this.rockLeftPath,
    required this.rockRightPath,
    required this.layers,
    required this.toyPaths,
    required this.foodPaths,
  });

  factory CustomEnvironmentTheme.fromDefaults() {
    const src = EnvironmentThemeConfig.themes;
    final base = src.first; // Forest
    final mSec = DateTime.now().millisecondsSinceEpoch;
    return CustomEnvironmentTheme(
      id: 'custom_$mSec',
      name: 'My Theme',
      skyPath: base.skyPath,
      groundPath: base.groundPath,
      cloudPath: base.cloudPath,
      groundTintArgb: base.groundTint.toARGB32(),
      cloudTintArgb: base.cloudTint.toARGB32(),
      baseColorArgb: base.baseColor.toARGB32(),
      isGroundTiled: base.isGroundTiled,
      skyOpacity: base.skyOpacity,
      cloudOpacity: base.cloudOpacity,
      groundOpacity: base.groundOpacity,
      mountainOpacity: base.mountainOpacity,
      rockOpacity: base.rockOpacity,
      birdScale: base.birdScale,
      rabbitScale: base.rabbitScale,
      birdPath: base.birdAsset.path,
      rabbitIdlePath: base.rabbitIdleAsset.path,
      rabbitRunPath: base.rabbitRunAsset.path,
      mountainLeftPath: base.mountainLeftAsset.path,
      mountainRightPath: base.mountainRightAsset.path,
      rockLeftPath: base.rockLeftAsset.path,
      rockRightPath: base.rockRightAsset.path,
      layers: const [],
      toyPaths: {for (final e in base.toyAssets.entries) e.key: e.value.path},
      foodPaths: {for (final e in base.foodAssets.entries) e.key: e.value.path},
    );
  }

  factory CustomEnvironmentTheme.fromJson(Map<String, dynamic> json) {
    final defaults = CustomEnvironmentTheme.fromDefaults();
    final layersRaw = json['layers'] as List<dynamic>?;
    final List<CustomEnvironmentLayer> layers;
    if (layersRaw != null) {
      layers = layersRaw
          .map(
            (e) => CustomEnvironmentLayer.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } else {
      final mtnL =
          json['mountainLeftPath'] as String? ?? defaults.mountainLeftPath;
      final mtnR =
          json['mountainRightPath'] as String? ?? defaults.mountainRightPath;
      final rockL = json['rockLeftPath'] as String? ?? defaults.rockLeftPath;
      final rockR = json['rockRightPath'] as String? ?? defaults.rockRightPath;
      layers = [
        if (mtnL != 'none' && mtnL.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'legacy_mtn_l',
            assetPath: mtnL,
            xRatio: 0.1,
            yRatio: 0.0,
          ),
        if (mtnR != 'none' && mtnR.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'legacy_mtn_r',
            assetPath: mtnR,
            xRatio: 0.9,
            yRatio: 0.0,
          ),
        if (rockL != 'none' && rockL.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'legacy_rock_l',
            assetPath: rockL,
            xRatio: 0.18,
            yRatio: 0.0,
          ),
        if (rockR != 'none' && rockR.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'legacy_rock_r',
            assetPath: rockR,
            xRatio: 0.82,
            yRatio: 0.0,
          ),
      ];
    }

    return CustomEnvironmentTheme(
      id: json['id'] as String? ?? defaults.id,
      name: json['name'] as String? ?? defaults.name,
      skyPath: json['skyPath'] as String? ?? defaults.skyPath,
      groundPath: json['groundPath'] as String? ?? defaults.groundPath,
      cloudPath: json['cloudPath'] as String? ?? defaults.cloudPath,
      groundTintArgb:
          (json['groundTintArgb'] as num?)?.toInt() ?? defaults.groundTintArgb,
      cloudTintArgb:
          (json['cloudTintArgb'] as num?)?.toInt() ?? defaults.cloudTintArgb,
      baseColorArgb:
          (json['baseColorArgb'] as num?)?.toInt() ?? defaults.baseColorArgb,
      isGroundTiled: json['isGroundTiled'] as bool? ?? defaults.isGroundTiled,
      skyOpacity:
          (json['skyOpacity'] as num?)?.toDouble() ?? defaults.skyOpacity,
      cloudOpacity:
          (json['cloudOpacity'] as num?)?.toDouble() ?? defaults.cloudOpacity,
      groundOpacity:
          (json['groundOpacity'] as num?)?.toDouble() ?? defaults.groundOpacity,
      mountainOpacity:
          (json['mountainOpacity'] as num?)?.toDouble() ??
          defaults.mountainOpacity,
      rockOpacity:
          (json['rockOpacity'] as num?)?.toDouble() ?? defaults.rockOpacity,
      birdScale: (json['birdScale'] as num?)?.toDouble() ?? defaults.birdScale,
      rabbitScale:
          (json['rabbitScale'] as num?)?.toDouble() ?? defaults.rabbitScale,
      birdPath: json['birdPath'] as String? ?? defaults.birdPath,
      rabbitIdlePath:
          json['rabbitIdlePath'] as String? ?? defaults.rabbitIdlePath,
      rabbitRunPath: json['rabbitRunPath'] as String? ?? defaults.rabbitRunPath,
      mountainLeftPath:
          json['mountainLeftPath'] as String? ?? defaults.mountainLeftPath,
      mountainRightPath:
          json['mountainRightPath'] as String? ?? defaults.mountainRightPath,
      rockLeftPath: json['rockLeftPath'] as String? ?? defaults.rockLeftPath,
      rockRightPath: json['rockRightPath'] as String? ?? defaults.rockRightPath,
      layers: layers,
      toyPaths: _stringMap(json['toyPaths']) ?? defaults.toyPaths,
      foodPaths: _stringMap(json['foodPaths']) ?? defaults.foodPaths,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'skyPath': skyPath,
    'groundPath': groundPath,
    'cloudPath': cloudPath,
    'groundTintArgb': groundTintArgb,
    'cloudTintArgb': cloudTintArgb,
    'baseColorArgb': baseColorArgb,
    'isGroundTiled': isGroundTiled,
    'skyOpacity': skyOpacity,
    'cloudOpacity': cloudOpacity,
    'groundOpacity': groundOpacity,
    'mountainOpacity': mountainOpacity,
    'rockOpacity': rockOpacity,
    'birdScale': birdScale,
    'rabbitScale': rabbitScale,
    'birdPath': birdPath,
    'rabbitIdlePath': rabbitIdlePath,
    'rabbitRunPath': rabbitRunPath,
    'mountainLeftPath': mountainLeftPath,
    'mountainRightPath': mountainRightPath,
    'rockLeftPath': rockLeftPath,
    'rockRightPath': rockRightPath,
    'layers': layers.map((e) => e.toJson()).toList(),
    'toyPaths': toyPaths,
    'foodPaths': foodPaths,
  };

  // Builds a runtime EnvironmentThemeConfig from the asset catalogue defaults
  // for sprite-sheet metadata, substituting this theme's chosen paths.
  EnvironmentThemeConfig toEnvironmentThemeConfig() {
    ThemeAssetConfig resolveAsset(
      String path,
      ThemeAssetConfig Function() catalogueFallback,
    ) {
      final cat = EnvironmentAssetCatalogue.findByPath(path);
      if (cat != null) return cat;
      // If the path is not in the catalogue (user somehow ended up with an
      // unknown path), fall back to the single-image default.
      return catalogueFallback();
    }

    return EnvironmentThemeConfig(
      id: id,
      name: name,
      skyPath: skyPath,
      cloudPath: cloudPath,
      groundPath: groundPath,
      groundTint: Color(groundTintArgb),
      cloudTint: Color(cloudTintArgb),
      baseColor: Color(baseColorArgb),
      isGroundTiled: isGroundTiled,
      skyOpacity: skyOpacity,
      cloudOpacity: cloudOpacity,
      groundOpacity: groundOpacity,
      mountainOpacity: mountainOpacity,
      rockOpacity: rockOpacity,
      birdScale: birdScale,
      rabbitScale: rabbitScale,
      birdAsset: resolveAsset(
        birdPath,
        () => ThemeAssetConfig(path: birdPath, isSpriteSheet: false),
      ),
      rabbitIdleAsset: resolveAsset(
        rabbitIdlePath,
        () => ThemeAssetConfig(path: rabbitIdlePath, isSpriteSheet: false),
      ),
      rabbitRunAsset: resolveAsset(
        rabbitRunPath,
        () => ThemeAssetConfig(path: rabbitRunPath, isSpriteSheet: false),
      ),
      mountainLeftAsset: resolveAsset(
        mountainLeftPath,
        () => ThemeAssetConfig(path: mountainLeftPath),
      ),
      mountainRightAsset: resolveAsset(
        mountainRightPath,
        () => ThemeAssetConfig(path: mountainRightPath),
      ),
      rockLeftAsset: resolveAsset(
        rockLeftPath,
        () => ThemeAssetConfig(path: rockLeftPath),
      ),
      rockRightAsset: resolveAsset(
        rockRightPath,
        () => ThemeAssetConfig(path: rockRightPath),
      ),
      layers: layers,
      toyAssets: {
        for (final e in toyPaths.entries)
          e.key: resolveAsset(e.value, () => ThemeAssetConfig(path: e.value)),
      },
      foodAssets: {
        for (final e in foodPaths.entries)
          e.key: resolveAsset(e.value, () => ThemeAssetConfig(path: e.value)),
      },
    );
  }

  CustomEnvironmentTheme copyWith({
    String? id,
    String? name,
    String? skyPath,
    String? groundPath,
    String? cloudPath,
    int? groundTintArgb,
    int? cloudTintArgb,
    int? baseColorArgb,
    bool? isGroundTiled,
    double? skyOpacity,
    double? cloudOpacity,
    double? groundOpacity,
    double? mountainOpacity,
    double? rockOpacity,
    double? birdScale,
    double? rabbitScale,
    String? birdPath,
    String? rabbitIdlePath,
    String? rabbitRunPath,
    String? mountainLeftPath,
    String? mountainRightPath,
    String? rockLeftPath,
    String? rockRightPath,
    List<CustomEnvironmentLayer>? layers,
    Map<String, String>? toyPaths,
    Map<String, String>? foodPaths,
  }) {
    return CustomEnvironmentTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      skyPath: skyPath ?? this.skyPath,
      groundPath: groundPath ?? this.groundPath,
      cloudPath: cloudPath ?? this.cloudPath,
      groundTintArgb: groundTintArgb ?? this.groundTintArgb,
      cloudTintArgb: cloudTintArgb ?? this.cloudTintArgb,
      baseColorArgb: baseColorArgb ?? this.baseColorArgb,
      isGroundTiled: isGroundTiled ?? this.isGroundTiled,
      skyOpacity: skyOpacity ?? this.skyOpacity,
      cloudOpacity: cloudOpacity ?? this.cloudOpacity,
      groundOpacity: groundOpacity ?? this.groundOpacity,
      mountainOpacity: mountainOpacity ?? this.mountainOpacity,
      rockOpacity: rockOpacity ?? this.rockOpacity,
      birdScale: birdScale ?? this.birdScale,
      rabbitScale: rabbitScale ?? this.rabbitScale,
      birdPath: birdPath ?? this.birdPath,
      rabbitIdlePath: rabbitIdlePath ?? this.rabbitIdlePath,
      rabbitRunPath: rabbitRunPath ?? this.rabbitRunPath,
      mountainLeftPath: mountainLeftPath ?? this.mountainLeftPath,
      mountainRightPath: mountainRightPath ?? this.mountainRightPath,
      rockLeftPath: rockLeftPath ?? this.rockLeftPath,
      rockRightPath: rockRightPath ?? this.rockRightPath,
      layers: layers ?? List.of(this.layers),
      toyPaths: toyPaths ?? Map.of(this.toyPaths),
      foodPaths: foodPaths ?? Map.of(this.foodPaths),
    );
  }

  static Map<String, String>? _stringMap(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return raw.cast<String, String>();
    } catch (_) {
      return null;
    }
  }
}

// Static catalogue that maps asset paths to their ThemeAssetConfig metadata.
// This avoids duplicating sprite-sheet metadata in the persisted JSON.
class EnvironmentAssetCatalogue {
  static const List<ThemeAssetConfig> birds = [
    ThemeAssetConfig(
      path: 'assets/animations/birds/flying_creature_cycle_2.png',
      isSpriteSheet: true,
      frameCount: 7,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: 'assets/animations/birds/flying_creature_cycle_skin_2.png',
      isSpriteSheet: true,
      frameCount: 7,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
  ];

  static const List<ThemeAssetConfig> rabbitIdle = [
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_1.png',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_2.png',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_3.png',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_4.png',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
  ];

  static const List<ThemeAssetConfig> rabbitRun = [
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_1_run.png',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_2_runing.png',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_3_running.png',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: 'assets/animations/rabbit/rabbit_4_run.png',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
  ];

  static const List<ThemeAssetConfig> mountains = [
    ThemeAssetConfig(
      path: 'assets/environments/trees/tree_sunny_mountains.png',
    ),
    ThemeAssetConfig(path: 'assets/environments/trees/tree_nature_1_5.png'),
    ThemeAssetConfig(path: 'assets/environments/trees/tree_nature_1_6.png'),
    ThemeAssetConfig(path: 'assets/environments/trees/tree_nature_1_7.png'),
  ];

  static const List<ThemeAssetConfig> rocks = [
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_1_1.png'),
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_1_2.png'),
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_1_3.png'),
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_1_4.png'),
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_2_1.png'),
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_2_2.png'),
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_2_3.png'),
    ThemeAssetConfig(path: 'assets/environments/rocks/rock_shadow_3_1.png'),
  ];

  static const List<String> skyPaths = [
    'assets/background/forest/background.png',
    'assets/background/autumn/background.png',
    'assets/background/winter/background.png',
    'assets/background/desert/background.png',
    'assets/background/urban/background.png',
    'assets/environments/sky/sky_back.png',
    'assets/environments/sky/sky_back_alt.png',
    'assets/environments/sky/sky_canyon.png',
    'assets/environments/sky/sky_blue_stars.png',
    'assets/environments/sky/origbig_5_2.png',
    'assets/environments/sky/sky_summer_1_1.png',
    'assets/environments/sky/sky_summer_3_2.png',
    'assets/environments/sky/sky_summer_3_3.png',
    'assets/environments/sky/sky_summer_4_1.png',
    'assets/environments/sky/sky_summer_5_1.png',
    'assets/environments/sky/sky_ocean_1_4.png',
    'assets/environments/sky/sky_ocean_2_5.png',
    'assets/environments/sky/sky_ocean_5_5.png',
    'assets/environments/sky/sky_nature_1_2.png',
    'assets/environments/sky/sky_nature_5_2.png',
    'assets/environments/sky/sky_nature_6_1.png',
    'assets/environments/background/bg_night_town.png',
    'assets/environments/background/bg_mist_forest.png',
    'assets/environments/background/bg_origbig_2_2.png',
    'assets/environments/background/bg_origbig_8.png',
    'assets/environments/background/bg_summer_5.png',
    'assets/environments/background/bg_summer_6.png',
    'assets/environments/background/bg_ocean_8_6.png',
    'assets/environments/background/bg_ocean_3_5.png',
  ];

  static const List<String> groundPaths = [
    'assets/environments/base/tile_nature_4_3.png',
    'assets/environments/base/tile_nature_3_4.png',
    'assets/environments/base/tile_nature_6_3.png',
    'assets/environments/base/tile_summer_1_3.png',
    'assets/environments/base/tile_summer_5_4.png',
    'assets/environments/base/tile_base.png',
    'assets/environments/base/tile_nature_7_2.png',
    'assets/environments/base/tile_nature_2_3.png',
    'assets/environments/base/tile_nature_2_4.png',
    'assets/environments/base/tile_nature_4_4.png',
    'assets/environments/base/tile_nature_5_3.png',
    'assets/environments/base/tile_summer_4_3.png',
    'assets/environments/background/bg_foreground_4.png',
    'assets/environments/background/bg_foreground_empty.png',
  ];

  static const List<String> cloudPaths = [
    'assets/environments/sky/sky_cloud.png',
    'assets/environments/sky/sky_clouds_3.png',
    'assets/environments/sky/sky_clouds_4.png',
    'assets/environments/sky/sky_clouds_5.png',
    'assets/environments/sky/sky_clouds_6.png',
    'assets/environments/sky/sky_clouds_1_3.png',
    'assets/environments/sky/sky_clouds_2_4.png',
    'assets/environments/sky/sky_clouds_2_alt.png',
    'assets/environments/sky/sky_clouds_3_2.png',
    'assets/environments/sky/sky_clouds_4_2.png',
    'assets/environments/sky/sky_clouds_4_3.png',
    'assets/environments/sky/sky_clouds_4_4.png',
    'assets/environments/sky/sky_clouds_5_2.png',
    'assets/environments/sky/sky_clouds_5_3.png',
    'assets/environments/sky/sky_clouds_5_5.png',
    'assets/environments/sky/sky_clouds_6_2.png',
    'assets/environments/sky/sky_clouds_7_3.png',
    'assets/environments/sky/sky_clouds_7_4.png',
    'assets/environments/sky/sky_clouds_8_3.png',
    'assets/environments/sky/sky_clouds_8_4.png',
    'assets/environments/sky/sky_clouds_8_6.png',
  ];

  static const Map<String, ThemeAssetConfig> toys = {
    'tennis_ball': ThemeAssetConfig(
      path: 'assets/animations/throw_particles/tennis_ball.png',
    ),
    'base_ball': ThemeAssetConfig(
      path: 'assets/animations/throw_particles/base_ball.png',
    ),
    'basket_ball': ThemeAssetConfig(
      path: 'assets/animations/throw_particles/basket_ball.png',
    ),
    'football': ThemeAssetConfig(
      path: 'assets/animations/throw_particles/football.png',
    ),
  };

  static const Map<String, ThemeAssetConfig> foods = {
    'carrot': ThemeAssetConfig(
      path: 'assets/environments/throwable/throwable_grass_wood_snacks.png',
      isSpriteSheet: true,
      frameCount: 1,
      spriteWidth: 16,
      spriteHeight: 16,
    ),
    'bone': ThemeAssetConfig(
      path: 'assets/environments/throwable/throwable_dog_items.png',
      isSpriteSheet: true,
      frameCount: 1,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
  };

  static ThemeAssetConfig? findByPath(String path) {
    for (final c in [
      ...birds,
      ...rabbitIdle,
      ...rabbitRun,
      ...mountains,
      ...rocks,
    ]) {
      if (c.path == path) return c;
    }
    for (final c in [...toys.values, ...foods.values]) {
      if (c.path == path) return c;
    }
    return null;
  }
}
