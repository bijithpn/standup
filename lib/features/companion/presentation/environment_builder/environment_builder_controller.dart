import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/domain/custom_environment_layer.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

// Holds all mutable state for the Environment Builder screen.
// Follows the ChangeNotifier provider pattern used elsewhere in the app.
class EnvironmentBuilderController extends ChangeNotifier {
  EnvironmentBuilderController({
    required CustomEnvironmentRepository repository,
  }) : _repo = repository {
    _savedThemes = List.of(_repo.themes);
    _draft = CustomEnvironmentTheme.fromDefaults();
    _loadDynamicAssets();
  }

  final CustomEnvironmentRepository _repo;

  late CustomEnvironmentTheme _draft;
  late List<CustomEnvironmentTheme> _savedThemes;
  bool _isSaving = false;

  List<String> _skyPaths = [];
  List<String> _groundPaths = [];
  List<String> _cloudPaths = [];
  List<String> _mountainPaths = [];
  List<String> _rockPaths = [];
  List<String> _birdPaths = [];
  List<String> _rabbitIdlePaths = [];
  List<String> _rabbitRunPaths = [];
  List<String> _toyPaths = [];
  List<String> _foodPaths = [];
  bool _isLoadingAssets = true;

  CustomEnvironmentTheme get draft => _draft;
  List<CustomEnvironmentTheme> get savedThemes =>
      List.unmodifiable(_savedThemes);
  bool get isSaving => _isSaving;

  List<String> get skyPaths => _skyPaths;
  List<String> get groundPaths => _groundPaths;
  List<String> get cloudPaths => _cloudPaths;
  List<String> get mountainPaths => _mountainPaths;
  List<String> get rockPaths => _rockPaths;
  List<String> get birdPaths => _birdPaths;
  List<String> get rabbitIdlePaths => _rabbitIdlePaths;
  List<String> get rabbitRunPaths => _rabbitRunPaths;
  List<String> get toyPaths => _toyPaths;
  List<String> get foodPaths => _foodPaths;
  bool get isLoadingAssets => _isLoadingAssets;

