import 'package:standup/features/companion/domain/animation_row_config.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';

enum CatType { composite, separate }

class CatTheme {
  final String id;
  final String name;
  final String basePath;
  final CatType type;
  final int spriteSize;
  final Map<CatAnimationState, dynamic> animations;

  const CatTheme({
    required this.id,
    required this.name,
    required this.basePath,
    required this.type,
    required this.spriteSize,
    required this.animations,
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
  static const String keyGoldie = 'goldie';
  static const String keyRealisticGoldie = 'realistic_goldie';

  static const Map<CatAnimationState, SeparateAnimationConfig> _catPackAnimations = {
    CatAnimationState.sleep: SeparateAnimationConfig(fileName: 'sleep_1.png', frameCount: 1, stepTime: 0.6),
    CatAnimationState.idle: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 10, stepTime: 0.18),
    CatAnimationState.typing: SeparateAnimationConfig(fileName: 'sitting.png', frameCount: 1, stepTime: 0.5),
    CatAnimationState.walk: SeparateAnimationConfig(fileName: 'walk.png', frameCount: 8, stepTime: 0.12),
    CatAnimationState.excited: SeparateAnimationConfig(fileName: 'run.png', frameCount: 8, stepTime: 0.1),
    CatAnimationState.sad: SeparateAnimationConfig(fileName: 'laying.png', frameCount: 8, stepTime: 0.18),
    CatAnimationState.breakMode: SeparateAnimationConfig(fileName: 'stretching.png', frameCount: 13, stepTime: 0.09),
    CatAnimationState.focusMode: SeparateAnimationConfig(fileName: 'sitting.png', frameCount: 1, stepTime: 0.5),
    CatAnimationState.angry: SeparateAnimationConfig(fileName: 'itch.png', frameCount: 2, stepTime: 0.16, loop: false),
    CatAnimationState.notification: SeparateAnimationConfig(fileName: 'meow.png', frameCount: 4, stepTime: 0.14, loop: false),
    CatAnimationState.celebrate: SeparateAnimationConfig(fileName: 'stretching.png', frameCount: 13, stepTime: 0.08, loop: false),
  };

  static const Map<CatAnimationState, SeparateAnimationConfig> _catPackAnimationsNoItch = {
    CatAnimationState.sleep: SeparateAnimationConfig(fileName: 'sleep_1.png', frameCount: 1, stepTime: 0.6),
    CatAnimationState.idle: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 10, stepTime: 0.18),
    CatAnimationState.typing: SeparateAnimationConfig(fileName: 'sitting.png', frameCount: 1, stepTime: 0.5),
    CatAnimationState.walk: SeparateAnimationConfig(fileName: 'walk.png', frameCount: 8, stepTime: 0.12),
    CatAnimationState.excited: SeparateAnimationConfig(fileName: 'run.png', frameCount: 8, stepTime: 0.1),
    CatAnimationState.sad: SeparateAnimationConfig(fileName: 'laying.png', frameCount: 8, stepTime: 0.18),
    CatAnimationState.breakMode: SeparateAnimationConfig(fileName: 'stretching.png', frameCount: 13, stepTime: 0.09),
    CatAnimationState.focusMode: SeparateAnimationConfig(fileName: 'sitting.png', frameCount: 1, stepTime: 0.5),
    CatAnimationState.angry: SeparateAnimationConfig(fileName: 'meow.png', frameCount: 4, stepTime: 0.16, loop: false),
    CatAnimationState.notification: SeparateAnimationConfig(fileName: 'meow.png', frameCount: 4, stepTime: 0.14, loop: false),
    CatAnimationState.celebrate: SeparateAnimationConfig(fileName: 'stretching.png', frameCount: 13, stepTime: 0.08, loop: false),
  };

