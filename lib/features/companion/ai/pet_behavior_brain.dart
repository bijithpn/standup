import 'dart:math';
import '../domain/pet_behavior_context.dart';
import '../domain/pet_state_machine.dart';
import '../domain/pet_mood.dart';

/// Uses weighted scoring across multiple factors to avoid repetitive actions.
class PetBehaviorBrain {
  final Random _random = Random();
  final Map<PetState, DateTime> _lastStateTimes = {};
  final Map<PetState, int> _stateFrequency = {};

  PetState decideNextState(PetBehaviorContext context) {
    final candidates = _getCandidateStates(context);

    if (candidates.isEmpty) {
      return PetState.idle;
    }

    final scored = candidates.map((state) {
      final score = _calculateStateScore(state, context);
      return MapEntry(state, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    final topCandidates = scored.take(3).toList();
    final totalWeight = topCandidates.fold<double>(
      0,
      (sum, e) => sum + e.value,
    );

    var threshold = _random.nextDouble() * totalWeight;
    for (final candidate in topCandidates) {
      threshold -= candidate.value;
      if (threshold <= 0) {
        return candidate.key;
      }
    }

    return topCandidates.first.key;
  }

  List<PetState> _getCandidateStates(PetBehaviorContext context) {
    final candidates = <PetState>[];

    // Spontaneous ambient candidates so the pet always has an active, unpredictable life
    candidates.addAll([
      PetState.idle,
      PetState.blink,
      PetState.stretch,
      PetState.walk,
      PetState.grooming,
      PetState.exploring,
      PetState.bored,
      PetState.resting,
      PetState.curious,
    ]);

    if (context.isBreakActive) {
      candidates.addAll([
        PetState.celebrating,
        PetState.dancing,
        PetState.playing,
      ]);
    }

    if (context.isMeetingDetected) {
      candidates.addAll([PetState.sleep, PetState.hiding, PetState.quiet]);
    }

    if (context.isCursorNearby && context.cursorDistance < 100) {
      candidates.addAll([
        PetState.interacting,
        PetState.curious,
        PetState.following,
      ]);
    }

    if (context.isHighEnergyState) {
      candidates.addAll([PetState.run, PetState.jumping, PetState.playing]);
    }

    if (context.shouldSeekInteraction) {
      candidates.addAll([
        PetState.interacting,
        PetState.affectionate,
        PetState.playing,
      ]);
    }

    if (context.isNearScreenEdge) {
      candidates.add(PetState.turning);
    }

    if (context.isIdle) {
      candidates.addAll([PetState.sleep, PetState.resting, PetState.bored]);
    }

    if (context.profile.personality.curiosity > 0.7) {
      candidates.add(PetState.exploring);
    }

    if (context.profile.personality.playfulness > 0.6) {
      candidates.add(PetState.playing);
    }

    return candidates.toSet().toList();
  }

  double _calculateStateScore(PetState state, PetBehaviorContext context) {
    var score = 1.0;

    final lastUsed = _lastStateTimes[state];
    if (lastUsed != null) {
      final secondsSince = DateTime.now().difference(lastUsed).inSeconds;
      final recencyPenalty = (1.0 / (1.0 + secondsSince * 0.1)).clamp(0.0, 0.8);
      score *= (1.0 - recencyPenalty);
    }

    final frequency = _stateFrequency[state] ?? 0;
    if (frequency > 3) {
      score *= (1.0 - (frequency - 3) * 0.15).clamp(0.2, 1.0);
    }

    final moodAlignment = _getMoodAlignmentScore(state, context.currentMood);
    score *= (1.0 + moodAlignment * 0.5);

    final personalityAlignment = _getPersonalityAlignmentScore(
      state,
      context.profile,
    );
    score *= (1.0 + personalityAlignment * 0.3);

    final contextBonus = _getContextRelevanceBonus(state, context);
    score *= (1.0 + contextBonus);

    if (context.fatigue > 0.6) {
      if (state == PetState.sleep) {
        score *= (1.0 + (context.fatigue - 0.6) * 10.0);
      } else if (state == PetState.resting) {
        score *= (1.0 + (context.fatigue - 0.6) * 5.0);
      } else if (state == PetState.run ||
          state == PetState.playing ||
          state == PetState.jumping) {
        score *= (1.0 - context.fatigue); // heavily penalize high energy states
      }
    }

    final double workHours = context.totalWorkToday.inSeconds / 3600.0;
    if (workHours >= 3.0) {
      final double fatigueMultiplier = 1.0 + (workHours - 3.0) * 1.5;
      if (state == PetState.sleep) {
        score *= (1.5 * fatigueMultiplier);
      } else if (state == PetState.resting) {
        score *= (1.2 * fatigueMultiplier);
      } else if (state == PetState.run ||
          state == PetState.playing ||
          state == PetState.jumping) {
        score /= (1.2 * fatigueMultiplier); // heavily penalize active states
      }
    }

    if (context.curiosity > 0.6) {
      if (state == PetState.following ||
          state == PetState.interacting ||
          state == PetState.curious ||
          state == PetState.exploring) {
        score *= (1.0 + (context.curiosity - 0.6) * 6.0);
      }
    }

    if (context.boredom > 0.5) {
      if (state == PetState.exploring ||
          state == PetState.walk ||
          state == PetState.playing ||
          state == PetState.bored) {
        score *= (1.0 + (context.boredom - 0.5) * 4.0);
      }
    }

    score *= (0.8 + _random.nextDouble() * 0.4);

    return score.clamp(0.1, 10.0);
  }

  double _getMoodAlignmentScore(PetState state, PetMoodState mood) {
    switch (state) {
      case PetState.playing:
      case PetState.dancing:
      case PetState.celebrating:
        return mood.mood == PetMood.playful || mood.mood == PetMood.happy
            ? 1.0
            : 0.2;
      case PetState.sleep:
      case PetState.resting:
        return mood.mood == PetMood.tired || mood.mood == PetMood.relaxed
            ? 1.0
            : 0.3;
      case PetState.interacting:
      case PetState.affectionate:
        return mood.mood == PetMood.affectionate ? 1.0 : 0.4;
      case PetState.curious:
      case PetState.exploring:
        return mood.mood == PetMood.curious ? 1.0 : 0.5;
      case PetState.hiding:
      case PetState.scared:
        return mood.mood == PetMood.scared ? 1.0 : 0.2;
      case PetState.grooming:
      case PetState.stretch:
      case PetState.blink:
        return mood.mood == PetMood.relaxed ? 1.0 : 0.5;
      default:
        return 0.5;
    }
  }

  double _getPersonalityAlignmentScore(PetState state, dynamic profile) {
    final personality = profile.personality;
    switch (state) {
      case PetState.run:
      case PetState.jumping:
      case PetState.playing:
      case PetState.walk:
      case PetState.stretch:
        return personality.activityLevel;
      case PetState.sleep:
      case PetState.resting:
        return 1.0 - personality.activityLevel;
      case PetState.interacting:
      case PetState.affectionate:
        return personality.sociability;
      case PetState.hiding:
      case PetState.quiet:
        return personality.skittishness;
      case PetState.exploring:
      case PetState.curious:
        return personality.curiosity;
      case PetState.idle:
      case PetState.grooming:
      case PetState.blink:
        return personality.independence;
      default:
        return 0.5;
    }
  }

  double _getContextRelevanceBonus(PetState state, PetBehaviorContext context) {
    switch (state) {
      case PetState.celebrating:
      case PetState.dancing:
        return context.isBreakActive ? 2.0 : 0.0;
      case PetState.sleep:
      case PetState.hiding:
        return context.isMeetingDetected ? 2.0 : 0.0;
      case PetState.interacting:
      case PetState.following:
        return context.isCursorNearby ? 1.5 : 0.0;
      case PetState.turning:
        return context.isNearScreenEdge ? 1.0 : 0.0;
      default:
        return 0.0;
    }
  }

  void recordStateSelection(PetState state) {
    _lastStateTimes[state] = DateTime.now();
    _stateFrequency[state] = (_stateFrequency[state] ?? 0) + 1;

    // Decay old frequencies to prevent permanent bias
    if (_stateFrequency.length > 20) {
      _stateFrequency.updateAll((key, value) => (value * 0.9).round());
    }
  }

  void reset() {
    _lastStateTimes.clear();
    _stateFrequency.clear();
  }
}
