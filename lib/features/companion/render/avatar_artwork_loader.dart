import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_graphics/vector_graphics.dart';

import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_worker.dart';

/// Vector-graphics BytesLoader that compiles SVG per recipe in a worker isolate, with an LRU cache and de-duplicated in-flight requests.
@immutable
class AvatarArtworkLoader extends BytesLoader {
  const AvatarArtworkLoader(this.recipe, {this.bundle});

  final AvatarArtworkRecipe recipe;

  final AssetBundle? bundle;

  static final LinkedHashMap<AvatarArtworkRecipe, Uint8List> _compiled =
      LinkedHashMap<AvatarArtworkRecipe, Uint8List>();

  static final Map<AvatarArtworkRecipe, Future<Uint8List>> _inFlight =
      <AvatarArtworkRecipe, Future<Uint8List>>{};

  static const int _maxCachedRecipes = 200;

  @override
  Future<ByteData> loadBytes(BuildContext? context) async {
    final bytes = await _resolve(context);
    return ByteData.sublistView(bytes);
  }

  Future<Uint8List> _resolve(BuildContext? context) {
    final cached = _compiled.remove(recipe);
    if (cached != null) {
      _compiled[recipe] = cached;
      return Future<Uint8List>.value(cached);
    }

    final pending = _inFlight[recipe];
    if (pending != null) return pending;

    final assetBundle =
        bundle ??
        (context == null ? rootBundle : DefaultAssetBundle.of(context));

    final future = _compile(assetBundle);
    _inFlight[recipe] = future;
    return future;
  }

  Future<Uint8List> _compile(AssetBundle assetBundle) async {
    try {
      final raw = await assetBundle.load(recipe.assetKey);
      final compiled = await AvatarArtworkWorker.instance.compile(
        recipe,
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
      );

      _compiled[recipe] = compiled;
      while (_compiled.length > _maxCachedRecipes) {
        _compiled.remove(_compiled.keys.first);
      }
      return compiled;
    } finally {
      _inFlight.remove(recipe);
    }
  }

  static Future<void> precache(
    Iterable<AvatarArtworkRecipe> recipes, {
    AssetBundle? bundle,
  }) async {
    for (final recipe in recipes) {
      try {
        await AvatarArtworkLoader(recipe, bundle: bundle)._resolve(null);
      } catch (_) {}
    }
  }

  static void evictAll() {
    _compiled.clear();
  }

  @override
  Object cacheKey(BuildContext? context) => recipe;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarArtworkLoader &&
          recipe == other.recipe &&
          bundle == other.bundle;

  @override
  int get hashCode => Object.hash(recipe, bundle);

  @override
  String toString() => 'AvatarArtworkLoader($recipe)';
}
