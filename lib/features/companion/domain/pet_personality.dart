/// Defines the personality traits of a pet companion.
/// These traits influence behavior frequency, mood transitions, and interaction responses.
class PetPersonality {
  /// How active the pet is (0.0 = lazy, 1.0 = hyperactive)
  final double activityLevel;

  /// How social the pet is (0.0 = aloof, 1.0 = affectionate)
  final double sociability;

  /// How playful the pet is (0.0 = serious, 1.0 = playful)
  final double playfulness;

  /// How curious the pet is (0.0 = indifferent, 1.0 = very curious)
  final double curiosity;

  /// How easily startled the pet is (0.0 = brave, 1.0 = skittish)
  final double skittishness;

  /// How independent the pet is (0.0 = needy, 1.0 = independent)
  final double independence;

  /// How vocal the pet is (0.0 = silent, 1.0 = vocal)
  final double vocalness;

  /// How sleepy the pet is (0.0 = alert, 1.0 = sleepy)
  final double sleepiness;

  const PetPersonality({
    this.activityLevel = 0.5,
    this.sociability = 0.5,
    this.playfulness = 0.5,
    this.curiosity = 0.5,
    this.skittishness = 0.3,
    this.independence = 0.5,
    this.vocalness = 0.3,
    this.sleepiness = 0.4,
  });

  /// Preset: Energetic and playful (typical dog)
  static const energetic = PetPersonality(
    activityLevel: 0.8,
    sociability: 0.9,
    playfulness: 0.9,
    curiosity: 0.7,
    skittishness: 0.2,
    independence: 0.3,
    vocalness: 0.6,
    sleepiness: 0.3,
  );

  /// Preset: Lazy and independent (typical cat)
  static const lazy = PetPersonality(
    activityLevel: 0.3,
    sociability: 0.4,
    playfulness: 0.4,
    curiosity: 0.6,
    skittishness: 0.5,
    independence: 0.8,
    vocalness: 0.3,
    sleepiness: 0.7,
  );

  /// Preset: Balanced and friendly
  static const friendly = PetPersonality(
    activityLevel: 0.5,
    sociability: 0.8,
    playfulness: 0.6,
    curiosity: 0.5,
    skittishness: 0.2,
    independence: 0.4,
    vocalness: 0.5,
    sleepiness: 0.4,
  );

  /// Preset: Shy and cautious
  static const shy = PetPersonality(
    activityLevel: 0.3,
    sociability: 0.2,
    playfulness: 0.3,
    curiosity: 0.3,
    skittishness: 0.8,
    independence: 0.7,
    vocalness: 0.2,
    sleepiness: 0.5,
  );

  /// Calculates a weighted behavior score for decision making.
  double behaviorScore({
    required double baseWeight,
    double? activityModifier,
    double? moodModifier,
  }) {
    double score = baseWeight;
    score += activityModifier != null ? activityModifier * activityLevel : 0;
    score += moodModifier != null ? moodModifier * sociability : 0;
    return score.clamp(0.0, 1.0);
  }

  PetPersonality copyWith({
    double? activityLevel,
    double? sociability,
    double? playfulness,
    double? curiosity,
    double? skittishness,
    double? independence,
    double? vocalness,
    double? sleepiness,
  }) {
    return PetPersonality(
      activityLevel: activityLevel ?? this.activityLevel,
      sociability: sociability ?? this.sociability,
      playfulness: playfulness ?? this.playfulness,
      curiosity: curiosity ?? this.curiosity,
      skittishness: skittishness ?? this.skittishness,
      independence: independence ?? this.independence,
      vocalness: vocalness ?? this.vocalness,
      sleepiness: sleepiness ?? this.sleepiness,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activityLevel': activityLevel,
      'sociability': sociability,
      'playfulness': playfulness,
      'curiosity': curiosity,
      'skittishness': skittishness,
      'independence': independence,
      'vocalness': vocalness,
      'sleepiness': sleepiness,
    };
  }

  factory PetPersonality.fromMap(Map<String, dynamic> map) {
    return PetPersonality(
      activityLevel: (map['activityLevel'] as num?)?.toDouble() ?? 0.5,
      sociability: (map['sociability'] as num?)?.toDouble() ?? 0.5,
      playfulness: (map['playfulness'] as num?)?.toDouble() ?? 0.5,
      curiosity: (map['curiosity'] as num?)?.toDouble() ?? 0.5,
      skittishness: (map['skittishness'] as num?)?.toDouble() ?? 0.3,
      independence: (map['independence'] as num?)?.toDouble() ?? 0.5,
      vocalness: (map['vocalness'] as num?)?.toDouble() ?? 0.3,
      sleepiness: (map['sleepiness'] as num?)?.toDouble() ?? 0.4,
    );
  }
}
