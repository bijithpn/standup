enum PetMood {
  happy,
  playful,
  relaxed,
  curious,
  tired,
  hungry,
  affectionate,
  alert,
  scared,
  bored,
  satisfied,
  mischievous,
}

class PetMoodState {
  final PetMood mood;
  final double intensity; // 0.0 to 1.0
  final DateTime since;
  final Duration decayDuration;

  const PetMoodState({
    required this.mood,
    this.intensity = 0.5,
    required this.since,
    this.decayDuration = const Duration(minutes: 5),
  });

  double getCurrentIntensity([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(since);
    if (elapsed >= decayDuration) return 0.0;
    return intensity *
        (1.0 - elapsed.inMilliseconds / decayDuration.inMilliseconds);
  }

  bool isActive([DateTime? now]) => getCurrentIntensity(now) > 0.0;

  PetMoodState copyWith({
    PetMood? mood,
    double? intensity,
    DateTime? since,
    Duration? decayDuration,
  }) {
    return PetMoodState(
      mood: mood ?? this.mood,
      intensity: intensity ?? this.intensity,
      since: since ?? this.since,
      decayDuration: decayDuration ?? this.decayDuration,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mood': mood.name,
      'intensity': intensity,
      'since': since.toIso8601String(),
      'decayDuration': decayDuration.inMilliseconds,
    };
  }

  factory PetMoodState.fromMap(Map<String, dynamic> map) {
    return PetMoodState(
      mood: PetMood.values.byName(map['mood'] as String),
      intensity: (map['intensity'] as num?)?.toDouble() ?? 0.5,
      since: DateTime.parse(map['since'] as String),
      decayDuration: Duration(
        milliseconds: map['decayDuration'] as int? ?? 300000,
      ),
    );
  }
}
