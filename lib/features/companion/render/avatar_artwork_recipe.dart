import 'package:breakmate/features/companion/domain/avatar_palette.dart';

/// Everything the background isolate needs to turn one raw avatar SVG into a
/// compiled vector-graphics buffer.
///
/// Deliberately free of any Flutter binding so the whole object can be handed
/// across an isolate port. [AvatarPalette] qualifies for the same reason — it
/// is a plain value type with no imports of its own.
class AvatarArtworkRecipe {
  const AvatarArtworkRecipe({
    required this.assetKey,
    this.transparentBackdrop = true,
    this.palette,
    this.paletteStrength = 1.0,
    this.centerContent = true,
  });

  /// Bundle key of the source artwork, e.g. `assets/avatars/species/cat.svg`.
  final String assetKey;

  /// Drops the full-bleed rounded plate every OneWorks snapshot is exported
  /// with. Without this the pet arrives sitting on an opaque card, which is
  /// wrong everywhere we composite it over the desktop.
  final bool transparentBackdrop;

  /// Recolours the artwork by role. Null keeps the authored colours.
  final AvatarPalette? palette;

  /// How far the recolour pulls toward [palette], 0..1. Below 1 the artwork
  /// keeps some of its own character.
  final double paletteStrength;

  /// Re-frames the artwork on a square centred over what is actually drawn.
  ///
  /// The snapshots place the pet with a transform rather than centring it, so
  /// without this each species sits off to one side by its own amount and
  /// renders at its own apparent size.
  final bool centerContent;

  /// Stable identity — this doubles as the render cache key, so two recipes
  /// that would compile to the same bytes must compare equal.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarArtworkRecipe &&
          assetKey == other.assetKey &&
          transparentBackdrop == other.transparentBackdrop &&
          palette == other.palette &&
          paletteStrength == other.paletteStrength &&
          centerContent == other.centerContent;

  @override
  int get hashCode => Object.hash(
    assetKey,
    transparentBackdrop,
    palette,
    paletteStrength,
    centerContent,
  );

  @override
  String toString() =>
      'AvatarArtworkRecipe($assetKey, '
      'transparent: $transparentBackdrop, palette: ${palette?.name})';
}
