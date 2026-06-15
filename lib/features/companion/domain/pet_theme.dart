import 'package:breakmate/features/companion/domain/animation_row_config.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';

enum PetType { composite, separate }

class PetTheme {
  final String id;
  final String name;
  final String basePath;
  final PetType type;
  final int spriteSize;
  final Map<PetAnimationState, dynamic> animations;
  final PetSpecies species;
  final int requiredConsistencyDays;

  const PetTheme({
    required this.id,
    required this.name,
    required this.basePath,
    required this.type,
    required this.spriteSize,
    required this.animations,
    this.species = PetSpecies.cat,
    this.requiredConsistencyDays = 0,
  });

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

  static const Map<PetAnimationState, SeparateAnimationConfig>
  _petPackAnimations = {
    PetAnimationState.sleep: SeparateAnimationConfig(
      fileName: 'sleep_1.png',
      frameCount: 1,
      stepTime: 0.6,
    ),
    PetAnimationState.idle: SeparateAnimationConfig(
      fileName: 'idle.png',
      frameCount: 10,
      stepTime: 0.18,
    ),
    PetAnimationState.typing: SeparateAnimationConfig(
      fileName: 'sitting.png',
      frameCount: 1,
      stepTime: 0.5,
    ),
    PetAnimationState.walkSide: SeparateAnimationConfig(
      fileName: 'walk.png',
      frameCount: 8,
      stepTime: 0.12,
    ),
    PetAnimationState.run: SeparateAnimationConfig(
      fileName: 'run.png',
      frameCount: 8,
      stepTime: 0.08,
    ),
    PetAnimationState.excited: SeparateAnimationConfig(
      fileName: 'run.png',
      frameCount: 8,
      stepTime: 0.1,
    ),
    PetAnimationState.sad: SeparateAnimationConfig(
      fileName: 'laying.png',
      frameCount: 8,
      stepTime: 0.18,
    ),
    PetAnimationState.stretch: SeparateAnimationConfig(
      fileName: 'stretching.png',
      frameCount: 13,
      stepTime: 0.15,
      loop: false,
    ),
    PetAnimationState.breakMode: SeparateAnimationConfig(
      fileName: 'stretching.png',
      frameCount: 13,
      stepTime: 0.09,
    ),
    PetAnimationState.focusMode: SeparateAnimationConfig(
      fileName: 'sitting.png',
      frameCount: 1,
      stepTime: 0.5,
    ),
    PetAnimationState.angry: SeparateAnimationConfig(
      fileName: 'itch.png',
      frameCount: 2,
      stepTime: 0.16,
      loop: false,
    ),
    PetAnimationState.notification: SeparateAnimationConfig(
      fileName: 'meow.png',
      frameCount: 4,
      stepTime: 0.14,
      loop: false,
    ),
    PetAnimationState.celebrate: SeparateAnimationConfig(
      fileName: 'stretching.png',
      frameCount: 13,
      stepTime: 0.08,
      loop: false,
    ),
    PetAnimationState.lick1: SeparateAnimationConfig(
      fileName: 'lick_1.png',
      frameCount: 5,
      stepTime: 0.16,
      loop: false,
    ),
    PetAnimationState.lick2: SeparateAnimationConfig(
      fileName: 'lick_2.png',
      frameCount: 5,
      stepTime: 0.16,
      loop: false,
    ),
    PetAnimationState.chasing: SeparateAnimationConfig(
      fileName: 'run.png',
      frameCount: 8,
      stepTime: 0.08,
    ),
    PetAnimationState.fetching: SeparateAnimationConfig(
      fileName: 'walk.png',
      frameCount: 8,
      stepTime: 0.12,
    ),
  };

