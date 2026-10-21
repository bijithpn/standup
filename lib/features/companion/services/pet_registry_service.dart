import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_personality.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';

class PetRegistryService {
  final Map<String, PetProfile> _profiles = {};
  String? _activePetId;

  Map<String, PetProfile> get profiles => Map.unmodifiable(_profiles);

  PetProfile? get activeProfile =>
      _activePetId != null ? _profiles[_activePetId] : null;

  String? get activePetId => _activePetId;

  void registerProfile(PetProfile profile) {
    _profiles[profile.id] = profile;
  }

  bool setActivePet(String petId) {
    if (!_profiles.containsKey(petId)) return false;
    _activePetId = petId;
    return true;
  }

  Future<void> loadFromManifest() async {
    _registerDefaultPresets();
    if (_activePetId == null && _profiles.isNotEmpty) {
      _activePetId = _profiles.keys.first;
    }
  }

  Future<void> discoverFromLegacyAssets() async {
    _registerDefaultPresets();
  }

  bool unregisterProfile(String petId) {
    if (petId == _activePetId) return false;
    return _profiles.remove(petId) != null;
  }

  PetProfile? getProfile(String petId) => _profiles[petId];

  List<PetProfile> getProfilesBySpecies(PetSpecies species) {
    return _profiles.values.where((p) => p.species == species).toList();
  }

  List<PetProfile> getEnabledProfiles() {
    return _profiles.values.where((p) => p.isEnabled).toList();
  }

  void _registerDefaultPresets() {
    for (final theme in PetTheme.themes) {
      final species = theme.avatarDefinition?.species ?? AvatarSpecies.cat;
      final profile = PetProfile(
        id: theme.id,
        name: theme.name,
        species: theme.species,
        variant: PetVariant(
          id: theme.id,
          name: theme.name,
          assetPath: theme.basePath,
          isSpriteSheet: false,
        ),
        personality: PetPersonality.energetic,
        theme: theme,
        avatarDefinition: theme.avatarDefinition ?? AvatarDefinition.fromSpecies(species),
      );
      registerProfile(profile);
    }
  }
}
