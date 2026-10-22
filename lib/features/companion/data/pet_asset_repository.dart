import 'package:breakmate/features/companion/data/pet_configuration.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';

class PetAsset {
  final String id;
  final AvatarDefinition definition;
  final PetConfiguration defaultConfiguration;

  const PetAsset({
    required this.id,
    required this.definition,
    required this.defaultConfiguration,
  });
}

/// Adapter repository for loading and caching pet assets and configurations
class PetAssetRepository {
  final Map<String, PetAsset> _cache = {};

  Future<PetAsset> loadPet(String id) async {
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }

    final species = AvatarSpecies.tryParse(id) ?? AvatarSpecies.cat;
    final definition = AvatarDefinition.fromSpecies(species);
    final configuration = PetConfiguration(
      petId: id,
      species: species.name,
      materials: {
        'primary': definition.palette.primary,
        'secondary': definition.palette.secondary,
        'accent': definition.palette.accent,
        'snout': definition.palette.snout,
        'ears': definition.palette.ears,
        'eyes': definition.palette.eyes,
      },
    );

    final asset = PetAsset(
      id: id,
      definition: definition,
      defaultConfiguration: configuration,
    );

    _cache[id] = asset;
    return asset;
  }
}
