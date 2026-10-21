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
    final mtnL = base.mountainLeftAsset.path;
    final mtnR = base.mountainRightAsset.path;
    final rockL = base.rockLeftAsset.path;
    final rockR = base.rockRightAsset.path;
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
      mountainLeftPath: mtnL,
      mountainRightPath: mtnR,
      rockLeftPath: rockL,
      rockRightPath: rockR,
      layers: [
        if (mtnL != 'none' && mtnL.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'default_mtn_l',
            assetPath: mtnL,
            xRatio: 0.1,
            yRatio: 0.0,
          ),
        if (mtnR != 'none' && mtnR.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'default_mtn_r',
            assetPath: mtnR,
            xRatio: 0.9,
            yRatio: 0.0,
          ),
        if (rockL != 'none' && rockL.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'default_rock_l',
            assetPath: rockL,
            xRatio: 0.18,
            yRatio: 0.0,
          ),
        if (rockR != 'none' && rockR.isNotEmpty)
          CustomEnvironmentLayer(
            id: 'default_rock_r',
            assetPath: rockR,
            xRatio: 0.82,
            yRatio: 0.0,
          ),
      ],
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
      path: '',
      isSpriteSheet: true,
      frameCount: 7,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 7,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
  ];

  static const List<ThemeAssetConfig> rabbitIdle = [
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 12,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
  ];

  static const List<ThemeAssetConfig> rabbitRun = [
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
    ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 8,
      spriteWidth: 32,
      spriteHeight: 32,
    ),
  ];

  static const List<ThemeAssetConfig> mountains = [
    ThemeAssetConfig(
      path: '',
    ),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
  ];

  static const List<ThemeAssetConfig> rocks = [
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
    ThemeAssetConfig(path: ''),
  ];

  static const List<String> skyPaths = [
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
  ];

  static const List<String> groundPaths = [
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
  ];

  static const List<String> cloudPaths = [
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
  ];

  static const Map<String, ThemeAssetConfig> toys = {
    'tennis_ball': ThemeAssetConfig(
      path: '',
    ),
    'base_ball': ThemeAssetConfig(
      path: '',
    ),
    'basket_ball': ThemeAssetConfig(
      path: '',
    ),
    'football': ThemeAssetConfig(
      path: '',
    ),
  };

  static const Map<String, ThemeAssetConfig> foods = {
    'carrot': ThemeAssetConfig(
      path: '',
      isSpriteSheet: true,
      frameCount: 1,
      spriteWidth: 16,
      spriteHeight: 16,
    ),
    'bone': ThemeAssetConfig(
      path: '',
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
