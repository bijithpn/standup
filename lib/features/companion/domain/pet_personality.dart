class PetPersonality {
  final double activityLevel;

  final double sociability;

  final double playfulness;

  final double curiosity;

  final double skittishness;

  final double independence;

  final double vocalness;

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