  static const Map<CatAnimationState, AnimationRowConfig> _dogSheetAnimations = {
    CatAnimationState.sleep: AnimationRowConfig(row: 0, frameCount: 8, stepTime: 0.4),
    CatAnimationState.idle: AnimationRowConfig(row: 0, frameCount: 8, stepTime: 0.25),
    CatAnimationState.typing: AnimationRowConfig(row: 1, frameCount: 8, stepTime: 0.16),
    CatAnimationState.walk: AnimationRowConfig(row: 1, frameCount: 8, stepTime: 0.16),
    CatAnimationState.excited: AnimationRowConfig(row: 2, frameCount: 8, stepTime: 0.12),
    CatAnimationState.sad: AnimationRowConfig(row: 0, frameCount: 8, stepTime: 0.4),
    CatAnimationState.breakMode: AnimationRowConfig(row: 2, frameCount: 8, stepTime: 0.12),
    CatAnimationState.focusMode: AnimationRowConfig(row: 0, frameCount: 8, stepTime: 0.25),
    CatAnimationState.angry: AnimationRowConfig(row: 2, frameCount: 8, stepTime: 0.12, loop: false),
    CatAnimationState.notification: AnimationRowConfig(row: 2, frameCount: 8, stepTime: 0.12, loop: false),
    CatAnimationState.celebrate: AnimationRowConfig(row: 2, frameCount: 8, stepTime: 0.1),
  };

