import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';

/// Singleton that lazily loads and caches all preset scenes from the bundled JSON.
class AvatarSceneCatalog {
  AvatarSceneCatalog._();

  static final AvatarSceneCatalog instance = AvatarSceneCatalog._();

  static const String assetKey = 'assets/avatars/scenes/avatar_scenes.json';

  Map<String, AvatarScene>? _scenes;
  Future<Map<String, AvatarScene>>? _loading;

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
        final scene = AvatarScene.fromJson(
          key,
          Map<String, dynamic>.from(value),
        );
        if (scene != null) scenes[key] = scene;
      }
      return _scenes = scenes;
    } finally {
      _loading = null;
    }
  }

  AvatarScene? sceneFor(String preset) => _scenes?[_normalize(preset)];

  bool has(String preset) => _scenes?.containsKey(_normalize(preset)) ?? false;

  List<String> get presets {
    final scenes = _scenes;
    if (scenes == null) return const <String>[];
    return scenes.keys.toList()..sort();
  }

  static String _normalize(String preset) {
    final kebab = preset
        .replaceAllMapped(
          RegExp('([a-z0-9])([A-Z])'),
          (match) => '${match[1]}-${match[2]}',
        )
        .toLowerCase();
    return kebab;
  }

  void reset() {
    _scenes = null;
    _loading = null;
  }
}
