import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/pet_profile.dart';
import '../domain/pet_type.dart';

class PetRegistryService {
  static const String _manifestPath = 'assets/animations/pets/pets.json';
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
    try {
      final manifestString = await rootBundle.loadString(_manifestPath);
      final List<dynamic> manifestData =
          jsonDecode(manifestString) as List<dynamic>;

      for (final entry in manifestData) {
        final map = entry as Map<String, dynamic>;
        final profile = _parseManifestEntry(map);
        if (profile != null) {
          _profiles[profile.id] = profile;
        }
      }

      if (_activePetId == null && _profiles.isNotEmpty) {
        _activePetId = _profiles.keys.first;
      }
    } on Exception {
      // Fallback: register default presets if manifest is unavailable
      _registerDefaultPresets();
    }
  }

  Future<void> discoverFromLegacyAssets() async {
    _registerDefaultPresets();

    const legacyPaths = [
      'assets/animations/cats/cat_1/',
      'assets/animations/cats/cat_2/',
      'assets/animations/cats/cat_3/',
      'assets/animations/cats/cat_4/',
      'assets/animations/cats/cat_5/',
      'assets/animations/cats/cat_6/',
    ];

    for (final path in legacyPaths) {
      final profile = _tryCreateLegacyProfile(path);
      if (profile != null && !_profiles.containsKey(profile.id)) {
        _profiles[profile.id] = profile;
      }
    }
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

  PetProfile? _parseManifestEntry(Map<String, dynamic> map) {
    try {
      final species = PetSpecies.values.firstWhere(
        (e) => e.name == map['species'],
        orElse: () => PetSpecies.cat,
      );

      final variant = PetVariant(
        id: map['variantId'] as String? ?? map['id'] as String,
        name: map['name'] as String? ?? 'Unknown',
        assetPath: map['assetPath'] as String,
        isSpriteSheet: map['isSpriteSheet'] as bool? ?? true,
        rowCount: map['rowCount'] as int?,
        frameCount: map['frameCount'] as int?,
      );

      return PetProfile(
        id: map['id'] as String,
        name: map['name'] as String? ?? variant.name,
        species: species,
        variant: variant,
        baseScale: (map['baseScale'] as num?)?.toDouble() ?? 1.0,
        movementSpeed: (map['movementSpeed'] as num?)?.toDouble() ?? 1.0,
        isEnabled: map['isEnabled'] as bool? ?? true,
      );
    } on Exception {
      return null;
    }
  }

  PetProfile? _tryCreateLegacyProfile(String directoryPath) {
    final dirName = directoryPath.split('/').where((s) => s.isNotEmpty).last;
    final species = directoryPath.contains('/dogs/')
        ? PetSpecies.dog
        : PetSpecies.cat;

    return PetProfile(
      id: 'legacy_$dirName',
      name: dirName
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '),
      species: species,
      variant: PetVariant(id: dirName, name: dirName, assetPath: directoryPath),
    );
  }

  void _registerDefaultPresets() {
    registerProfile(PetProfile.orangeCat);
  }
}
