import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'pet_mood.dart';
import 'pet_personality.dart';

/// Generic pet state for the FSM.
enum PetState {
  idle,
  blink,
  stretch,
  walk,
  run,
  sleep,
  alert,
  happy,
  drag,
  breakReminder,
  meetingPaused,
  focusMode,
  curious,
  excited,
  sad,
  grooming,
  playing,
  eating,
  celebrating,
  dancing,
  hiding,
  quiet,
  interacting,
  following,
  jumping,
  affectionate,
  turning,
  resting,
  bored,
  exploring,
  scared,
}

/// Generic pet events that trigger state transitions.
enum PetEvent {
  tick,
  userClick,
  userDoubleClick,
  userHover,
  userDragStart,
  userDragEnd,
  breakStarted,
  breakEnded,
  meetingDetected,
  meetingEnded,
  focusModeOn,
  focusModeOff,
  idleTimeout,
  activityDetected,
  randomBehavior,
  cursorNearby,
  cursorLeft,
  notificationReceived,
  breakCompleted,
  petFed,
  petPlayed,
}

/// Weighted transition with conditions.
class PetTransition {
  final PetEvent event;
  final PetState targetState;
  final double weight; // Higher = more likely when multiple transitions match
  final Duration? minDuration; // Minimum time in current state before this transition
  final Duration? cooldown; // Cooldown after this transition fires
  final bool Function(PetMoodState? currentMood, PetPersonality personality)? condition;

  const PetTransition({
    required this.event,
    required this.targetState,
    this.weight = 1.0,
    this.minDuration,
    this.cooldown,
    this.condition,
  });
}

/// Abstracted state machine with weighted transitions and mood awareness.
class PetStateMachine extends ChangeNotifier {
  PetStateMachine({
    PetPersonality? personality,
    void Function(PetState)? onStateChanged,
  })  : personality = personality ?? const PetPersonality(),
        _onStateChanged = onStateChanged;

  final PetPersonality personality;
  final void Function(PetState)? _onStateChanged;

  PetState _currentState = PetState.idle;
  DateTime? _stateEnteredAt;
  Duration? _minStateDuration;
  final Map<PetTransition, DateTime> _lastTriggered = {};
  PetMoodState? _currentMood;

  PetState get currentState => _currentState;
  Duration get timeInState =>
      _stateEnteredAt != null ? DateTime.now().difference(_stateEnteredAt!) : Duration.zero;
  bool get canTransition =>
      _minStateDuration == null || timeInState >= _minStateDuration!;
  PetMoodState? get currentMood => _currentMood;

  /// Stream of state changes for reactive listening.
  Stream<PetState> get stateStream => _stateController.stream;
  final StreamController<PetState> _stateController = StreamController<PetState>.broadcast();

  /// Set the current mood state.
  void setMood(PetMoodState mood) {
    _currentMood = mood;
  }

  /// Get transitions for the current state.
  List<PetTransition> _getTransitions() {
    return _baseTransitions[_currentState] ?? [];
  }

  /// Handle an event and potentially transition to a new state.
  void handleEvent(PetEvent event) {
    final transitions = _getTransitions();
    final matchingTransitions = transitions.where((t) {
      if (t.event != event) return false;
      if (t.minDuration != null && timeInState < t.minDuration!) return false;
      final lastTriggered = _lastTriggered[t];
      if (t.cooldown != null &&
          lastTriggered != null &&
          DateTime.now().difference(lastTriggered) < t.cooldown!) {
        return false;
      }
      if (t.condition != null && !t.condition!(_currentMood, personality)) return false;
      return true;
    }).toList();

    if (matchingTransitions.isEmpty) return;

    // If multiple transitions match, pick based on weight
    PetTransition selected;
    if (matchingTransitions.length == 1) {
      selected = matchingTransitions.first;
    } else {
      final totalWeight = matchingTransitions.fold<double>(0, (sum, t) => sum + t.weight);
      final random = Random().nextDouble() * totalWeight;
      double cumulative = 0;
      selected = matchingTransitions.first;
      for (final t in matchingTransitions) {
        cumulative += t.weight;
        if (random <= cumulative) {
          selected = t;
          break;
        }
      }
    }

    _transitionTo(selected.targetState, selected);
  }

