import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics_compat.dart' show RenderingStrategy;

import 'package:breakmate/features/companion/domain/avatar_breed.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_loader.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';

/// Builds the recipe that draws [definition].
///
/// The breed artwork wins when the definition names one, because a breed is a
/// finished illustration rather than a variation applied to the species.
AvatarArtworkRecipe avatarRecipeFor(
  AvatarDefinition definition, {
  bool transparentBackdrop = true,
  bool applyPalette = true,
  double paletteStrength = 0.85,
}) {
  final breedId = definition.breed;
  final breed =
      breedId == null ? null : AvatarBreed.find(definition.species, breedId);

  // Both base species snapshots and breed snapshots carry authored colouring.
  // Only recolour when the user has explicitly moved off the default palette.
  final isDefaultPalette =
      definition.palette == AvatarPalette.defaultPalette ||
      definition.palette.name == 'default';
  final palette = !applyPalette || isDefaultPalette
      ? null
      : definition.palette;

  return AvatarArtworkRecipe(
    assetKey: breed?.svgAssetPath ?? definition.species.svgAssetPath,
    transparentBackdrop: transparentBackdrop,
    palette: palette,
    paletteStrength: paletteStrength,
  );
}

/// Draws one piece of avatar artwork.
///
/// Prefer this over `SvgPicture.asset` anywhere a pet is shown: it strips the
/// opaque plate the snapshots ship with, applies the definition's palette, and
/// keeps the raster between frames instead of replaying the paths.
class AvatarArtwork extends StatelessWidget {
  const AvatarArtwork({
    super.key,
    required this.recipe,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.placeholder,
    this.semanticsLabel,
  });

  /// Convenience constructor for the common case of drawing a definition.
  AvatarArtwork.definition(
    AvatarDefinition definition, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
    Widget? placeholder,
    String? semanticsLabel,
    bool transparentBackdrop = true,
    bool applyPalette = true,
  }) : this(
          key: key,
          recipe: avatarRecipeFor(
            definition,
            transparentBackdrop: transparentBackdrop,
            applyPalette: applyPalette,
          ),
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          placeholder: placeholder,
          semanticsLabel: semanticsLabel ?? definition.species.displayName,
        );

  final AvatarArtworkRecipe recipe;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  /// Shown while the artwork compiles. Defaults to nothing — a spinner over a
  /// transparent desktop overlay draws more attention than the gap it fills.
  final Widget? placeholder;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture(
      AvatarArtworkLoader(recipe),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: semanticsLabel == null,
      // The artwork is complex and redrawn every frame by the pet's motion, so
      // keeping a raster is dramatically cheaper than replaying its paths.
      renderingStrategy: RenderingStrategy.raster,
      placeholderBuilder: (_) =>
          placeholder ?? SizedBox(width: width, height: height),
    );
  }
}