  static const Map<PetAnimationState, SeparateAnimationConfig>
  _petPackAnimationsNoItch = {
    PetAnimationState.sleep: SeparateAnimationConfig(
      fileName: 'sleep_1.png',
      frameCount: 1,
      stepTime: 0.6,
    ),
    PetAnimationState.idle: SeparateAnimationConfig(
      fileName: 'idle.png',
      frameCount: 10,
      stepTime: 0.18,
    ),
    PetAnimationState.typing: SeparateAnimationConfig(
      fileName: 'sitting.png',
      frameCount: 1,
      stepTime: 0.5,
    ),
    PetAnimationState.walkSide: SeparateAnimationConfig(
      fileName: 'walk.png',
      frameCount: 8,
      stepTime: 0.12,
    ),
    PetAnimationState.run: SeparateAnimationConfig(
      fileName: 'run.png',
      frameCount: 8,
      stepTime: 0.08,
    ),
    PetAnimationState.excited: SeparateAnimationConfig(
      fileName: 'run.png',
      frameCount: 8,
      stepTime: 0.1,
    ),
    PetAnimationState.sad: SeparateAnimationConfig(
      fileName: 'laying.png',
      frameCount: 8,
      stepTime: 0.18,
    ),
    PetAnimationState.stretch: SeparateAnimationConfig(
      fileName: 'stretching.png',
      frameCount: 13,
      stepTime: 0.15,
      loop: false,
    ),
    PetAnimationState.breakMode: SeparateAnimationConfig(
      fileName: 'stretching.png',
      frameCount: 13,
      stepTime: 0.09,
    ),
    PetAnimationState.focusMode: SeparateAnimationConfig(
      fileName: 'sitting.png',
      frameCount: 1,
      stepTime: 0.5,
    ),
    PetAnimationState.angry: SeparateAnimationConfig(
      fileName: 'meow.png',
      frameCount: 4,
      stepTime: 0.16,
      loop: false,
    ),
    PetAnimationState.notification: SeparateAnimationConfig(
      fileName: 'meow.png',
      frameCount: 4,
      stepTime: 0.14,
      loop: false,
    ),
    PetAnimationState.celebrate: SeparateAnimationConfig(
      fileName: 'stretching.png',
      frameCount: 13,
      stepTime: 0.08,
      loop: false,
    ),
    PetAnimationState.lick1: SeparateAnimationConfig(
      fileName: 'lick_1.png',
      frameCount: 5,
      stepTime: 0.16,
      loop: false,
    ),
    PetAnimationState.lick2: SeparateAnimationConfig(
      fileName: 'lick_2.png',
      frameCount: 5,
      stepTime: 0.16,
      loop: false,
    ),
    PetAnimationState.chasing: SeparateAnimationConfig(
      fileName: 'run.png',
      frameCount: 8,
      stepTime: 0.08,
    ),
    PetAnimationState.fetching: SeparateAnimationConfig(
      fileName: 'walk.png',
      frameCount: 8,
      stepTime: 0.12,
    ),
  };

  static const Map<PetAnimationState, AnimationRowConfig> _dogSheetAnimations =
      {
        PetAnimationState.idle: AnimationRowConfig(
          row: 0,
          frameCount: 1,
          stepTime: 1.0,
        ),
        PetAnimationState.walkSide: AnimationRowConfig(
          row: 0,
          frameCount: 8,
          stepTime: 0.15,
        ),
        PetAnimationState.run: AnimationRowConfig(
          row: 1,
          frameCount: 8,
          stepTime: 0.1,
        ),
        PetAnimationState.excited: AnimationRowConfig(
          row: 2,
          frameCount: 6,
          stepTime: 0.1,
        ),
        PetAnimationState.celebrate: AnimationRowConfig(
          row: 2,
          frameCount: 6,
          stepTime: 0.08,
        ),
        PetAnimationState.notification: AnimationRowConfig(
          row: 2,
          frameCount: 6,
          stepTime: 0.12,
          loop: false,
        ),
        PetAnimationState.sad: AnimationRowConfig(
          row: 0,
          frameCount: 8,
          stepTime: 0.4,
        ),
        PetAnimationState.stretch: AnimationRowConfig(
          row: 2,
          frameCount: 6,
          stepTime: 0.15,
          loop: false,
        ),
        PetAnimationState.breakMode: AnimationRowConfig(
          row: 2,
          frameCount: 6,
          stepTime: 0.12,
        ),
        PetAnimationState.focusMode: AnimationRowConfig(
          row: 0,
          frameCount: 8,
          stepTime: 0.25,
        ),
        PetAnimationState.angry: AnimationRowConfig(
          row: 2,
          frameCount: 6,
          stepTime: 0.12,
          loop: false,
        ),
        PetAnimationState.chasing: AnimationRowConfig(
          row: 1,
          frameCount: 8,
          stepTime: 0.1,
        ),
        PetAnimationState.fetching: AnimationRowConfig(
          row: 0,
          frameCount: 8,
          stepTime: 0.15,
        ),
      };

