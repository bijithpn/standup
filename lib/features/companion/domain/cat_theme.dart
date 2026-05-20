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
