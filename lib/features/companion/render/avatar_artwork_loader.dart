import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_graphics/vector_graphics.dart';

import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_worker.dart';

/// Loads avatar artwork as compiled vector graphics, prepared on the render
/// isolate and cached by recipe.
///
/// Two caches sit in front of the isolate. This one holds the compiled bytes,
/// so a recipe is only ever prepared once per run; `vector_graphics` holds the
/// decoded picture behind [cacheKey], so it is only ever decoded once. What is
/// left at paint time is a raster blit.
@immutable
class AvatarArtworkLoader extends BytesLoader {
  const AvatarArtworkLoader(this.recipe, {this.bundle});

  final AvatarArtworkRecipe recipe;

  /// Overridden in tests; production reads from the app bundle.
  final AssetBundle? bundle;

  /// Compiled buffers, most recently used last.
  static final LinkedHashMap<AvatarArtworkRecipe, Uint8List> _compiled =
      LinkedHashMap<AvatarArtworkRecipe, Uint8List>();

  /// In-flight compiles, so N widgets asking for one recipe cost one compile.
  static final Map<AvatarArtworkRecipe, Future<Uint8List>> _inFlight =
      <AvatarArtworkRecipe, Future<Uint8List>>{};

  /// Roughly every breed and species at once, which is the worst case the
  /// customizer can ask for.
  static const int _maxCachedRecipes = 200;

  @override
  Future<ByteData> loadBytes(BuildContext? context) async {
    final bytes = await _resolve(context);
    return ByteData.sublistView(bytes);
  }

  Future<Uint8List> _resolve(BuildContext? context) {
    final cached = _compiled.remove(recipe);
    if (cached != null) {
      _compiled[recipe] = cached; // Re-insert to mark as most recently used.
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

  /// Prepares [recipes] ahead of the frame that needs them.
  ///
  /// Used to warm the companion's own artwork while a window is still opening,
  /// so the pet is never a blank box on first paint.
  static Future<void> precache(
    Iterable<AvatarArtworkRecipe> recipes, {
    AssetBundle? bundle,
  }) async {
    for (final recipe in recipes) {
      try {
        await AvatarArtworkLoader(recipe, bundle: bundle)._resolve(null);
      } catch (_) {
        // A warm-up failure is not worth surfacing; the real load will retry
        // and can show its own error state.
      }
    }
  }

  /// Drops every cached buffer. Call when artwork on disk may have changed.
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