  void _transitionTo(PetState newState, [PetTransition? transition]) {
    if (_currentState == newState) return;
    _currentState = newState;
    _stateEnteredAt = DateTime.now();
    _minStateDuration = transition?.minDuration;
    if (transition != null) {
      _lastTriggered[transition] = DateTime.now();
    }
    _onStateChanged?.call(newState);
    notifyListeners();
  }

  /// Base transition table - can be extended/overridden by species-specific implementations.
  static final Map<PetState, List<PetTransition>> _baseTransitions = {
    PetState.idle: [
      PetTransition(event: PetEvent.userClick, targetState: PetState.alert, weight: 1.0, minDuration: const Duration(milliseconds: 500)),
      PetTransition(event: PetEvent.userDoubleClick, targetState: PetState.happy, weight: 1.0, minDuration: const Duration(milliseconds: 500)),
      PetTransition(event: PetEvent.userHover, targetState: PetState.alert, weight: 0.8, minDuration: const Duration(milliseconds: 200)),
      PetTransition(event: PetEvent.userDragStart, targetState: PetState.drag, weight: 1.0),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
      PetTransition(event: PetEvent.meetingDetected, targetState: PetState.meetingPaused, weight: 1.0),
      PetTransition(event: PetEvent.focusModeOn, targetState: PetState.focusMode, weight: 1.0),
      PetTransition(event: PetEvent.idleTimeout, targetState: PetState.sleep, weight: 1.0),
      PetTransition(event: PetEvent.cursorNearby, targetState: PetState.curious, weight: 0.7),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.blink,
        weight: 3.0,
        condition: (mood, personality) => personality.playfulness < 0.5,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.stretch,
        weight: 2.0,
        condition: (mood, personality) => personality.activityLevel > 0.6,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.walk,
        weight: 2.0,
        condition: (mood, personality) => personality.activityLevel > 0.4,
      ),
    ],
    PetState.blink: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(milliseconds: 300)),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.stretch: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 2)),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.walk: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 3)),
      PetTransition(event: PetEvent.userClick, targetState: PetState.alert, weight: 1.0),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.run: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 2)),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.sleep: [
      PetTransition(event: PetEvent.activityDetected, targetState: PetState.idle, weight: 1.0),
      PetTransition(event: PetEvent.userClick, targetState: PetState.alert, weight: 0.8, minDuration: const Duration(seconds: 2)),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.alert: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(milliseconds: 1500)),
      PetTransition(event: PetEvent.userDoubleClick, targetState: PetState.happy, weight: 1.0),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.happy: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 2)),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.drag: [
      PetTransition(event: PetEvent.userDragEnd, targetState: PetState.idle, weight: 1.0),
    ],
    PetState.breakReminder: [
      PetTransition(event: PetEvent.breakEnded, targetState: PetState.happy, weight: 1.0, minDuration: const Duration(seconds: 3)),
      PetTransition(event: PetEvent.meetingDetected, targetState: PetState.meetingPaused, weight: 1.0),
    ],
    PetState.meetingPaused: [
      PetTransition(event: PetEvent.meetingEnded, targetState: PetState.idle, weight: 1.0),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.focusMode: [
      PetTransition(event: PetEvent.focusModeOff, targetState: PetState.idle, weight: 1.0),
      PetTransition(event: PetEvent.breakStarted, targetState: PetState.breakReminder, weight: 1.0),
    ],
    PetState.curious: [
      PetTransition(event: PetEvent.cursorLeft, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(milliseconds: 500)),
      PetTransition(event: PetEvent.userClick, targetState: PetState.happy, weight: 1.0),
    ],
    PetState.excited: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 3)),
    ],
    PetState.sad: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 4)),
      PetTransition(event: PetEvent.petPlayed, targetState: PetState.happy, weight: 1.0),
    ],
    PetState.grooming: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 3)),
    ],
    PetState.playing: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 5)),
    ],
    PetState.eating: [
      PetTransition(event: PetEvent.tick, targetState: PetState.idle, weight: 1.0, minDuration: const Duration(seconds: 4)),
    ],
  };
}
