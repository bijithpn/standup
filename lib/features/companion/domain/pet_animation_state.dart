import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';

enum SpriteLayout { spriteSheet, individualFrames, mixed }

enum PetAnimationState {
  idle,
  walkUp,
  walkDown,
  walkSide,
  run,
  sleep,
  typing,
  excited,
  sad,
  stretch,
  blink,
  breakMode,
  angry,
  notification,
  celebrate,
  lick1,
  lick2,
  breatheFire,
  fly,
  hop,
  glide,
  chasing,
  fetching,
  falling,
  reacting,
  petting,
}

extension PetAnimationStateAvatarExtension on PetAnimationState {
  AvatarAnimationClip toAvatarClip() {
    switch (this) {
      case PetAnimationState.idle:
        return AvatarAnimationClip.idle;
      case PetAnimationState.walkUp:
      case PetAnimationState.walkDown:
      case PetAnimationState.walkSide:
      case PetAnimationState.fly:
      case PetAnimationState.glide:
        return AvatarAnimationClip.walk;
      case PetAnimationState.run:
      case PetAnimationState.chasing:
      case PetAnimationState.fetching:
        return AvatarAnimationClip.run;
      case PetAnimationState.sleep:
        return AvatarAnimationClip.sleep;
      case PetAnimationState.typing:
        return AvatarAnimationClip.idle;
      case PetAnimationState.excited:
        return AvatarAnimationClip.celebrate;
      case PetAnimationState.sad:
        return AvatarAnimationClip.glance;
      case PetAnimationState.stretch:
      case PetAnimationState.breakMode:
        return AvatarAnimationClip.stretch;
      case PetAnimationState.blink:
        return AvatarAnimationClip.blink;
      case PetAnimationState.angry:
      case PetAnimationState.breatheFire:
        return AvatarAnimationClip.anger;
      case PetAnimationState.notification:
        return AvatarAnimationClip.nod;
      case PetAnimationState.celebrate:
        return AvatarAnimationClip.celebrate;
      case PetAnimationState.lick1:
      case PetAnimationState.lick2:
      case PetAnimationState.petting:
        return AvatarAnimationClip.bounce;
      case PetAnimationState.hop:
        return AvatarAnimationClip.jump;
      case PetAnimationState.falling:
        return AvatarAnimationClip.wiggle;
      case PetAnimationState.reacting:
        return AvatarAnimationClip.lookAround;
    }
  }
}

class PetAnimationConfig {
  final String stateName;
  final SpriteLayout layout;

  final int? frameX;
  final int? frameY;
  final int? frameWidth;
  final int? frameHeight;
  final int? totalFrames;
  final double? stepTime;

  final int? rowUp;
  final int? rowDown;
  final int? rowSide;

  final List<String>? framePaths;
  final double? individualFrameStepTime;

  final String? fallbackStateName;

  const PetAnimationConfig({
    required this.stateName,
    this.layout = SpriteLayout.spriteSheet,
    this.frameX,
    this.frameY,
    this.frameWidth,
    this.frameHeight,
    this.totalFrames,
    this.stepTime = 0.1,
    this.rowUp,
    this.rowDown,
    this.rowSide,
    this.framePaths,
    this.individualFrameStepTime = 0.1,
    this.fallbackStateName,
  });

  factory PetAnimationConfig.sheetRow({
    required String stateName,
    required int frameY,
    required int frameWidth,
    required int frameHeight,
    required int totalFrames,
    double stepTime = 0.1,
    int? rowUp,
    int? rowDown,
    int? rowSide,
    String? fallbackStateName,
  }) {
    return PetAnimationConfig(
      stateName: stateName,
      layout: SpriteLayout.spriteSheet,
      frameX: 0,
      frameY: frameY,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      totalFrames: totalFrames,
      stepTime: stepTime,
      rowUp: rowUp,
      rowDown: rowDown,
      rowSide: rowSide,
      fallbackStateName: fallbackStateName,
    );
  }

  factory PetAnimationConfig.frames({
    required String stateName,
    required List<String> framePaths,
    double stepTime = 0.1,
    String? fallbackStateName,
  }) {
    return PetAnimationConfig(
      stateName: stateName,
      layout: SpriteLayout.individualFrames,
      framePaths: framePaths,
      individualFrameStepTime: stepTime,
      fallbackStateName: fallbackStateName,
    );
  }

  PetAnimationConfig copyWith({
    String? stateName,
    SpriteLayout? layout,
    int? frameX,
    int? frameY,
    int? frameWidth,
    int? frameHeight,
    int? totalFrames,
    double? stepTime,
    int? rowUp,
    int? rowDown,
    int? rowSide,
    List<String>? framePaths,
    double? individualFrameStepTime,
    String? fallbackStateName,
  }) {
    return PetAnimationConfig(
      stateName: stateName ?? this.stateName,
      layout: layout ?? this.layout,
      frameX: frameX ?? this.frameX,
      frameY: frameY ?? this.frameY,
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
      totalFrames: totalFrames ?? this.totalFrames,
      stepTime: stepTime ?? this.stepTime,
      rowUp: rowUp ?? this.rowUp,
      rowDown: rowDown ?? this.rowDown,
      rowSide: rowSide ?? this.rowSide,
      framePaths: framePaths ?? this.framePaths,
      individualFrameStepTime:
          individualFrameStepTime ?? this.individualFrameStepTime,
      fallbackStateName: fallbackStateName ?? this.fallbackStateName,
    );
  }
}

class PetAnimationRegistry {
  final Map<String, PetAnimationConfig> _configs = {};

  void register(PetAnimationConfig config) {
    _configs[config.stateName] = config;
  }

  PetAnimationConfig? get(String stateName) {
    return _configs[stateName];
  }

  PetAnimationConfig getOrDefault(
    String stateName,
    PetAnimationConfig fallback,
  ) {
    return _configs[stateName] ?? fallback;
  }

  bool has(String stateName) => _configs.containsKey(stateName);

  Set<String> get registeredStates => _configs.keys.toSet();

  void clear() => _configs.clear();
}