  static const List<CatTheme> themes = [
    // Grey Cat (32x32 composite)
    CatTheme(
      id: keyGreyCat,
      name: 'Classic Grey Cat',
      basePath: 'assets/animations/cats/grey_cat/sprite_sheet.png',
      type: CatType.composite,
      spriteSize: 32,
      animations: {
        CatAnimationState.sleep: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.idle: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.typing: AnimationRowConfig(row: 2, frameCount: 4, stepTime: 0.25),
        CatAnimationState.walk: AnimationRowConfig(row: 6, frameCount: 8, stepTime: 0.15),
        CatAnimationState.excited: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.sad: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.breakMode: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.focusMode: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.angry: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.notification: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.celebrate: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.1),
      },
    ),
    // Orange Cat (32x32 composite)
    CatTheme(
      id: keyOrangeCat,
      name: 'Playful Orange Cat',
      basePath: 'assets/animations/cats/orange_cat/sprite_sheet.png',
      type: CatType.composite,
      spriteSize: 32,
      animations: {
        CatAnimationState.sleep: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.idle: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.typing: AnimationRowConfig(row: 2, frameCount: 4, stepTime: 0.25),
        CatAnimationState.walk: AnimationRowConfig(row: 6, frameCount: 8, stepTime: 0.15),
        CatAnimationState.excited: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.sad: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.breakMode: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.focusMode: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.angry: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.notification: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.celebrate: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.1),
      },
    ),
    // Black Cat (32x32 composite)
    CatTheme(
      id: keyBlackCat,
      name: 'Sleek Black Cat',
      basePath: 'assets/animations/cats/black_cat/sprite_sheet.png',
      type: CatType.composite,
      spriteSize: 32,
      animations: {
        CatAnimationState.sleep: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.idle: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.typing: AnimationRowConfig(row: 2, frameCount: 4, stepTime: 0.25),
        CatAnimationState.walk: AnimationRowConfig(row: 6, frameCount: 8, stepTime: 0.15),
        CatAnimationState.excited: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.sad: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.breakMode: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.focusMode: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.angry: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.notification: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.celebrate: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.1),
      },
    ),
    // Large Cat (32x32 separate files)
    CatTheme(
      id: keyLargeCat,
      name: 'Fluffy Large Cat',
      basePath: 'assets/animations/cats/large_cat/',
      type: CatType.separate,
      spriteSize: 32,
      animations: {
        // Map states to asset name and configuration parameters
        CatAnimationState.sleep: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 8, stepTime: 0.4),
        CatAnimationState.idle: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 8, stepTime: 0.3),
        CatAnimationState.typing: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 8, stepTime: 0.3),
        CatAnimationState.walk: SeparateAnimationConfig(fileName: 'run.png', frameCount: 10, stepTime: 0.15),
        CatAnimationState.excited: SeparateAnimationConfig(fileName: 'run.png', frameCount: 10, stepTime: 0.12),
        CatAnimationState.sad: SeparateAnimationConfig(fileName: 'fall.png', frameCount: 4, stepTime: 0.25),
        CatAnimationState.breakMode: SeparateAnimationConfig(fileName: 'run.png', frameCount: 10, stepTime: 0.12),
        CatAnimationState.focusMode: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 8, stepTime: 0.3),
        CatAnimationState.angry: SeparateAnimationConfig(fileName: 'jump.png', frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.notification: SeparateAnimationConfig(fileName: 'jump.png', frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.celebrate: SeparateAnimationConfig(fileName: 'run.png', frameCount: 10, stepTime: 0.1),
      },
    ),
    CatTheme(
      id: keyPixelCat,
      name: 'Pixel Explorer Cat',
      basePath: 'assets/animations/cats/pixel_cat/',
      type: CatType.separate,
      spriteSize: 64,
      animations: {
        CatAnimationState.sleep: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 10, stepTime: 0.4),
        CatAnimationState.idle: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 10, stepTime: 0.12),
        CatAnimationState.typing: SeparateAnimationConfig(fileName: 'walk.png', frameCount: 15, stepTime: 0.08),
        CatAnimationState.walk: SeparateAnimationConfig(fileName: 'walk.png', frameCount: 15, stepTime: 0.08),
        CatAnimationState.excited: SeparateAnimationConfig(fileName: 'run.png', frameCount: 10, stepTime: 0.08),
        CatAnimationState.sad: SeparateAnimationConfig(fileName: 'hurt.png', frameCount: 5, stepTime: 0.12, loop: false),
        CatAnimationState.breakMode: SeparateAnimationConfig(fileName: 'run.png', frameCount: 10, stepTime: 0.08),
        CatAnimationState.focusMode: SeparateAnimationConfig(fileName: 'idle.png', frameCount: 10, stepTime: 0.16),
        CatAnimationState.angry: SeparateAnimationConfig(fileName: 'attack.png', frameCount: 10, stepTime: 0.08, loop: false),
        CatAnimationState.notification: SeparateAnimationConfig(fileName: 'jump.png', frameCount: 3, stepTime: 0.12, loop: false),
        CatAnimationState.celebrate: SeparateAnimationConfig(fileName: 'running jump.png', frameCount: 3, stepTime: 0.1, loop: false),
      },
    ),
    CatTheme(
      id: keyCat1,
      name: 'Cream Studio Cat',
      basePath: 'assets/animations/cats/cat_1/',
      type: CatType.separate,
      spriteSize: 50,
      animations: _catPackAnimations,
    ),
    CatTheme(
      id: keyCat2,
      name: 'Silver Studio Cat',
      basePath: 'assets/animations/cats/cat_2/',
      type: CatType.separate,
      spriteSize: 50,
      animations: _catPackAnimations,
    ),
    CatTheme(
      id: keyCat3,
      name: 'Amber Studio Cat',
      basePath: 'assets/animations/cats/cat_3/',
      type: CatType.separate,
      spriteSize: 50,
      animations: _catPackAnimationsNoItch,
    ),
    CatTheme(
      id: keyCat4,
      name: 'Midnight Studio Cat',
      basePath: 'assets/animations/cats/cat_4/',
      type: CatType.separate,
      spriteSize: 50,
      animations: _catPackAnimations,
    ),
    CatTheme(
      id: keyCat5,
      name: 'Snow Studio Cat',
      basePath: 'assets/animations/cats/cat_5/',
      type: CatType.separate,
      spriteSize: 50,
      animations: _catPackAnimations,
    ),
    CatTheme(
      id: keyCat6,
      name: 'Tuxedo Studio Cat',
      basePath: 'assets/animations/cats/cat_6/',
      type: CatType.separate,
      spriteSize: 50,
      animations: _catPackAnimations,
    ),
    CatTheme(
      id: keyCat50,
      name: 'Tiny Sheet Cat',
      basePath: 'assets/animations/cats/cat_50/cat_sheet.png',
      type: CatType.composite,
      spriteSize: 32,
      animations: {
        CatAnimationState.sleep: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.idle: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.typing: AnimationRowConfig(row: 2, frameCount: 4, stepTime: 0.25),
        CatAnimationState.walk: AnimationRowConfig(row: 6, frameCount: 8, stepTime: 0.15),
        CatAnimationState.excited: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.sad: AnimationRowConfig(row: 0, frameCount: 4, stepTime: 0.4),
        CatAnimationState.breakMode: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.12),
        CatAnimationState.focusMode: AnimationRowConfig(row: 1, frameCount: 4, stepTime: 0.3),
        CatAnimationState.angry: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.notification: AnimationRowConfig(row: 11, frameCount: 4, stepTime: 0.2, loop: false),
        CatAnimationState.celebrate: AnimationRowConfig(row: 9, frameCount: 8, stepTime: 0.1),
      },
    ),
    CatTheme(
      id: keyCollie,
      name: 'Collie Dog',
      basePath: 'assets/animations/dogs/collie.png',
      type: CatType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
    ),
    CatTheme(
      id: keyCorgi,
      name: 'Corgi Dog',
      basePath: 'assets/animations/dogs/corgi.png',
      type: CatType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
    ),
    CatTheme(
      id: keyDalmatian,
      name: 'Dalmatian Dog',
      basePath: 'assets/animations/dogs/dalmatian.png',
      type: CatType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
    ),
    CatTheme(
      id: keyHusky,
      name: 'Husky Dog',
      basePath: 'assets/animations/dogs/husky.png',
      type: CatType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
    ),
    CatTheme(
      id: keyLabrador,
      name: 'Labrador Dog',
      basePath: 'assets/animations/dogs/labrador.png',
      type: CatType.composite,
      spriteSize: 64,
      animations: _dogSheetAnimations,
    ),
    CatTheme(
      id: keyGoldie,
      name: 'Goldie Dog',
      basePath: 'assets/animations/dogs/goldie/goldie_v02.png',
      type: CatType.composite,
      spriteSize: 64,
      animations: {
        CatAnimationState.sleep: AnimationRowConfig(row: 0, frameCount: 2, stepTime: 0.45),
        CatAnimationState.idle: AnimationRowConfig(row: 0, frameCount: 2, stepTime: 0.35),
        CatAnimationState.typing: AnimationRowConfig(row: 1, frameCount: 2, stepTime: 0.2),
        CatAnimationState.walk: AnimationRowConfig(row: 1, frameCount: 2, stepTime: 0.2),
        CatAnimationState.excited: AnimationRowConfig(row: 2, frameCount: 2, stepTime: 0.16),
        CatAnimationState.sad: AnimationRowConfig(row: 3, frameCount: 2, stepTime: 0.35),
        CatAnimationState.breakMode: AnimationRowConfig(row: 2, frameCount: 2, stepTime: 0.16),
        CatAnimationState.focusMode: AnimationRowConfig(row: 0, frameCount: 2, stepTime: 0.35),
        CatAnimationState.angry: AnimationRowConfig(row: 4, frameCount: 2, stepTime: 0.18, loop: false),
        CatAnimationState.notification: AnimationRowConfig(row: 4, frameCount: 2, stepTime: 0.18, loop: false),
        CatAnimationState.celebrate: AnimationRowConfig(row: 2, frameCount: 2, stepTime: 0.14),
      },
    ),
    CatTheme(
      id: keyRealisticGoldie,
      name: 'Realistic Goldie Dog',
      basePath: 'assets/animations/dogs/goldie/',
      type: CatType.separate,
      spriteSize: 64,
      animations: {
        CatAnimationState.sleep: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.idle: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.typing: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.walk: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.excited: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.sad: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.breakMode: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.focusMode: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.angry: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.notification: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
        CatAnimationState.celebrate: SeparateAnimationConfig(fileName: 'realistic_goldie.png', frameCount: 1, stepTime: 0.5),
      },
    ),
  ];

  static CatTheme getTheme(String id) {
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
