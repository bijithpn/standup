import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';

/// Builds the profile a companion would run with for [theme].
PetProfile profileFromTheme(PetTheme theme) {
  final variant = PetVariant(
    id: theme.id,
    name: theme.name,
    assetPath: theme.basePath,
    isSpriteSheet: theme.type == PetType.composite,
  );
  return PetProfile(
    id: theme.id,
    name: theme.name,
    species: theme.species,
    variant: variant,
    theme: theme,
    avatarDefinition: theme.avatarDefinition,
  );
}
