/// Defines how a pet's animation frames are organized.
enum SpriteLayout {
  /// All frames in a single sprite sheet grid.
  spriteSheet,

  /// Individual image files per animation state.
  individualFrames,

  /// Mixed: some states use sprite sheets, others use individual frames.
  mixed,
}

/// Generic pet animation states.
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
  focusMode,
  angry,
  notification,
  celebrate,
  lick1,
  lick2,
  breatheFire,
  fly,
  hop,
  glide,
  // Behavior-engine states (pet-behavior-engine spec, task 14.2)
  chasing,   // maps to run sprite row (or dedicated if available)
  fetching,  // maps to walkSide with item
  falling,   // maps to run or a new falling sprite
  reacting,  // maps to notification or a new reacting sprite
}

/// Configuration for a specific animation state's visual representation.
class PetAnimationConfig {
  final String stateName;
  final SpriteLayout layout;

  // Sprite sheet properties
  final int? frameX;
  final int? frameY;
  final int? frameWidth;
  final int? frameHeight;
  final int? totalFrames;
  final double? stepTime;

  // Directional sprite sheet rows (optional)
  final int? rowUp;
  final int? rowDown;
  final int? rowSide;

  // Individual frames
  final List<String>? framePaths;
  final double? individualFrameStepTime;

  // Fallback
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

  /// Creates an animation from a sprite sheet row.
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

  /// Creates an animation from individual frame files.
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

/// Maps pet states to their animation configurations.
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
