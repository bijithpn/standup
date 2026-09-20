import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';

enum PetType { composite, separate, avatar, blobatar }

class PetTheme {
  final String id;
  final String name;
  final String basePath;
  final PetType type;
  final int spriteSize;
  final Map<PetAnimationState, dynamic> animations;
  final PetSpecies species;
  final int requiredConsistencyDays;
  final AvatarDefinition? avatarDefinition;

  const PetTheme({
    required this.id,
    required this.name,
    required this.basePath,
    required this.type,
    required this.spriteSize,
    required this.animations,
    this.species = PetSpecies.cat,
    this.requiredConsistencyDays = 0,
    this.avatarDefinition,
  });

  factory PetTheme.avatar({
    String? id,
    String? name,
    AvatarDefinition? definition,
    AvatarSpecies? species,
    int requiredConsistencyDays = 0,
    PetSpecies petSpecies = PetSpecies.cat,
  }) {
    final def = definition ??
        (species != null
            ? AvatarDefinition.fromSpecies(species)
            : AvatarDefinition.fromSpecies(AvatarSpecies.cat));
    return PetTheme(
      id: id ?? 'avatar_${def.species.name}',
      name: name ?? '${def.species.displayName} (3D)',
      basePath: def.species.svgAssetPath,
      type: PetType.avatar,
      spriteSize: 128,
      animations: const {},
      species: petSpecies,
      requiredConsistencyDays: requiredConsistencyDays,
      avatarDefinition: def,
    );
  }

  factory PetTheme.blobatar({
    String? id,
    String? name,
    int requiredConsistencyDays = 0,
  }) {
    return PetTheme(
      id: id ?? 'blobatar',
      name: name ?? 'Blobatar (Dynamic)',
      basePath: AvatarSpecies.cat.svgAssetPath,
      type: PetType.blobatar,
      spriteSize: 160,
      animations: const {},
      species: PetSpecies.cat,
      requiredConsistencyDays: requiredConsistencyDays,
      avatarDefinition: AvatarDefinition.fromSpecies(AvatarSpecies.cat),
    );
  }

  bool get isAvatar => type == PetType.avatar || avatarDefinition != null;
  bool get isBlobatar => type == PetType.blobatar || id == 'blobatar';

  static const String keyGreyCat = 'grey_cat';
  static const String keyOrangeCat = 'orange_cat';
  static const String keyBlackCat = 'black_cat';
  static const String keyCat1 = 'cat_1';
  static const String keyCat2 = 'cat_2';
  static const String keyCat3 = 'cat_3';
  static const String keyCat4 = 'cat_4';
  static const String keyCat5 = 'cat_5';
  static const String keyCat6 = 'cat_6';
  static const String keyCollie = 'collie';
  static const String keyCorgi = 'corgi';
  static const String keyDalmatian = 'dalmatian';
  static const String keyHusky = 'husky';
  static const String keyLabrador = 'labrador';
  static const String keyFlamingo = 'flamingo';

  static final List<PetTheme> themes = [
    // Dynamic Blobatar Companion (Generative from Name)
    PetTheme.blobatar(),

    // Primary 3D Avatars (All 33 OneWorks Species)
    PetTheme.avatar(
      id: 'avatar_cat',
      name: 'Cat',
      species: AvatarSpecies.cat,
      petSpecies: PetSpecies.cat,
    ),
    PetTheme.avatar(
      id: 'avatar_dog',
      name: 'Dog',
      species: AvatarSpecies.dog,
      petSpecies: PetSpecies.dog,
      requiredConsistencyDays: 3,
    ),
    PetTheme.avatar(
      id: 'avatar_fox',
      name: 'Fox',
      species: AvatarSpecies.fox,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 5,
    ),
    PetTheme.avatar(
      id: 'avatar_bear',
      name: 'Bear',
      species: AvatarSpecies.bear,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 7,
    ),
    PetTheme.avatar(
      id: 'avatar_capybara',
      name: 'Capybara',
      species: AvatarSpecies.capybara,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 10,
    ),
    PetTheme.avatar(
      id: 'avatar_panda',
      name: 'Panda',
      species: AvatarSpecies.panda,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 12,
    ),
    PetTheme.avatar(
      id: 'avatar_penguin',
      name: 'Penguin',
      species: AvatarSpecies.penguin,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 14,
    ),
    PetTheme.avatar(
      id: 'avatar_rabbit',
      name: 'Rabbit',
      species: AvatarSpecies.rabbit,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 15,
    ),
    PetTheme.avatar(
      id: 'avatar_owl',
      name: 'Owl',
      species: AvatarSpecies.owl,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 18,
    ),
    PetTheme.avatar(
      id: 'avatar_lion',
      name: 'Lion',
      species: AvatarSpecies.lion,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 21,
    ),
    PetTheme.avatar(
      id: 'avatar_otter',
      name: 'Otter',
      species: AvatarSpecies.otter,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 25,
    ),
    PetTheme.avatar(
      id: 'avatar_redPanda',
      name: 'Red Panda',
      species: AvatarSpecies.redPanda,
      petSpecies: PetSpecies.cat,
      requiredConsistencyDays: 30,
    ),
    // All remaining OneWorks species
    for (final s in AvatarSpecies.values)
      if (![
        AvatarSpecies.cat,
        AvatarSpecies.dog,
        AvatarSpecies.fox,
        AvatarSpecies.bear,
        AvatarSpecies.capybara,
        AvatarSpecies.panda,
        AvatarSpecies.penguin,
        AvatarSpecies.rabbit,
        AvatarSpecies.owl,
        AvatarSpecies.lion,
        AvatarSpecies.otter,
        AvatarSpecies.redPanda,
      ].contains(s))
        PetTheme.avatar(
          id: 'avatar_${s.name}',
          name: s.displayName,
          species: s,
          petSpecies: PetSpecies.cat,
        ),
  ];

  static PetTheme getTheme(String id) {
    final theme = themes.cast<PetTheme?>().firstWhere(
      (theme) => theme?.id == id,
      orElse: () => null,
    );
    if (theme != null) return theme;

    if (id.startsWith('avatar_')) {
      final speciesName = id.substring('avatar_'.length);
      final species = AvatarSpecies.tryParse(speciesName);
      if (species != null) {
        return PetTheme.avatar(
          id: id,
          name: '${species.displayName} (3D)',
          definition: AvatarDefinition.fromSpecies(species),
        );
      }
    }

    // Map legacy sprite IDs to appropriate 3D Avatar species
    if (id.contains('cat')) {
      return getTheme('avatar_cat');
    } else if (id.contains('dog') ||
        id == keyCollie ||
        id == keyCorgi ||
        id == keyDalmatian ||
        id == keyHusky ||
        id == keyLabrador) {
      return getTheme('avatar_dog');
    } else if (id == keyFlamingo) {
      return getTheme('avatar_duck');
    }

    return themes.first;
  }
}

class SeparateAnimationConfig {
  final String fileName;
  final int frameCount;
  final double stepTime;
  final bool loop;

  const SeparateAnimationConfig({
    required this.fileName,
    required this.frameCount,
    this.stepTime = 0.1,
    this.loop = true,
  });
}
