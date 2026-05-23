import 'package:standup/features/companion/domain/animation_row_config.dart';
import 'package:standup/features/companion/domain/pet_animation_state.dart';
import 'package:standup/features/companion/domain/pet_type.dart';

enum PetType { composite, separate }

class PetTheme {
  final String id;
  final String name;
  final String basePath;
  final PetType type;
  final int spriteSize;
  final Map<PetAnimationState, dynamic> animations;
  final PetSpecies species;

  const PetTheme({
    required this.id,
    required this.name,
    required this.basePath,
    required this.type,
    required this.spriteSize,
    required this.animations,
    this.species = PetSpecies.cat,
  });

  static const String keyGreyCat = 'grey_cat';
  static const String keyOrangeCat = 'orange_cat';
  static const String keyBlackCat = 'black_cat';
  static const String keyLargeCat = 'large_cat';
  static const String keyPixelCat = 'pixel_cat';
  static const String keyCat1 = 'cat_1';
  static const String keyCat2 = 'cat_2';
  static const String keyCat3 = 'cat_3';
  static const String keyCat4 = 'cat_4';
  static const String keyCat5 = 'cat_5';
  static const String keyCat6 = 'cat_6';
  static const String keyCat50 = 'cat_50';
  static const String keyCollie = 'collie';
  static const String keyCorgi = 'corgi';
  static const String keyDalmatian = 'dalmatian';
  static const String keyHusky = 'husky';
  static const String keyLabrador = 'labrador';
  static const String keyRabbit = 'rabbit_hop_01';
  static const String keyFox = 'fox_firefox_01';
  static const String keyDragon = 'dragon_shadow_01';

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
          frameCount: 8,
          stepTime: 0.1,
        ),
        PetAnimationState.celebrate: AnimationRowConfig(
          row: 2,
          frameCount: 8,
          stepTime: 0.08,
        ),
        PetAnimationState.notification: AnimationRowConfig(
          row: 2,
          frameCount: 8,
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
          frameCount: 8,
          stepTime: 0.15,
          loop: false,
        ),
        PetAnimationState.breakMode: AnimationRowConfig(
          row: 2,
          frameCount: 8,
          stepTime: 0.12,
        ),
        PetAnimationState.focusMode: AnimationRowConfig(
          row: 0,
          frameCount: 8,
          stepTime: 0.25,
        ),
        PetAnimationState.angry: AnimationRowConfig(
          row: 2,
          frameCount: 8,
          stepTime: 0.12,
          loop: false,
        ),
      };

  static const Map<PetAnimationState, AnimationRowConfig> _petSheetAnimations =
      {
        PetAnimationState.sleep: AnimationRowConfig(
          row: 0,
          frameCount: 4,
          stepTime: 0.4,
        ),
        PetAnimationState.idle: AnimationRowConfig(
          row: 1,
          frameCount: 4,
          stepTime: 0.3,
        ),
        PetAnimationState.typing: AnimationRowConfig(
          row: 2,
          frameCount: 4,
          stepTime: 0.25,
        ),
        PetAnimationState.walkSide: AnimationRowConfig(
          row: 6,
          frameCount: 8,
          stepTime: 0.15,
        ),
        PetAnimationState.excited: AnimationRowConfig(
          row: 9,
          frameCount: 8,
          stepTime: 0.12,
        ),
        PetAnimationState.sad: AnimationRowConfig(
          row: 0,
          frameCount: 4,
          stepTime: 0.4,
        ),
        PetAnimationState.stretch: AnimationRowConfig(
          row: 9,
          frameCount: 8,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.breakMode: AnimationRowConfig(
          row: 9,
          frameCount: 8,
          stepTime: 0.12,
        ),
        PetAnimationState.focusMode: AnimationRowConfig(
          row: 1,
          frameCount: 4,
          stepTime: 0.3,
        ),
        PetAnimationState.angry: AnimationRowConfig(
          row: 11,
          frameCount: 4,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.notification: AnimationRowConfig(
          row: 11,
          frameCount: 4,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.celebrate: AnimationRowConfig(
          row: 9,
          frameCount: 8,
          stepTime: 0.1,
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
      id: keyLargeCat,
      name: 'Fluffy Large Cat',
      basePath: 'assets/animations/cats/large_cat/',
      type: PetType.separate,
      spriteSize: 32,
      animations: {
        PetAnimationState.sleep: SeparateAnimationConfig(
          fileName: 'idle.png',
          frameCount: 8,
          stepTime: 0.4,
        ),
        PetAnimationState.idle: SeparateAnimationConfig(
          fileName: 'idle.png',
          frameCount: 8,
          stepTime: 0.3,
        ),
        PetAnimationState.typing: SeparateAnimationConfig(
          fileName: 'idle.png',
          frameCount: 8,
          stepTime: 0.3,
        ),
        PetAnimationState.walkSide: SeparateAnimationConfig(
          fileName: 'run.png',
          frameCount: 10,
          stepTime: 0.15,
        ),
        PetAnimationState.excited: SeparateAnimationConfig(
          fileName: 'run.png',
          frameCount: 10,
          stepTime: 0.12,
        ),
        PetAnimationState.sad: SeparateAnimationConfig(
          fileName: 'fall.png',
          frameCount: 4,
          stepTime: 0.25,
        ),
        PetAnimationState.breakMode: SeparateAnimationConfig(
          fileName: 'run.png',
          frameCount: 10,
          stepTime: 0.12,
        ),
        PetAnimationState.focusMode: SeparateAnimationConfig(
          fileName: 'idle.png',
          frameCount: 8,
          stepTime: 0.3,
        ),
        PetAnimationState.angry: SeparateAnimationConfig(
          fileName: 'jump.png',
          frameCount: 4,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.notification: SeparateAnimationConfig(
          fileName: 'jump.png',
          frameCount: 4,
          stepTime: 0.2,
          loop: false,
        ),
        PetAnimationState.celebrate: SeparateAnimationConfig(
          fileName: 'run.png',
          frameCount: 10,
          stepTime: 0.1,
        ),
      },
      species: PetSpecies.cat,
    ),
    PetTheme(
      id: keyPixelCat,
      name: 'Pixel Explorer Cat',
      basePath: 'assets/animations/cats/pixel_cat/',
      type: PetType.separate,
      spriteSize: 64,
      animations: {
        PetAnimationState.sleep: SeparateAnimationConfig(
          fileName: 'idle.png',
          frameCount: 10,
          stepTime: 0.4,
        ),
        PetAnimationState.idle: SeparateAnimationConfig(
          fileName: 'idle.png',
          frameCount: 10,
          stepTime: 0.12,
        ),
        PetAnimationState.typing: SeparateAnimationConfig(
          fileName: 'walk.png',
          frameCount: 15,
          stepTime: 0.08,
        ),
        PetAnimationState.walkSide: SeparateAnimationConfig(
          fileName: 'walk.png',
          frameCount: 15,
          stepTime: 0.08,
        ),
        PetAnimationState.excited: SeparateAnimationConfig(
          fileName: 'run.png',
          frameCount: 10,
          stepTime: 0.08,
        ),
        PetAnimationState.sad: SeparateAnimationConfig(
          fileName: 'hurt.png',
          frameCount: 5,
          stepTime: 0.12,
          loop: false,
        ),
        PetAnimationState.breakMode: SeparateAnimationConfig(
          fileName: 'run.png',
          frameCount: 10,
          stepTime: 0.08,
        ),
        PetAnimationState.focusMode: SeparateAnimationConfig(
          fileName: 'idle.png',
          frameCount: 10,
          stepTime: 0.16,
        ),
        PetAnimationState.angry: SeparateAnimationConfig(
          fileName: 'attack.png',
          frameCount: 10,
          stepTime: 0.08,
          loop: false,
        ),
        PetAnimationState.notification: SeparateAnimationConfig(
          fileName: 'jump.png',
          frameCount: 3,
          stepTime: 0.12,
          loop: false,
        ),
        PetAnimationState.celebrate: SeparateAnimationConfig(
          fileName: 'running jump.png',
          frameCount: 3,
          stepTime: 0.1,
          loop: false,
        ),
      },
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
    ),
    PetTheme(
      id: keyCat2,
      name: 'Silver Studio Cat',
      basePath: 'assets/animations/cats/cat_2/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimations,
      species: PetSpecies.cat,
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
      id: keyCat50,
      name: 'Tiny Sheet Cat',
      basePath: 'assets/animations/cats/cat_50/cat_sheet.png',
      type: PetType.composite,
      spriteSize: 32,
      animations: _petSheetAnimations,
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
    ),
    PetTheme(
      id: keyCorgi,
      name: 'Corgi Dog',
      basePath: 'assets/animations/dogs/corgi.png',
      type: PetType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
      species: PetSpecies.dog,
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
    // --- New Species Themes ---
    PetTheme(
      id: keyRabbit,
      name: 'Ginger Hop Rabbit',
      basePath: 'assets/animations/cats/cat_1/',
      type: PetType.separate,
      spriteSize: 50,
      animations: _petPackAnimations,
      species: PetSpecies.rabbit,
    ),
    PetTheme(
      id: keyFox,
      name: 'Firefox Fox',
      basePath: 'assets/animations/cats/orange_cat/sprite_sheet.png',
      type: PetType.composite,
      spriteSize: 32,
      animations: _petSheetAnimations,
      species: PetSpecies.fox,
    ),
    PetTheme(
      id: keyDragon,
      name: 'Shadow Wing Dragon',
      basePath: 'assets/animations/cats/black_cat/sprite_sheet.png',
      type: PetType.composite,
      spriteSize: 32,
      animations: _petSheetAnimations,
      species: PetSpecies.dragon,
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