  Directory? _findPhysicalAssetsDir() {
    // 1. Check current working directory (e.g. project root in debug mode)
    final projectAssets = Directory('assets');
    if (projectAssets.existsSync()) {
      return projectAssets;
    }
    // 2. Check macOS app bundle path
    try {
      final exePath = Platform.resolvedExecutable;
      final bundleResources = Directory(
        p.join(
          Directory(exePath).parent.parent.path,
          'Resources',
          'flutter_assets',
          'assets',
        ),
      );
      if (bundleResources.existsSync()) {
        return bundleResources;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadDynamicAssets() async {
    try {
      List<String> allAssets = [];

      final assetsDir = _findPhysicalAssetsDir();
      if (assetsDir != null) {
        final List<FileSystemEntity> entities = assetsDir.listSync(
          recursive: true,
        );
        for (final entity in entities) {
          if (entity is File) {
            // Get path relative to the folder above 'assets' (so it starts with 'assets/')
            final relativePath = p.relative(
              entity.path,
              from: assetsDir.parent.path,
            );
            allAssets.add(relativePath.replaceAll('\\', '/'));
          }
        }
      }

      // If we failed to find any assets via the directory scanner (e.g. platform restrictions),
      // fall back to reading the manifest.
      if (allAssets.isEmpty) {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        allAssets = manifest.listAssets();
      }

      // Filter only image and GIF assets
      allAssets = allAssets.where((path) {
        final ext = p.extension(path).toLowerCase();
        return ext == '.png' ||
            ext == '.gif' ||
            ext == '.jpg' ||
            ext == '.jpeg' ||
            ext == '.webp' ||
            ext == '.bmp';
      }).toList();

      _skyPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _groundPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _cloudPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _mountainPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _rockPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _birdPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _rabbitIdlePaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _rabbitRunPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _toyPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      _foodPaths = allAssets
          .where(
            // asset-migration: these assets have been removed
            (p) => false,
          )
          .toList();

      // Remove duplicates
      _skyPaths = _skyPaths.toSet().toList();
      _groundPaths = _groundPaths.toSet().toList();
      _cloudPaths = _cloudPaths.toSet().toList();
      _mountainPaths = _mountainPaths.toSet().toList();
      _rockPaths = _rockPaths.toSet().toList();
      _birdPaths = _birdPaths.toSet().toList();
      _rabbitIdlePaths = _rabbitIdlePaths.toSet().toList();
      _rabbitRunPaths = _rabbitRunPaths.toSet().toList();
      _toyPaths = _toyPaths.toSet().toList();
      _foodPaths = _foodPaths.toSet().toList();

      // Fallbacks
      if (_skyPaths.isEmpty) {
        _skyPaths = List.of(EnvironmentAssetCatalogue.skyPaths);
      }
      if (_groundPaths.isEmpty) {
        _groundPaths = List.of(EnvironmentAssetCatalogue.groundPaths);
      }
      if (_cloudPaths.isEmpty) {
        _cloudPaths = List.of(EnvironmentAssetCatalogue.cloudPaths);
      }
      if (_mountainPaths.isEmpty) {
        _mountainPaths = EnvironmentAssetCatalogue.mountains
            .map((c) => c.path)
            .toList();
      }
      if (_rockPaths.isEmpty) {
        _rockPaths = EnvironmentAssetCatalogue.rocks
            .map((c) => c.path)
            .toList();
      }
      if (_birdPaths.isEmpty) {
        _birdPaths = EnvironmentAssetCatalogue.birds
            .map((c) => c.path)
            .toList();
      }
      if (_rabbitIdlePaths.isEmpty) {
        _rabbitIdlePaths = EnvironmentAssetCatalogue.rabbitIdle
            .map((c) => c.path)
            .toList();
      }
      if (_rabbitRunPaths.isEmpty) {
        _rabbitRunPaths = EnvironmentAssetCatalogue.rabbitRun
            .map((c) => c.path)
            .toList();
      }
      if (_toyPaths.isEmpty) {
        _toyPaths = EnvironmentAssetCatalogue.toys.values
            .map((c) => c.path)
            .toList();
      }
      if (_foodPaths.isEmpty) {
        _foodPaths = EnvironmentAssetCatalogue.foods.values
            .map((c) => c.path)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading dynamic assets: $e');
      _skyPaths = List.of(EnvironmentAssetCatalogue.skyPaths);
      _groundPaths = List.of(EnvironmentAssetCatalogue.groundPaths);
      _cloudPaths = List.of(EnvironmentAssetCatalogue.cloudPaths);
      _mountainPaths = EnvironmentAssetCatalogue.mountains
          .map((c) => c.path)
          .toList();
      _rockPaths = EnvironmentAssetCatalogue.rocks.map((c) => c.path).toList();
      _birdPaths = EnvironmentAssetCatalogue.birds.map((c) => c.path).toList();
      _rabbitIdlePaths = EnvironmentAssetCatalogue.rabbitIdle
          .map((c) => c.path)
          .toList();
      _rabbitRunPaths = EnvironmentAssetCatalogue.rabbitRun
          .map((c) => c.path)
          .toList();
      _toyPaths = EnvironmentAssetCatalogue.toys.values
          .map((c) => c.path)
          .toList();
      _foodPaths = EnvironmentAssetCatalogue.foods.values
          .map((c) => c.path)
          .toList();
    } finally {
      _isLoadingAssets = false;
      notifyListeners();
    }
  }

  // ── Draft mutations ──────────────────────────────────────────────────────

  void updateName(String name) {
    _draft = _draft.copyWith(name: name);
    notifyListeners();
  }

  void updateSky(String path) {
    _draft = _draft.copyWith(skyPath: path);
    notifyListeners();
  }

  void updateGround(String path) {
    final bool isTiled = !path.contains('bg_foreground');
    _draft = _draft.copyWith(groundPath: path, isGroundTiled: isTiled);
    notifyListeners();
  }

  void updateIsGroundTiled(bool value) {
    _draft = _draft.copyWith(isGroundTiled: value);
    notifyListeners();
  }

  void updateSkyOpacity(double value) {
    _draft = _draft.copyWith(skyOpacity: value.clamp(0.0, 1.0));
    notifyListeners();
  }

  void updateCloudOpacity(double value) {
    _draft = _draft.copyWith(cloudOpacity: value.clamp(0.0, 1.0));
    notifyListeners();
  }

  void updateGroundOpacity(double value) {
    _draft = _draft.copyWith(groundOpacity: value.clamp(0.0, 1.0));
    notifyListeners();
  }

  void updateMountainOpacity(double value) {
    _draft = _draft.copyWith(mountainOpacity: value.clamp(0.0, 1.0));
    notifyListeners();
  }

  void updateRockOpacity(double value) {
    _draft = _draft.copyWith(rockOpacity: value.clamp(0.0, 1.0));
    notifyListeners();
  }

  void updateBirdScale(double value) {
    _draft = _draft.copyWith(birdScale: value.clamp(0.1, 3.0));
    notifyListeners();
  }

  void updateRabbitScale(double value) {
    _draft = _draft.copyWith(rabbitScale: value.clamp(0.1, 3.0));
    notifyListeners();
  }

  void updateCloud(String path) {
    _draft = _draft.copyWith(cloudPath: path);
    notifyListeners();
  }

  void updateGroundTint(Color color) {
    _draft = _draft.copyWith(groundTintArgb: color.toARGB32());
    notifyListeners();
  }

  void updateCloudTint(Color color) {
    _draft = _draft.copyWith(cloudTintArgb: color.toARGB32());
    notifyListeners();
  }

  void updateBaseColor(Color color) {
    _draft = _draft.copyWith(baseColorArgb: color.toARGB32());
    notifyListeners();
  }

  void updateBird(String path) {
    _draft = _draft.copyWith(birdPath: path);
    notifyListeners();
  }

  void updateRabbitIdle(String path) {
    _draft = _draft.copyWith(rabbitIdlePath: path);
    notifyListeners();
  }

  void updateRabbitRun(String path) {
    _draft = _draft.copyWith(rabbitRunPath: path);
    notifyListeners();
  }

  void updateMountainLeft(String path) {
    _draft = _draft.copyWith(mountainLeftPath: path);
    notifyListeners();
  }

  void updateMountainRight(String path) {
    _draft = _draft.copyWith(mountainRightPath: path);
    notifyListeners();
  }

  void updateRockLeft(String path) {
    _draft = _draft.copyWith(rockLeftPath: path);
    notifyListeners();
  }

  void updateRockRight(String path) {
    _draft = _draft.copyWith(rockRightPath: path);
    notifyListeners();
  }

  void updateToy(String key, String path) {
    final updated = Map<String, String>.of(_draft.toyPaths)..[key] = path;
    _draft = _draft.copyWith(toyPaths: updated);
    notifyListeners();
  }

  void updateFood(String key, String path) {
    final updated = Map<String, String>.of(_draft.foodPaths)..[key] = path;
    _draft = _draft.copyWith(foodPaths: updated);
    notifyListeners();
  }

  // Reset draft to factory defaults.
  void resetDraft() {
    _draft = CustomEnvironmentTheme.fromDefaults();
    notifyListeners();
  }

  // Load an existing saved theme into the draft for editing.
  void loadForEditing(CustomEnvironmentTheme theme) {
    _draft = theme.copyWith(id: theme.id);
    notifyListeners();
  }

  // ── Layer Management ──────────────────────────────────────────────────────

  void addLayer(String assetPath) {
    final isCloud = assetPath.contains('/sky/') || assetPath.contains('cloud');
    final mSec = DateTime.now().millisecondsSinceEpoch;
    final newLayer = CustomEnvironmentLayer(
      id: 'layer_${mSec}_${_draft.layers.length}',
      assetPath: assetPath,
      xRatio: 0.5,
      yRatio: isCloud ? 0.7 : 0.0,
      scale: 1.0,
      opacity: 1.0,
      flipX: false,
    );
    _draft = _draft.copyWith(layers: [..._draft.layers, newLayer]);
    notifyListeners();
  }

  void removeLayer(String id) {
    _draft = _draft.copyWith(
      layers: _draft.layers.where((l) => l.id != id).toList(),
    );
    notifyListeners();
  }

  void updateLayer(CustomEnvironmentLayer updated) {
    _draft = _draft.copyWith(
      layers: _draft.layers
          .map((l) => l.id == updated.id ? updated : l)
          .toList(),
    );
    notifyListeners();
  }

  void reorderLayers(int oldIndex, int newIndex) {
    final list = List<CustomEnvironmentLayer>.of(_draft.layers);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _draft = _draft.copyWith(layers: list);
    notifyListeners();
  }

  void duplicateLayer(CustomEnvironmentLayer layer) {
    final mSec = DateTime.now().millisecondsSinceEpoch;
    final duplicated = layer.copyWith(
      id: 'layer_${mSec}_dup',
      xRatio: (layer.xRatio + 0.05).clamp(0.0, 1.0),
    );
    final index = _draft.layers.indexOf(layer);
    final list = List<CustomEnvironmentLayer>.of(_draft.layers);
    if (index != -1) {
      list.insert(index + 1, duplicated);
    } else {
      list.add(duplicated);
    }
    _draft = _draft.copyWith(layers: list);
    notifyListeners();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> saveCurrentDraft() async {
    if (_isSaving) return;
    _isSaving = true;
    notifyListeners();
    try {
      await _repo.upsert(_draft);
      _savedThemes = List.of(_repo.themes);
      final settingsRepo = sl<SettingsRepository>();
      final updated = settingsRepo.currentSettings.copyWith(
        companionPreviewBackground: _draft.id,
      );
      await settingsRepo.save(updated);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteSavedTheme(String id) async {
    await _repo.delete(id);
    _savedThemes = List.of(_repo.themes);
    notifyListeners();
  }

  // ── Code generation ──────────────────────────────────────────────────────

  String generateDartCode() {
    final d = _draft;

    String colorCode(int argb) {
      final hex = argb.toRadixString(16).toUpperCase().padLeft(8, '0');
      return 'Color(0x$hex)';
    }

    String asset(
      String path, {
      bool isSpriteSheet = false,
      int frameCount = 1,
      double w = 32,
      double h = 32,
    }) {
      if (!isSpriteSheet) return "ThemeAssetConfig(path: '$path')";
      return "ThemeAssetConfig(path: '$path', isSpriteSheet: true, frameCount: $frameCount, spriteWidth: ${w.toStringAsFixed(1)}, spriteHeight: ${h.toStringAsFixed(1)})";
    }

    final bird = EnvironmentAssetCatalogue.findByPath(d.birdPath);
    final rabbitIdle = EnvironmentAssetCatalogue.findByPath(d.rabbitIdlePath);
    final rabbitRun = EnvironmentAssetCatalogue.findByPath(d.rabbitRunPath);
    final mtnL = EnvironmentAssetCatalogue.findByPath(d.mountainLeftPath);
    final mtnR = EnvironmentAssetCatalogue.findByPath(d.mountainRightPath);
    final rockL = EnvironmentAssetCatalogue.findByPath(d.rockLeftPath);
    final rockR = EnvironmentAssetCatalogue.findByPath(d.rockRightPath);

    final toyEntries = d.toyPaths.entries
        .map((e) {
          final cfg = EnvironmentAssetCatalogue.findByPath(e.value);
          final assetCode = cfg != null
              ? asset(
                  e.value,
                  isSpriteSheet: cfg.isSpriteSheet,
                  frameCount: cfg.frameCount,
                  w: cfg.spriteWidth,
                  h: cfg.spriteHeight,
                )
              : asset(e.value);
          return "        '${e.key}': $assetCode,";
        })
        .join('\n');

    final foodEntries = d.foodPaths.entries
        .map((e) {
          final cfg = EnvironmentAssetCatalogue.findByPath(e.value);
          final assetCode = cfg != null
              ? asset(
                  e.value,
                  isSpriteSheet: cfg.isSpriteSheet,
                  frameCount: cfg.frameCount,
                  w: cfg.spriteWidth,
                  h: cfg.spriteHeight,
                )
              : asset(e.value);
          return "        '${e.key}': $assetCode,";
        })
        .join('\n');

    final birdCode = bird != null
        ? asset(
            d.birdPath,
            isSpriteSheet: bird.isSpriteSheet,
            frameCount: bird.frameCount,
            w: bird.spriteWidth,
            h: bird.spriteHeight,
          )
        : asset(d.birdPath);
    final riCode = rabbitIdle != null
        ? asset(
            d.rabbitIdlePath,
            isSpriteSheet: rabbitIdle.isSpriteSheet,
            frameCount: rabbitIdle.frameCount,
            w: rabbitIdle.spriteWidth,
            h: rabbitIdle.spriteHeight,
          )
        : asset(d.rabbitIdlePath);
    final rrCode = rabbitRun != null
        ? asset(
            d.rabbitRunPath,
            isSpriteSheet: rabbitRun.isSpriteSheet,
            frameCount: rabbitRun.frameCount,
            w: rabbitRun.spriteWidth,
            h: rabbitRun.spriteHeight,
          )
        : asset(d.rabbitRunPath);

    final layersCode = d.layers
        .map((l) {
          return "    CustomEnvironmentLayer(id: '${l.id}', assetPath: '${l.assetPath}', xRatio: ${l.xRatio.toStringAsFixed(2)}, yRatio: ${l.yRatio.toStringAsFixed(2)}, scale: ${l.scale.toStringAsFixed(2)}, opacity: ${l.opacity.toStringAsFixed(2)}, flipX: ${l.flipX}),";
        })
        .join('\n');

    return '''EnvironmentThemeConfig(
  id: '${d.id}',
  name: '${d.name}',
  skyPath: '${d.skyPath}',
  cloudPath: '${d.cloudPath}',
  groundPath: '${d.groundPath}',
  isGroundTiled: ${d.isGroundTiled},
  groundTint: ${colorCode(d.groundTintArgb)},
  cloudTint: ${colorCode(d.cloudTintArgb)},
  baseColor: ${colorCode(d.baseColorArgb)},
  skyOpacity: ${d.skyOpacity.toStringAsFixed(2)},
  cloudOpacity: ${d.cloudOpacity.toStringAsFixed(2)},
  groundOpacity: ${d.groundOpacity.toStringAsFixed(2)},
  mountainOpacity: ${d.mountainOpacity.toStringAsFixed(2)},
  rockOpacity: ${d.rockOpacity.toStringAsFixed(2)},
  birdScale: ${d.birdScale.toStringAsFixed(2)},
  rabbitScale: ${d.rabbitScale.toStringAsFixed(2)},
  birdAsset: $birdCode,
  rabbitIdleAsset: $riCode,
  rabbitRunAsset: $rrCode,
  mountainLeftAsset: ${mtnL != null ? asset(d.mountainLeftPath) : asset(d.mountainLeftPath)},
  mountainRightAsset: ${mtnR != null ? asset(d.mountainRightPath) : asset(d.mountainRightPath)},
  rockLeftAsset: ${rockL != null ? asset(d.rockLeftPath) : asset(d.rockLeftPath)},
  rockRightAsset: ${rockR != null ? asset(d.rockRightPath) : asset(d.rockRightPath)},
  layers: [
$layersCode
  ],
  toyAssets: {
$toyEntries
  },
  foodAssets: {
$foodEntries
  },
),''';
  }
}