  static const Map<PetAnimationState, AnimationRowConfig>
  _flamingoSheetAnimations = {
    PetAnimationState.idle: AnimationRowConfig(
      row: 1,
      frameCount: 1,
      stepTime: 1.0,
    ),
    PetAnimationState.walkSide: AnimationRowConfig(
      row: 1,
      frameCount: 4,
      stepTime: 0.15,
    ),
    PetAnimationState.run: AnimationRowConfig(
      row: 1,
      frameCount: 4,
      stepTime: 0.1,
    ),
    PetAnimationState.excited: AnimationRowConfig(
      row: 0,
      frameCount: 5,
      stepTime: 0.12,
    ),
    PetAnimationState.celebrate: AnimationRowConfig(
      row: 0,
      frameCount: 5,
      stepTime: 0.1,
    ),
    PetAnimationState.notification: AnimationRowConfig(
      row: 0,
      frameCount: 5,
      stepTime: 0.15,
      loop: false,
    ),
    PetAnimationState.sad: AnimationRowConfig(
      row: 3,
      frameCount: 4,
      stepTime: 0.4,
    ),
    PetAnimationState.sleep: AnimationRowConfig(
      row: 3,
      frameCount: 4,
      stepTime: 0.4,
    ),
    PetAnimationState.stretch: AnimationRowConfig(
      row: 0,
      frameCount: 5,
      stepTime: 0.15,
      loop: false,
    ),
    PetAnimationState.breakMode: AnimationRowConfig(
      row: 0,
      frameCount: 5,
      stepTime: 0.12,
    ),
    PetAnimationState.focusMode: AnimationRowConfig(
      row: 1,
      frameCount: 1,
      stepTime: 1.0,
    ),
    PetAnimationState.angry: AnimationRowConfig(
      row: 0,
      frameCount: 5,
      stepTime: 0.12,
      loop: false,
    ),
    PetAnimationState.chasing: AnimationRowConfig(
      row: 1,
      frameCount: 4,
      stepTime: 0.1,
    ),
    PetAnimationState.fetching: AnimationRowConfig(
      row: 1,
      frameCount: 4,
      stepTime: 0.15,
    ),
  };

