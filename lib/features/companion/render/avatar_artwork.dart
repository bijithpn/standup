import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics_compat.dart'
    show RenderingStrategy;

import 'package:breakmate/features/companion/domain/avatar_breed.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_loader.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';

/// Builds the render recipe for a definition; the default palette is skipped so the authored colors stay untouched.
AvatarArtworkRecipe avatarRecipeFor(
  AvatarDefinition definition, {
  bool transparentBackdrop = true,
  bool applyPalette = true,
  double paletteStrength = 0.85,
}) {
  final breedId = definition.breed;
  final breed = breedId == null
      ? null
      : AvatarBreed.find(definition.species, breedId);

  final isDefaultPalette =
      definition.palette == AvatarPalette.defaultPalette ||
      definition.palette.name == 'default';
  final palette = !applyPalette || isDefaultPalette ? null : definition.palette;

  return AvatarArtworkRecipe(
    assetKey: breed?.svgAssetPath ?? definition.species.svgAssetPath,
    transparentBackdrop: transparentBackdrop,
    palette: palette,
    paletteStrength: paletteStrength,
  );
}

/// Displays a compiled avatar SVG through AvatarArtworkLoader, so heavy SVG prep runs off the UI thread.
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

      renderingStrategy: RenderingStrategy.raster,
      placeholderBuilder: (_) =>
          placeholder ?? SizedBox(width: width, height: height),
    );
  }
}
