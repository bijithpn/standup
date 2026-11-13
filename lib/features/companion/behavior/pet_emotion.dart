/// Visible emotion that picks the avatar's face expression.
enum PetEmotion {
  content,

  happy,

  excited,

  curious,

  affectionate,

  lonely,

  weary,

  sleepy,

  startled,

  playful,

  laughing;

  bool get isPositive =>
      this == PetEmotion.happy ||
      this == PetEmotion.excited ||
      this == PetEmotion.affectionate ||
      this == PetEmotion.playful ||
      this == PetEmotion.laughing ||
      this == PetEmotion.content;

  bool get isRestful => this == PetEmotion.sleepy || this == PetEmotion.weary;
}

/// Emotion plus intensity.
class PetEmotionState {
  const PetEmotionState({
    required this.emotion,
    required this.intensity,
    this.affection = 0,
    this.loneliness = 0,
    this.fatigue = 0,
  });

  final PetEmotion emotion;

  final double intensity;

  final double affection;
  final double loneliness;
  final double fatigue;

  static const PetEmotionState neutral = PetEmotionState(
    emotion: PetEmotion.content,
    intensity: 0.25,
  );

  PetEmotionState copyWith({
    PetEmotion? emotion,
    double? intensity,
    double? affection,
    double? loneliness,
    double? fatigue,
  }) {
    return PetEmotionState(
      emotion: emotion ?? this.emotion,
      intensity: intensity ?? this.intensity,
      affection: affection ?? this.affection,
      loneliness: loneliness ?? this.loneliness,
      fatigue: fatigue ?? this.fatigue,
    );
  }

  @override
  String toString() =>
      'PetEmotionState(${emotion.name} @ ${intensity.toStringAsFixed(2)})';
}

enum PetWish { none, petting, play, treat, rest }
