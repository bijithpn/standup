import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/simple_prefs.dart';
import '../../../core/utils/logger.dart';
import '../../../features/settings/settings_repository.dart';
import 'pet_state_machine.dart';

/// Immutable value object that tracks the four core need dimensions of the
/// companion pet. All values are clamped to the closed interval [0.0, 1.0].
///
/// Persisted as a flat JSON object under the key `pet_needs` in
/// `SettingsRepository`.
///
/// Requirements: 10.1, 10.9
@immutable
class PetNeeds {
  /// Creates a [PetNeeds] instance.
  ///
  /// All parameters default to 0.5, which is the neutral resting value
  /// used when no persisted data exists (Req 10.9).
  const PetNeeds({
    this.affection = 0.5,
    this.playfulness = 0.5,
    this.energy = 0.5,
    this.restfulness = 0.5,
  });

  /// Degree to which the pet feels loved. Range: [0.0, 1.0].
  final double affection;

  /// Degree to which the pet wants to play. Range: [0.0, 1.0].
  final double playfulness;

  /// Current energy level. Range: [0.0, 1.0].
  final double energy;

  /// How rested the pet is. Range: [0.0, 1.0].
  final double restfulness;

  // ---------------------------------------------------------------------------
  // Mutation helpers
  // ---------------------------------------------------------------------------

  /// Returns a new [PetNeeds] replacing any provided fields and clamping all
  /// four values to [0.0, 1.0].
  ///
  /// Unspecified fields keep their current (already-clamped) values.
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

  /// Returns a new [PetNeeds] with each field incremented by the corresponding
  /// delta, clamping every result to [0.0, 1.0].
  ///
  /// Omitted delta parameters default to 0.0 (no change for that field).
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

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Serialises this instance to a flat JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'affection': affection,
      'playfulness': playfulness,
      'energy': energy,
      'restfulness': restfulness,
    };
  }

  /// Deserialises a [PetNeeds] from [json].
  ///
  /// Any missing or malformed field falls back to 0.5 (the default neutral
  /// value required by Req 10.9).
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

  // ---------------------------------------------------------------------------
  // Object overrides
  // ---------------------------------------------------------------------------

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

// =============================================================================
// NeedsEngine
// =============================================================================

/// Stateful service that owns one [PetNeeds] instance and applies tick-based
/// decay, activity-driven mutations, and persistence.
///
/// All arithmetic is forwarded to [PetNeeds.applyDelta] which clamps every
/// result to [0.0, 1.0], satisfying Req 10.1.
///
/// Requirements: 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9
class NeedsEngine {
  NeedsEngine({SettingsRepository? settingsRepository, AppLogger? logger})
    : // SettingsRepository is accepted to honour the design contract but
      // persistence is performed via SimplePrefs — the same KV layer the
      // repository falls back to — which is accessible from secondary
      // isolates / companion contexts.
      // ignore: unused_field
      _settingsRepository = settingsRepository,
      _logger = logger ?? AppLogger();

  // ignore: unused_field
  final SettingsRepository? _settingsRepository;
  final AppLogger _logger;

  // ── State ─────────────────────────────────────────────────────────────────

  PetNeeds _needs = const PetNeeds();

  /// The current [PetNeeds] snapshot.
  PetNeeds get current => _needs;

  // ── Active-state duration tracking ───────────────────────────────────────

  /// Cumulative time spent in active-movement states (walk/run/chasing/playing).
  ///
  /// Resets to zero when the pet exits all active-movement states.
  double _activeMovementElapsed = 0.0;

  /// Cumulative time spent in rest/sleep states.
  ///
  /// Resets to zero when the pet exits all rest/sleep states.
  double _restElapsed = 0.0;

  // ── Persistence key ───────────────────────────────────────────────────────

  static const String _persistKey = 'pet_needs';

  // ── State classification helpers ──────────────────────────────────────────

  static const Set<PetState> _activeMovementStates = {
    PetState.walk,
    PetState.run,
    PetState.chasing,
    PetState.playing,
  };

  static const Set<PetState> _restStates = {PetState.sleep, PetState.resting};

  // ── Thresholds ────────────────────────────────────────────────────────────

  /// Cumulative active-movement time required before energy drain starts (Req 10.5).
  static const double _activeMovementThresholdSeconds = 60.0;

  /// Energy drain rate while in active-movement states after threshold (Req 10.5).
  static const double _activeMovementDrainPerSecond = 0.01;

  /// Cumulative rest time required before restfulness regen starts (Req 10.6).
  static const double _restThresholdSeconds = 30.0;

  /// Restfulness regen rate while resting after threshold (Req 10.6).
  static const double _restRegenPerSecond = 0.005;

  /// Long-session threshold in seconds (50 min) (Req 10.7).
  static const double _longSessionThresholdSeconds = 50 * 60.0;

  /// Energy drain per minute beyond the long-session threshold (Req 10.7).
  static const double _longSessionDrainPerMinute = 0.005;

  /// Idle decay rate toward 0.5 (Req 10.8).
  static const double _idleDecayPerSecond = 0.001;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Called each frame by [CompanionGame.update()].
  ///
  /// Applies in order:
  /// 1. Idle decay toward 0.5 at [_idleDecayPerSecond] (Req 10.8).
  /// 2. Active-movement energy drain once cumulative time ≥ 60 s (Req 10.5).
  /// 3. Rest/sleep restfulness regen once cumulative time ≥ 30 s (Req 10.6).
  /// 4. Long-session energy drain for each minute beyond 50 min (Req 10.7).
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

