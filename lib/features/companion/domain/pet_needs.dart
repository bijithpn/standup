import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/simple_prefs.dart';
import '../../../core/utils/logger.dart';
import '../../../features/settings/settings_repository.dart';
import 'pet_state_machine.dart';

@immutable
class PetNeeds {
  const PetNeeds({
    this.affection = 0.5,
    this.playfulness = 0.5,
    this.energy = 0.5,
    this.restfulness = 0.5,
  });

  final double affection;

  final double playfulness;

  final double energy;

  final double restfulness;

  PetNeeds copyWith({
    double? affection,
    double? playfulness,
    double? energy,
    double? restfulness,
  }) {
    return PetNeeds(
      affection: (affection ?? this.affection).clamp(0.0, 1.0),
      playfulness: (playfulness ?? this.playfulness).clamp(0.0, 1.0),
      energy: (energy ?? this.energy).clamp(0.0, 1.0),
      restfulness: (restfulness ?? this.restfulness).clamp(0.0, 1.0),
    );
  }

  PetNeeds applyDelta({
    double affectionDelta = 0.0,
    double playfulnessDelta = 0.0,
    double energyDelta = 0.0,
    double restfulnessDelta = 0.0,
  }) {
    return PetNeeds(
      affection: (affection + affectionDelta).clamp(0.0, 1.0),
      playfulness: (playfulness + playfulnessDelta).clamp(0.0, 1.0),
      energy: (energy + energyDelta).clamp(0.0, 1.0),
      restfulness: (restfulness + restfulnessDelta).clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'affection': affection,
      'playfulness': playfulness,
      'energy': energy,
      'restfulness': restfulness,
    };
  }

  factory PetNeeds.fromJson(Map<String, dynamic> json) {
    return PetNeeds(
      affection: (json['affection'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
      playfulness:
          (json['playfulness'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
      energy: (json['energy'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
      restfulness:
          (json['restfulness'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PetNeeds &&
        other.affection == affection &&
        other.playfulness == playfulness &&
        other.energy == energy &&
        other.restfulness == restfulness;
  }

  @override
  int get hashCode => Object.hash(affection, playfulness, energy, restfulness);

  @override
  String toString() =>
      'PetNeeds(affection: $affection, playfulness: $playfulness, '
      'energy: $energy, restfulness: $restfulness)';
}

class NeedsEngine {
  NeedsEngine({SettingsRepository? settingsRepository, AppLogger? logger})
    : _logger = logger ?? AppLogger();

  final AppLogger _logger;

  PetNeeds _needs = const PetNeeds();

  PetNeeds get current => _needs;

  double _activeMovementElapsed = 0.0;

  double _restElapsed = 0.0;

  static const String _persistKey = 'pet_needs';

  static const Set<PetState> _activeMovementStates = {
    PetState.walk,
    PetState.run,
    PetState.chasing,
    PetState.playing,
  };

  static const Set<PetState> _restStates = {PetState.sleep, PetState.resting};

  static const double _activeMovementThresholdSeconds = 60.0;

  static const double _activeMovementDrainPerSecond = 0.01;

  static const double _restThresholdSeconds = 30.0;

  static const double _restRegenPerSecond = 0.005;

  static const double _longSessionThresholdSeconds = 50 * 60.0;

  static const double _longSessionDrainPerMinute = 0.005;

  static const double _idleDecayPerSecond = 0.001;

  void tick(
    double dt,
    PetState currentState,
    bool isPettingActive,
    Duration workSessionElapsed,
  ) {
    if (dt <= 0) return;

    double affectionDelta = 0.0;
    double playfulnessDelta = 0.0;
    double energyDelta = 0.0;
    double restfulnessDelta = 0.0;

    final isActiveMovement = _activeMovementStates.contains(currentState);
    final isResting = _restStates.contains(currentState);

    final isExemptFromDecay =
        isPettingActive ||
        currentState == PetState.eating ||
        currentState == PetState.chasing ||
        currentState == PetState.fetching;

    if (!isExemptFromDecay) {
      final decayAmount = _idleDecayPerSecond * dt;

      affectionDelta += _decayDelta(_needs.affection, decayAmount);
      playfulnessDelta += _decayDelta(_needs.playfulness, decayAmount);
      energyDelta += _decayDelta(_needs.energy, decayAmount);
      restfulnessDelta += _decayDelta(_needs.restfulness, decayAmount);
    }

    if (isActiveMovement) {
      _activeMovementElapsed += dt;
      if (_activeMovementElapsed >= _activeMovementThresholdSeconds) {
        energyDelta -= _activeMovementDrainPerSecond * dt;
      }
    } else {
      _activeMovementElapsed = 0.0;
    }

    if (isResting) {
      _restElapsed += dt;
      if (_restElapsed >= _restThresholdSeconds) {
        restfulnessDelta += _restRegenPerSecond * dt;
      }
    } else {
      _restElapsed = 0.0;
    }

    final elapsedSeconds = workSessionElapsed.inSeconds.toDouble();
    if (elapsedSeconds > _longSessionThresholdSeconds) {
      final minutesBeyondThreshold =
          (elapsedSeconds - _longSessionThresholdSeconds) / 60.0;
      energyDelta -= _longSessionDrainPerMinute * minutesBeyondThreshold * dt;
    }

    _needs = _needs.applyDelta(
      affectionDelta: affectionDelta,
      playfulnessDelta: playfulnessDelta,
      energyDelta: energyDelta,
      restfulnessDelta: restfulnessDelta,
    );
  }

  void onPetted() {
    _needs = _needs.applyDelta(affectionDelta: 0.1);
    _logger.info('NeedsEngine.onPetted(): affection=${_needs.affection}');
  }

  void onBallFetched() {
    _needs = _needs.applyDelta(playfulnessDelta: 0.15);
    _logger.info(
      'NeedsEngine.onBallFetched(): playfulness=${_needs.playfulness}',
    );
  }

  void onTreatEaten() {
    _needs = _needs.applyDelta(energyDelta: 0.15, affectionDelta: 0.1);
    _logger.info(
      'NeedsEngine.onTreatEaten(): '
      'energy=${_needs.energy} affection=${_needs.affection}',
    );
  }

  void onWorkBlockLong({double minutesBeyondThreshold = 1.0}) {
    final drain = _longSessionDrainPerMinute * minutesBeyondThreshold;
    _needs = _needs.applyDelta(energyDelta: -drain);
    _logger.info(
      'NeedsEngine.onWorkBlockLong(): '
      'drain=$drain energy=${_needs.energy}',
    );
  }

  void persist() {
    try {
      final json = jsonEncode(_needs.toJson());
      SimplePrefs.instance.setString(_persistKey, json);
      _logger.info('NeedsEngine.persist(): $json');
    } catch (e, st) {
      _logger.error('NeedsEngine.persist() failed: $e', stackTrace: st);
    }
  }

  void restore() {
    try {
      final raw = SimplePrefs.instance.getString(_persistKey);
      if (raw.isEmpty) {
        _logger.info(
          'NeedsEngine.restore(): no persisted data, using defaults',
        );
        return;
      }
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        _needs = PetNeeds.fromJson(map);
        _logger.info('NeedsEngine.restore(): $_needs');
      }
    } catch (e, st) {
      _logger.error('NeedsEngine.restore() failed: $e', stackTrace: st);
      _needs = const PetNeeds();
    }
  }

  static double _decayDelta(double value, double amount) {
    if (value > 0.5) {
      return -(amount.clamp(0.0, value - 0.5));
    } else if (value < 0.5) {
      return amount.clamp(0.0, 0.5 - value);
    }
    return 0.0;
  }
}
