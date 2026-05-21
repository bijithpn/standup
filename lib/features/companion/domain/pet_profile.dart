import 'package:flutter/material.dart';
import 'pet_type.dart';
import 'pet_personality.dart';
import 'pet_mood.dart';

/// Complete configuration for a pet companion instance.
class PetProfile {
  final String id;
  final String name;
  final PetSpecies species;
  final PetVariant variant;
  final PetPersonality personality;
  final PetMood? initialMood;
  final Color primaryColor;
  final Color secondaryColor;
  final double baseScale;
  final double movementSpeed;
  final bool isEnabled;

  const PetProfile({
    required this.id,
    required this.name,
    required this.species,
    required this.variant,
    this.personality = const PetPersonality(),
    this.initialMood,
    this.primaryColor = Colors.orange,
    this.secondaryColor = Colors.brown,
    this.baseScale = 1.0,
    this.movementSpeed = 1.0,
    this.isEnabled = true,
  });

  /// Preset: Classic orange cat
  static const orangeCat = PetProfile(
    id: 'orange_cat_01',
    name: 'Ginger',
    species: PetSpecies.cat,
    variant: PetVariant(
      id: 'orange_cat',
      name: 'Orange Cat',
      assetPath: 'assets/animations/cats/orange_cat/sprite_sheet.png',
    ),
    personality: PetPersonality.lazy,
    initialMood: PetMood.relaxed,
    primaryColor: Color(0xFFFF9800),
    secondaryColor: Color(0xFF795548),
  );

  /// Preset: Friendly golden dog
  static const goldenDog = PetProfile(
    id: 'golden_dog_01',
    name: 'Goldie',
    species: PetSpecies.dog,
    variant: PetVariant(
      id: 'goldie',
      name: 'Golden Retriever',
      assetPath: 'assets/animations/dogs/goldie/goldie_v02.png',
    ),
    personality: PetPersonality.friendly,
    initialMood: PetMood.happy,
    primaryColor: Color(0xFFFFD54F),
    secondaryColor: Color(0xFFFF8F00),
    movementSpeed: 1.2,
  );

  PetProfile copyWith({
    String? id,
    String? name,
    PetSpecies? species,
    PetVariant? variant,
    PetPersonality? personality,
    PetMood? initialMood,
    Color? primaryColor,
    Color? secondaryColor,
    double? baseScale,
    double? movementSpeed,
    bool? isEnabled,
  }) {
    return PetProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      variant: variant ?? this.variant,
      personality: personality ?? this.personality,
      initialMood: initialMood ?? this.initialMood,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      baseScale: baseScale ?? this.baseScale,
      movementSpeed: movementSpeed ?? this.movementSpeed,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'species': species.name,
      'variant': variant.toMap(),
      'personality': personality.toMap(),
      'initialMood': initialMood?.name,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'baseScale': baseScale,
      'movementSpeed': movementSpeed,
      'isEnabled': isEnabled,
    };
  }

  factory PetProfile.fromMap(Map<String, dynamic> map) {
    return PetProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      species: PetSpecies.values.firstWhere(
        (e) => e.name == map['species'],
        orElse: () => PetSpecies.cat,
      ),
      variant: PetVariant.fromMap(map['variant'] as Map<String, dynamic>),
      personality: PetPersonality.fromMap(map['personality'] as Map<String, dynamic>),
      initialMood: PetMood.values.firstWhere(
        (e) => e.name == map['initialMood'],
        orElse: () => PetMood.relaxed,
      ),
      primaryColor: Color(map['primaryColor'] as int),
      secondaryColor: Color(map['secondaryColor'] as int),
      baseScale: (map['baseScale'] as num?)?.toDouble() ?? 1.0,
      movementSpeed: (map['movementSpeed'] as num?)?.toDouble() ?? 1.0,
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}
