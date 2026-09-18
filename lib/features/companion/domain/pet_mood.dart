import 'pet_needs.dart';

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

extension PetMoodCalculator on PetMood {
  static PetMood fromNeeds(PetNeeds needs) {
    if (needs.breakMode) return PetMood.happy;
    if (needs.energyLevel <= 20.0 || needs.energy <= 0.20) return PetMood.tired;
    if (needs.hunger > 75.0 || needs.hungerNormalized > 0.75) return PetMood.hungry;
    if (needs.boredom > 70.0 || needs.boredomNormalized > 0.70) return PetMood.bored;
    if (needs.happiness > 80.0 || needs.happinessNormalized > 0.80) return PetMood.happy;
    if (needs.focusMode) return PetMood.relaxed;
    if (needs.affection > 0.7) return PetMood.affectionate;
    if (needs.playfulness > 0.7) return PetMood.playful;
    return PetMood.relaxed;
  }
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

  factory PetMoodState.fromNeeds(PetNeeds needs, [DateTime? now]) {
    final mood = PetMoodCalculator.fromNeeds(needs);
    double intensity = 0.5;
    if (mood == PetMood.tired) {
      intensity = ((100.0 - needs.energyLevel) / 100.0).clamp(0.1, 1.0);
    } else if (mood == PetMood.hungry) {
      intensity = needs.hungerNormalized;
    } else if (mood == PetMood.bored) {
      intensity = needs.boredomNormalized;
    } else if (mood == PetMood.happy) {
      intensity = needs.happinessNormalized;
    }
    return PetMoodState(
      mood: mood,
      intensity: intensity,
      since: now ?? DateTime.now(),
    );
  }

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

