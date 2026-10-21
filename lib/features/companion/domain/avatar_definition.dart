import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:flutter/foundation.dart';

class AvatarDefinition {
  final int schemaVersion;
  final AvatarSpecies species;
  final String? breed;
  final AvatarPalette palette;
  final String pattern;
  final String seed;
  final double scale;
  final double yaw;
  final Map<String, dynamic> parts;

  const AvatarDefinition({
    this.schemaVersion = 1,
    required this.species,
    this.breed,
    required this.palette,
    this.pattern = 'solid',
    required this.seed,
    this.scale = 1.0,
    this.yaw = 0.0,
    this.parts = const {},
  });

  factory AvatarDefinition.fromSpecies(
    AvatarSpecies species, {
    String? breed,
    AvatarPalette? palette,
    String? pattern,
    String? seed,
    double scale = 1.0,
    double yaw = 0.0,
    Map<String, dynamic>? parts,
  }) {
    final effectiveSeed = seed ?? 'species-${species.name}';
    return AvatarDefinition(
      schemaVersion: 1,
      species: species,
      breed: breed,
      palette: palette ?? AvatarPalette.defaultPalette,
      pattern: pattern ?? 'solid',
      seed: effectiveSeed,
      scale: scale,
      yaw: yaw,
      parts: parts ?? Map<String, dynamic>.from(species.defaultPartConfigurations),
    );
  }

  factory AvatarDefinition.fromSeed(String seed, {AvatarSpecies? species}) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < seed.length; i++) {
      hash ^= seed.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    final selectedSpecies = species ??
        AvatarSpecies.values[hash.abs() % AvatarSpecies.values.length];

    final presetList = AvatarPalette.presets.values.toList();
    final paletteIndex = (hash.abs() >> 4) % presetList.length;
    final selectedPalette = presetList[paletteIndex];

    const patterns = ['solid', 'stripes', 'spots', 'patches', 'gradient'];
    final patternIndex = (hash.abs() >> 8) % patterns.length;
    final selectedPattern = patterns[patternIndex];

    return AvatarDefinition(
      schemaVersion: 1,
      species: selectedSpecies,
      palette: selectedPalette,
      pattern: selectedPattern,
      seed: seed,
      scale: 1.0,
      yaw: 0.0,
      parts: Map<String, dynamic>.from(selectedSpecies.defaultPartConfigurations),
    );
  }

  AvatarDefinition copyWith({
    int? schemaVersion,
    AvatarSpecies? species,
    String? breed,
    AvatarPalette? palette,
    String? pattern,
    String? seed,
    double? scale,
    double? yaw,
    Map<String, dynamic>? parts,
  }) {
    return AvatarDefinition(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      palette: palette ?? this.palette,
      pattern: pattern ?? this.pattern,
      seed: seed ?? this.seed,
      scale: scale ?? this.scale,
      yaw: yaw ?? this.yaw,
      parts: parts ?? this.parts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'species': species.name,
      if (breed != null) 'breed': breed,
      'palette': palette.toJson(),
      'pattern': pattern,
      'seed': seed,
      'scale': scale,
      'yaw': yaw,
      'parts': parts,
    };
  }

  factory AvatarDefinition.fromJson(Map<String, dynamic> json) {
    final speciesStr = json['species'] as String? ?? 'cat';
    final parsedSpecies = AvatarSpecies.tryParse(speciesStr) ?? AvatarSpecies.cat;
    final parsedBreed = json['breed'] as String?;

    AvatarPalette parsedPalette;
    if (json['palette'] is Map<String, dynamic>) {
      parsedPalette = AvatarPalette.fromJson(json['palette'] as Map<String, dynamic>);
    } else if (json['palette'] is String) {
      parsedPalette = AvatarPalette.fromName(json['palette'] as String);
    } else {
      parsedPalette = AvatarPalette.defaultPalette;
    }

    return AvatarDefinition(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      species: parsedSpecies,
      breed: parsedBreed,
      palette: parsedPalette,
      pattern: json['pattern'] as String? ?? 'solid',
      seed: json['seed'] as String? ?? 'default',
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      yaw: (json['yaw'] as num?)?.toDouble() ?? 0.0,
      parts: json['parts'] is Map
          ? Map<String, dynamic>.from(json['parts'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarDefinition &&
          runtimeType == other.runtimeType &&
          schemaVersion == other.schemaVersion &&
          species == other.species &&
          palette == other.palette &&
          pattern == other.pattern &&
          seed == other.seed &&
          scale == other.scale &&
          yaw == other.yaw &&
          mapEquals(parts, other.parts);

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        species,
        palette,
        pattern,
        seed,
        scale,
        yaw,
        Object.hashAll(parts.entries),
      );

  @override
  String toString() =>
      'AvatarDefinition(species: ${species.name}, palette: ${palette.name}, seed: $seed)';
}