    // ── 1. Idle decay (Req 10.8) ─────────────────────────────────────────
    // Decay applies when not in eating/chasing/fetching and no petting session.
    final isExemptFromDecay =
        isPettingActive ||
        currentState == PetState.eating ||
        currentState == PetState.chasing ||
        currentState == PetState.fetching;

    if (!isExemptFromDecay) {
      // For each need, decay toward 0.5.
      // If value > 0.5: subtract rate * dt (move toward 0.5).
      // If value < 0.5: add rate * dt (move toward 0.5).
      // If value == 0.5: no change.
      // The applyDelta clamping will prevent overshoot.
      final decayAmount = _idleDecayPerSecond * dt;

      affectionDelta += _decayDelta(_needs.affection, decayAmount);
      playfulnessDelta += _decayDelta(_needs.playfulness, decayAmount);
      energyDelta += _decayDelta(_needs.energy, decayAmount);
      restfulnessDelta += _decayDelta(_needs.restfulness, decayAmount);
    }

    // ── 2. Active-movement duration tracking and drain (Req 10.5) ────────
    if (isActiveMovement) {
      _activeMovementElapsed += dt;
      if (_activeMovementElapsed >= _activeMovementThresholdSeconds) {
        energyDelta -= _activeMovementDrainPerSecond * dt;
      }
    } else {
      _activeMovementElapsed = 0.0;
    }

    // ── 3. Rest/sleep duration tracking and regen (Req 10.6) ─────────────
    if (isResting) {
      _restElapsed += dt;
      if (_restElapsed >= _restThresholdSeconds) {
        restfulnessDelta += _restRegenPerSecond * dt;
      }
    } else {
      _restElapsed = 0.0;
    }

    // ── 4. Long-session drain (Req 10.7) ─────────────────────────────────
    final elapsedSeconds = workSessionElapsed.inSeconds.toDouble();
    if (elapsedSeconds > _longSessionThresholdSeconds) {
      final minutesBeyondThreshold =
          (elapsedSeconds - _longSessionThresholdSeconds) / 60.0;
      energyDelta -= _longSessionDrainPerMinute * minutesBeyondThreshold * dt;
    }

    // Apply all deltas at once.
    _needs = _needs.applyDelta(
      affectionDelta: affectionDelta,
      playfulnessDelta: playfulnessDelta,
      energyDelta: energyDelta,
      restfulnessDelta: restfulnessDelta,
    );
  }

  /// Called by [InteractionController] when the user pets the companion.
  ///
  /// Increases affection by 0.1, clamped to 1.0 (Req 10.2).
  void onPetted() {
    _needs = _needs.applyDelta(affectionDelta: 0.1);
    _logger.info('NeedsEngine.onPetted(): affection=${_needs.affection}');
  }

  /// Called by [InteractionController] when a ball throwable is fetched.
  ///
  /// Increases playfulness by 0.15, clamped to 1.0 (Req 10.3).
  void onBallFetched() {
    _needs = _needs.applyDelta(playfulnessDelta: 0.15);
    _logger.info(
      'NeedsEngine.onBallFetched(): playfulness=${_needs.playfulness}',
    );
  }

  /// Called by [InteractionController] when the pet eats a treat.
  ///
  /// Increases energy by 0.15 and affection by 0.1, both clamped to 1.0
  /// (Req 10.4).
  void onTreatEaten() {
    _needs = _needs.applyDelta(energyDelta: 0.15, affectionDelta: 0.1);
    _logger.info(
      'NeedsEngine.onTreatEaten(): '
      'energy=${_needs.energy} affection=${_needs.affection}',
    );
  }

  /// Called when a work block has exceeded the 50-minute threshold.
  ///
  /// Decreases energy by 0.005 per minute beyond the 50-minute threshold
  /// (Req 10.7). [minutesBeyondThreshold] is the number of elapsed minutes
  /// past the threshold.
  void onWorkBlockLong({double minutesBeyondThreshold = 1.0}) {
    final drain = _longSessionDrainPerMinute * minutesBeyondThreshold;
    _needs = _needs.applyDelta(energyDelta: -drain);
    _logger.info(
      'NeedsEngine.onWorkBlockLong(): '
      'drain=$drain energy=${_needs.energy}',
    );
  }

  // ── Persistence (Req 10.9) ────────────────────────────────────────────────

  /// Persists the current [PetNeeds] to the KV store under key [_persistKey].
  ///
  /// Called by [CompanionGame.onRemove] / app close.
  void persist() {
    try {
      final json = jsonEncode(_needs.toJson());
      SimplePrefs.instance.setString(_persistKey, json);
      _logger.info('NeedsEngine.persist(): $json');
    } catch (e, st) {
      _logger.error('NeedsEngine.persist() failed: $e', stackTrace: st);
    }
  }

  /// Restores [PetNeeds] from the KV store.
  ///
  /// If no persisted data exists, [_needs] remains at the default (all 0.5),
  /// satisfying Req 10.9.  Called by [CompanionGame.onLoad].
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
      // Fall back to defaults on any error.
      _needs = const PetNeeds();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Computes the signed decay delta that moves [value] toward 0.5 by
  /// [amount] without overshooting.
  ///
  /// Returns:
  /// - `-min(amount, value - 0.5)` when value > 0.5
  /// - `+min(amount, 0.5 - value)` when value < 0.5
  /// - `0.0` when value == 0.5
  static double _decayDelta(double value, double amount) {
    if (value > 0.5) {
      return -(amount.clamp(0.0, value - 0.5));
    } else if (value < 0.5) {
      return amount.clamp(0.0, 0.5 - value);
    }
    return 0.0;
  }
}
