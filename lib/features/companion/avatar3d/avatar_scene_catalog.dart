import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';

/// Loads the authored companion scenes exported from the OneWorks editor.
///
/// One JSON file holds every built-in species: its primitives, its face, its
/// camera and its light. Parsed once and kept, because it is small and every
/// companion surface wants it.
class AvatarSceneCatalog {
  AvatarSceneCatalog._();

  static final AvatarSceneCatalog instance = AvatarSceneCatalog._();

  static const String assetKey = 'assets/avatars/scenes/avatar_scenes.json';

  Map<String, AvatarScene>? _scenes;
  Future<Map<String, AvatarScene>>? _loading;

  /// Every scene, keyed by preset name (`cat`, `red-panda`, …).
  Future<Map<String, AvatarScene>> load({AssetBundle? bundle}) {
    final cached = _scenes;
    if (cached != null) return Future<Map<String, AvatarScene>>.value(cached);
    return _loading ??= _read(bundle ?? rootBundle);
  }

  Future<Map<String, AvatarScene>> _read(AssetBundle bundle) async {
    try {
      final raw = await bundle.loadString(assetKey);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _scenes = <String, AvatarScene>{};

      final scenes = <String, AvatarScene>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || value is! Map) continue;
        final scene =
            AvatarScene.fromJson(key, Map<String, dynamic>.from(value));
        if (scene != null) scenes[key] = scene;
      }
      return _scenes = scenes;
    } finally {
      _loading = null;
    }
  }

  /// The scene for [preset], once [load] has completed. Null before then.
  AvatarScene? sceneFor(String preset) => _scenes?[_normalize(preset)];

  /// Whether the catalog has a scene for this preset.
  bool has(String preset) => _scenes?.containsKey(_normalize(preset)) ?? false;

  /// Every preset name the catalog knows, sorted.
  List<String> get presets {
    final scenes = _scenes;
    if (scenes == null) return const <String>[];
    return scenes.keys.toList()..sort();
  }

  /// Maps the app's species naming onto the editor's preset names.
  ///
  /// The app uses lowerCamelCase enum names while the editor uses kebab-case,
  /// so `redPanda` and `red-panda` have to resolve to the same scene.
  static String _normalize(String preset) {
    final kebab = preset
        .replaceAllMapped(
          RegExp('([a-z0-9])([A-Z])'),
          (match) => '${match[1]}-${match[2]}',
        )
        .toLowerCase();
    return kebab;
  }

  /// Drops the parsed catalog. For tests.
  void reset() {
    _scenes = null;
    _loading = null;
  }
}
