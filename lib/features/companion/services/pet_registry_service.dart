import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/pet_profile.dart';
import '../domain/pet_type.dart';

/// Service responsible for discovering, loading, and managing pet companion profiles.
/// Handles runtime registration of new pet types from asset metadata and user preferences.
class PetRegistryService {
  static const String _manifestPath = 'assets/animations/pets/pets.json';
  final Map<String, PetProfile> _profiles = {};
  String? _activePetId;

  /// Returns all registered pet profiles.
  Map<String, PetProfile> get profiles => Map.unmodifiable(_profiles);

  /// Returns the currently active pet profile, or null if none selected.
  PetProfile? get activeProfile =>
      _activePetId != null ? _profiles[_activePetId] : null;

  /// Returns the ID of the active pet.
  String? get activePetId => _activePetId;

  /// Registers a pet profile manually (for programmatic addition).
  void registerProfile(PetProfile profile) {
    _profiles[profile.id] = profile;
  }

  /// Sets the active pet by ID. Returns true if the profile exists.
  bool setActivePet(String petId) {
    if (!_profiles.containsKey(petId)) return false;
    _activePetId = petId;
    return true;
  }

  /// Loads pet metadata from the central manifest file.
  /// Populates the registry with profiles derived from manifest entries.
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

      // Auto-select first available pet if none active
      if (_activePetId == null && _profiles.isNotEmpty) {
        _activePetId = _profiles.keys.first;
      }
    } on Exception {
      // Fallback: register default presets if manifest is unavailable
      _registerDefaultPresets();
    }
  }

  /// Discovers pets from the legacy asset structure.
  /// Scans known paths and registers profiles for found sprite sheets.
  Future<void> discoverFromLegacyAssets() async {
    _registerDefaultPresets();

    // Additional legacy paths can be scanned here
    const legacyPaths = [
      'assets/animations/cats/cat_1/',
      'assets/animations/cats/cat_2/',
      'assets/animations/cats/cat_3/',
      'assets/animations/cats/cat_4/',
      'assets/animations/cats/cat_5/',
      'assets/animations/cats/cat_6/',
      'assets/animations/cats/cat_50/',
    ];

    for (final path in legacyPaths) {
      final profile = _tryCreateLegacyProfile(path);
      if (profile != null && !_profiles.containsKey(profile.id)) {
        _profiles[profile.id] = profile;
      }
    }
  }

  /// Unregisters a pet profile by ID. Cannot remove the active pet.
  bool unregisterProfile(String petId) {
    if (petId == _activePetId) return false;
    return _profiles.remove(petId) != null;
  }

  /// Gets a profile by ID, or null if not found.
  PetProfile? getProfile(String petId) => _profiles[petId];

  /// Gets all profiles for a specific species.
  List<PetProfile> getProfilesBySpecies(PetSpecies species) {
    return _profiles.values.where((p) => p.species == species).toList();
  }

  /// Gets all enabled profiles.
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
    registerProfile(PetProfile.goldenDog);
  }
}
