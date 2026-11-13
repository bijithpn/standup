import 'package:breakmate/features/companion/domain/avatar_palette.dart';

/// Value-equal key describing how to prepare an avatar SVG; doubles as the cache key.
class AvatarArtworkRecipe {
  const AvatarArtworkRecipe({
    required this.assetKey,
    this.transparentBackdrop = true,
    this.palette,
    this.paletteStrength = 1.0,
    this.centerContent = true,
  });

  final String assetKey;

  final bool transparentBackdrop;

  final AvatarPalette? palette;

  final double paletteStrength;

  final bool centerContent;

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
