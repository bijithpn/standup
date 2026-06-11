import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/services/custom_environment_repository.dart';

// Holds all mutable state for the Environment Builder screen.
// Follows the ChangeNotifier provider pattern used elsewhere in the app.
class EnvironmentBuilderController extends ChangeNotifier {
  EnvironmentBuilderController({required CustomEnvironmentRepository repository})
      : _repo = repository {
    _savedThemes = List.of(_repo.themes);
    _draft = CustomEnvironmentTheme.fromDefaults();
  }

  final CustomEnvironmentRepository _repo;

  late CustomEnvironmentTheme _draft;
  late List<CustomEnvironmentTheme> _savedThemes;
  bool _isSaving = false;

  CustomEnvironmentTheme get draft => _draft;
  List<CustomEnvironmentTheme> get savedThemes => List.unmodifiable(_savedThemes);
  bool get isSaving => _isSaving;

  // ── Draft mutations ──────────────────────────────────────────────────────

  void updateName(String name) {
    _draft = _draft.copyWith(name: name.trim().isEmpty ? 'My Theme' : name.trim());
    notifyListeners();
  }

  void updateSky(String path) {
    _draft = _draft.copyWith(skyPath: path);
    notifyListeners();
  }

  void updateGround(String path) {
    final bool isTiled = !path.contains('bg_foreground');
    _draft = _draft.copyWith(
      groundPath: path,
      isGroundTiled: isTiled,
    );
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
    _draft = theme.copyWith(
      id: theme.id,
    );
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
      // Advance the draft to a fresh theme so the user can keep composing.
      _draft = CustomEnvironmentTheme.fromDefaults();
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

    String asset(String path, {bool isSpriteSheet = false, int frameCount = 1, double w = 32, double h = 32}) {
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
              ? asset(e.value, isSpriteSheet: cfg.isSpriteSheet, frameCount: cfg.frameCount, w: cfg.spriteWidth, h: cfg.spriteHeight)
              : asset(e.value);
          return "        '${e.key}': $assetCode,";
        })
        .join('\n');

    final foodEntries = d.foodPaths.entries
        .map((e) {
          final cfg = EnvironmentAssetCatalogue.findByPath(e.value);
          final assetCode = cfg != null
              ? asset(e.value, isSpriteSheet: cfg.isSpriteSheet, frameCount: cfg.frameCount, w: cfg.spriteWidth, h: cfg.spriteHeight)
              : asset(e.value);
          return "        '${e.key}': $assetCode,";
        })
        .join('\n');

    final birdCode = bird != null
        ? asset(d.birdPath, isSpriteSheet: bird.isSpriteSheet, frameCount: bird.frameCount, w: bird.spriteWidth, h: bird.spriteHeight)
        : asset(d.birdPath);
    final riCode = rabbitIdle != null
        ? asset(d.rabbitIdlePath, isSpriteSheet: rabbitIdle.isSpriteSheet, frameCount: rabbitIdle.frameCount, w: rabbitIdle.spriteWidth, h: rabbitIdle.spriteHeight)
        : asset(d.rabbitIdlePath);
    final rrCode = rabbitRun != null
        ? asset(d.rabbitRunPath, isSpriteSheet: rabbitRun.isSpriteSheet, frameCount: rabbitRun.frameCount, w: rabbitRun.spriteWidth, h: rabbitRun.spriteHeight)
        : asset(d.rabbitRunPath);

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
  birdAsset: $birdCode,
  rabbitIdleAsset: $riCode,
  rabbitRunAsset: $rrCode,
  mountainLeftAsset: ${mtnL != null ? asset(d.mountainLeftPath) : asset(d.mountainLeftPath)},
  mountainRightAsset: ${mtnR != null ? asset(d.mountainRightPath) : asset(d.mountainRightPath)},
  rockLeftAsset: ${rockL != null ? asset(d.rockLeftPath) : asset(d.rockLeftPath)},
  rockRightAsset: ${rockR != null ? asset(d.rockRightPath) : asset(d.rockRightPath)},
  toyAssets: {
$toyEntries
  },
  foodAssets: {
$foodEntries
  },
),''';
  }
}
