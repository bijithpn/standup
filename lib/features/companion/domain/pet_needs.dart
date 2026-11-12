import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/simple_prefs.dart';
import '../../../app/dependency_injection.dart';
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
    this.hunger = 0.0,
    this.boredom = 0.0,
    this.happiness = 50.0,
    this.breakMode = false,
  });

  final double affection;
  final double playfulness;
  final double energy;
  final double restfulness;
  final double hunger;
  final double boredom;
  final double happiness;
  final bool breakMode;

  double get energyLevel => energy <= 1.0 ? energy * 100.0 : energy;
  double get hungerNormalized => (hunger / 100.0).clamp(0.0, 1.0);
  double get boredomNormalized => (boredom / 100.0).clamp(0.0, 100.0);
  double get happinessNormalized => (happiness / 100.0).clamp(0.0, 1.0);

  PetNeeds copyWith({
    double? affection,
    double? playfulness,
    double? energy,
    double? restfulness,
    double? hunger,
    double? boredom,
    double? happiness,
    bool? breakMode,
  }) {
    return PetNeeds(
      affection: (affection ?? this.affection).clamp(0.0, 1.0),
      playfulness: (playfulness ?? this.playfulness).clamp(0.0, 1.0),
      energy: (energy ?? this.energy).clamp(0.0, 1.0),
      restfulness: (restfulness ?? this.restfulness).clamp(0.0, 1.0),
      hunger: (hunger ?? this.hunger).clamp(0.0, 100.0),
      boredom: (boredom ?? this.boredom).clamp(0.0, 100.0),
      happiness: (happiness ?? this.happiness).clamp(0.0, 100.0),
      breakMode: breakMode ?? this.breakMode,
    );
  }

  PetNeeds applyDelta({
    double affectionDelta = 0.0,
    double playfulnessDelta = 0.0,
    double energyDelta = 0.0,
    double restfulnessDelta = 0.0,
    double hungerDelta = 0.0,
    double boredomDelta = 0.0,
    double happinessDelta = 0.0,
    bool? breakMode,
  }) {
    return PetNeeds(
      affection: (affection + affectionDelta).clamp(0.0, 1.0),
      playfulness: (playfulness + playfulnessDelta).clamp(0.0, 1.0),
      energy: (energy + energyDelta).clamp(0.0, 1.0),
      restfulness: (restfulness + restfulnessDelta).clamp(0.0, 1.0),
      hunger: (hunger + hungerDelta).clamp(0.0, 100.0),
      boredom: (boredom + boredomDelta).clamp(0.0, 100.0),
      happiness: (happiness + happinessDelta).clamp(0.0, 100.0),
      breakMode: breakMode ?? this.breakMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'affection': affection,
      'playfulness': playfulness,
      'energy': energy,
      'restfulness': restfulness,
      'hunger': hunger,
      'boredom': boredom,
      'happiness': happiness,
      'breakMode': breakMode,
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
      hunger: (json['hunger'] as num?)?.toDouble().clamp(0.0, 100.0) ?? 0.0,
      boredom: (json['boredom'] as num?)?.toDouble().clamp(0.0, 100.0) ?? 0.0,
      happiness:
          (json['happiness'] as num?)?.toDouble().clamp(0.0, 100.0) ?? 50.0,
      breakMode: json['breakMode'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PetNeeds &&
        other.affection == affection &&
        other.playfulness == playfulness &&
        other.energy == energy &&
        other.restfulness == restfulness &&
        other.hunger == hunger &&
        other.boredom == boredom &&
        other.happiness == happiness &&
        other.breakMode == breakMode;
  }

  @override
  int get hashCode => Object.hash(
    affection,
    playfulness,
    energy,
    restfulness,
    hunger,
    boredom,
    happiness,
    breakMode,
  );

  @override
  String toString() =>
      'PetNeeds(affection: $affection, playfulness: $playfulness, '
      'energy: $energy, restfulness: $restfulness, hunger: $hunger, '
      'boredom: $boredom, happiness: $happiness, breakMode: $breakMode)';
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

  void setHunger(double value) {
    _needs = _needs.copyWith(hunger: value);
  }

  void setBoredom(double value) {
    _needs = _needs.copyWith(boredom: value);
  }

  void setHappiness(double value) {
    _needs = _needs.copyWith(happiness: value);
  }

  void setBreakMode(bool active) {
    _needs = _needs.copyWith(breakMode: active);
  }

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
    double hungerDelta = 0.0;
    double boredomDelta = 0.0;
    double happinessDelta = 0.0;

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

    // Passive hunger and boredom tick
    if (currentState != PetState.eating) {
      hungerDelta += 0.15 * dt;
    }

    if (currentState == PetState.idle || currentState == PetState.resting) {
      boredomDelta += 0.25 * dt;
    } else if (currentState == PetState.playing ||
        currentState == PetState.chasing ||
        currentState == PetState.celebrating) {
      boredomDelta -= 0.5 * dt;
    }

    // Happiness decays slowly towards 50
    if (_needs.happiness > 50.0) {
      happinessDelta -= (0.1 * dt).clamp(0.0, _needs.happiness - 50.0);
    } else if (_needs.happiness < 50.0) {
      happinessDelta += (0.1 * dt).clamp(0.0, 50.0 - _needs.happiness);
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
      hungerDelta: hungerDelta,
      boredomDelta: boredomDelta,
      happinessDelta: happinessDelta,
    );
  }

  void onPetted() {
    onPetting();
  }

  void onPetting() {
    _needs = _needs.applyDelta(
      affectionDelta: 0.1,
      happinessDelta: 15.0,
      boredomDelta: -10.0,
    );
    _logger.info(
      'NeedsEngine.onPetting(): affection=${_needs.affection} happiness=${_needs.happiness}',
    );
  }

  void onBallFetched() {
    onPlayToy();
  }

  void onPlayToy() {
    _needs = _needs.applyDelta(
      playfulnessDelta: 0.15,
      happinessDelta: 20.0,
      boredomDelta: -25.0,
      hungerDelta: 5.0,
    );
    _logger.info(
      'NeedsEngine.onPlayToy(): playfulness=${_needs.playfulness} boredom=${_needs.boredom}',
    );
  }

  void onTreatEaten() {
    onFedTreat();
  }

  void onFedTreat() {
    _needs = _needs.applyDelta(
      energyDelta: 0.15,
      affectionDelta: 0.1,
      hungerDelta: -30.0,
      happinessDelta: 15.0,
    );
    _logger.info(
      'NeedsEngine.onFedTreat(): '
      'energy=${_needs.energy} affection=${_needs.affection} hunger=${_needs.hunger}',
    );
  }

  void onBreakStarted() {
    _needs = _needs
        .copyWith(breakMode: true)
        .applyDelta(restfulnessDelta: 0.1, happinessDelta: 10.0);
    _logger.info('NeedsEngine.onBreakStarted()');
  }

  void onBreakCompleted() {
    _needs = _needs
        .copyWith(breakMode: false)
        .applyDelta(happinessDelta: 20.0, affectionDelta: 0.1);
    _logger.info(
      'NeedsEngine.onBreakCompleted(): happiness=${_needs.happiness}',
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
      if (sl.isRegistered<StorageService>()) {
        sl<StorageService>().setString(_persistKey, json);
      } else {
        SimplePrefs.instance.setString(_persistKey, json);
      }
      _logger.info('NeedsEngine.persist(): $json');
    } catch (e, st) {
      _logger.error('NeedsEngine.persist() failed: $e', stackTrace: st);
    }
  }

  void restore() {
    try {
      final String raw;
      if (sl.isRegistered<StorageService>()) {
        raw = sl<StorageService>().getString(_persistKey);
      } else {
        raw = SimplePrefs.instance.getString(_persistKey, defaultValue: '');
      }
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
