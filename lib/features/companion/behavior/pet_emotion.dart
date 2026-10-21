/// What the companion is feeling, and how strongly.
///
/// Kept deliberately small. A face has a handful of legible states, and a pet
/// that cycles through twenty subtly different moods reads as broken rather
/// than nuanced — the point is that someone glancing at the corner of their
/// screen understands it instantly, without a caption.
enum PetEmotion {
  /// The resting state: awake, unbothered, quietly present.
  content,

  /// Pleased. Follows attention, play, or a break well taken.
  happy,

  /// Wound up and wanting to play.
  excited,

  /// Something caught its interest and it is working out what.
  curious,

  /// Being petted. The warmest state, and short-lived on purpose.
  affectionate,

  /// Ignored for a long stretch. Not distress — the look of a pet waiting by
  /// the door.
  lonely,

  /// Worn out. Comes from a long unbroken working stretch, not from boredom.
  weary,

  /// Eyes shut, breathing slow.
  sleepy,

  /// A fright, from sudden movement nearby. Always brief.
  startled;

  /// Whether the emotion is a pleasant one, for choosing warm or cool accents.
  bool get isPositive =>
      this == PetEmotion.happy ||
      this == PetEmotion.excited ||
      this == PetEmotion.affectionate ||
      this == PetEmotion.content;

  /// Whether this state should hold the face still rather than animate it.
  bool get isRestful => this == PetEmotion.sleepy || this == PetEmotion.weary;
}

/// An emotion together with how strongly it is felt.
class PetEmotionState {
  const PetEmotionState({
    required this.emotion,
    required this.intensity,
    this.affection = 0,
    this.loneliness = 0,
    this.fatigue = 0,
  });

  final PetEmotion emotion;

  /// 0..1. Drives how far the face moves from its resting shape, so a mild
  /// feeling is a hint and a strong one is unmistakable.
  final double intensity;

  /// The slow-moving drives behind the emotion, exposed for the settings and
  /// diagnostics rather than for the face.
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

/// What the companion would most appreciate right now.
///
/// The emotion says how the pet feels; this says what to do about it. The two
/// are deliberately separate: a lonely pet and a bored one wear different
/// faces but both want the same thing, and a face alone never tells a new user
/// which button to press.
enum PetWish {
  /// Asleep, or settled enough that the kind thing is to leave it be.
  none,

  /// Wants attention — a touch, a scratch.
  petting,

  /// Wound up and looking for a game.
  play,

  /// Peckish. The small pleasant default.
  treat,

  /// Not the pet's need but the user's: it has watched them work without a
  /// break for a long time.
  rest,
}