  static const Map<PetAnimationState, AnimationRowConfig> _petSheetAnimations =
      {
        PetAnimationState.sleep: AnimationRowConfig(
          row: 0,
          frameCount: 6,
          stepTime: 0.4,
        ),
        PetAnimationState.idle: AnimationRowConfig(
          row: 1,
          frameCount: 8,
          stepTime: 0.3,
        ),
        PetAnimationState.typing: AnimationRowConfig(
          row: 2,
          frameCount: 6,
          stepTime: 0.25,
        ),
        PetAnimationState.walkSide: AnimationRowConfig(
          row: 6,
          frameCount: 8,
          stepTime: 0.15,
        ),
        PetAnimationState.run: AnimationRowConfig(
          row: 7,
          frameCount: 8,
          stepTime: 0.1,
        ),
        PetAnimationState.excited: AnimationRowConfig(
          row: 9,
          frameCount: 6,
          stepTime: 0.12,
        ),
        PetAnimationState.sad: AnimationRowConfig(
          row: 0,
          frameCount: 6,
          stepTime: 0.4,
        ),
        PetAnimationState.stretch: AnimationRowConfig(
          row: 39,
          frameCount: 11,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.breakMode: AnimationRowConfig(
          row: 39,
          frameCount: 11,
          stepTime: 0.12,
        ),
        PetAnimationState.focusMode: AnimationRowConfig(
          row: 1,
          frameCount: 8,
          stepTime: 0.3,
        ),
        PetAnimationState.angry: AnimationRowConfig(
          row: 11,
          frameCount: 6,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.notification: AnimationRowConfig(
          row: 11,
          frameCount: 6,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.celebrate: AnimationRowConfig(
          row: 39,
          frameCount: 11,
          stepTime: 0.1,
        ),
        PetAnimationState.chasing: AnimationRowConfig(
          row: 7,
          frameCount: 8,
          stepTime: 0.08,
        ),
        PetAnimationState.fetching: AnimationRowConfig(
          row: 6,
          frameCount: 8,
          stepTime: 0.12,
        ),
      };

  static const List<PetTheme> themes = [
    PetTheme(
      id: keyGreyCat,
      name: 'Classic Grey Cat',
      basePath: 'assets/animations/cats/grey_cat/sprite_sheet.png',
      type: PetType.composite,
      spriteSize: 32,
      animations: _petSheetAnimations,
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyOrangeCat,
      name: 'Playful Orange Cat',
      basePath: 'assets/animations/cats/orange_cat/sprite_sheet.png',
      type: PetType.composite,
      spriteSize: 32,
      animations: _petSheetAnimations,
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyBlackCat,
      name: 'Sleek Black Cat',
      basePath: 'assets/animations/cats/black_cat/sprite_sheet.png',
      type: PetType.composite,
      spriteSize: 32,
      animations: _petSheetAnimations,
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyCat1,
      name: 'Cream Studio Cat',
      basePath: 'assets/animations/cats/cat_1/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimations,
      species: PetSpecies.cat,
      requiredConsistencyDays: 10,
    ),
    PetTheme(
      id: keyCat2,
      name: 'Silver Studio Cat',
      basePath: 'assets/animations/cats/cat_2/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimations,
      species: PetSpecies.cat,
      requiredConsistencyDays: 14,
    ),
    PetTheme(
      id: keyCat3,
      name: 'Amber Studio Cat',
      basePath: 'assets/animations/cats/cat_3/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimationsNoItch,
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyCat4,
      name: 'Midnight Studio Cat',
      basePath: 'assets/animations/cats/cat_4/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimations,
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyCat5,
      name: 'Snow Studio Cat',
      basePath: 'assets/animations/cats/cat_5/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimations,
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyCat6,
      name: 'Tuxedo Studio Cat',
      basePath: 'assets/animations/cats/cat_6/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimations,
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyCollie,
      name: 'Collie Dog',
      basePath: 'assets/animations/dogs/collie.png',
      type: PetType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
      species: PetSpecies.dog,
      requiredConsistencyDays: 5,
    ),
    PetTheme(
      id: keyCorgi,
      name: 'Corgi Dog',
      basePath: 'assets/animations/dogs/corgi.png',
      type: PetType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
      species: PetSpecies.dog,
      requiredConsistencyDays: 15,
    ),
    PetTheme(
      id: keyDalmatian,
      name: 'Dalmatian Dog',
      basePath: 'assets/animations/dogs/dalmatian.png',
      type: PetType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
      species: PetSpecies.dog,
    ),
    PetTheme(
      id: keyHusky,
      name: 'Husky Dog',
      basePath: 'assets/animations/dogs/husky.png',
      type: PetType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
      species: PetSpecies.dog,
    ),
    PetTheme(
      id: keyLabrador,
      name: 'Labrador Dog',
      basePath: 'assets/animations/dogs/labrador.png',
      type: PetType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
      species: PetSpecies.dog,
    ),
    PetTheme(
      id: keyFlamingo,
      name: 'Pinky Flamingo',
      basePath: 'assets/animations/flamingo/pixelflamingospritesheet.png',
      type: PetType.composite,
      spriteSize: 128,
      animations: _flamingoSheetAnimations,
      species: PetSpecies.flamingo,
    ),
  ];

  static PetTheme getTheme(String id) {
    return themes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => themes.first,
    );
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
