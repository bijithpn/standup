import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'pet_mood.dart';
import 'pet_personality.dart';
import 'behavior_engine_models.dart';
import '../../../core/utils/logger.dart';

enum PetState {
  idle,
  blink,
  stretch,
  walk,
  run,
  sleep,
  alert,
  happy,
  angry,
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
  breatheFire,
  fly,
  chasing,
  fetching,
  falling,
  reacting,
}

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
  animationComplete,
  cursorEnteredZone,
  cursorExitedZone,
  cursorDwell,
  cursorFastMove,
  throwableSpawned,
  throwableStationary,
  throwableFetched,
  throwableReturned,
  landedOnSurface,
  windowOverlap,
  windowOverlapEnded,
  surfaceLost,
  loopBlocked,
}

class PetTransition {
  final PetEvent event;
  final PetState targetState;
  final double weight;
  final Duration?
  minDuration;
  final Duration? cooldown;
  final bool Function(PetMoodState? currentMood, PetPersonality personality)?
  condition;

  const PetTransition({
    required this.event,
    required this.targetState,
    this.weight = 1.0,
    this.minDuration,
    this.cooldown,
    this.condition,
  });
}

const Map<PetState, int> _statePriority = {
  PetState.falling: 5,
  PetState.chasing: 4,
  PetState.fetching: 4,
  PetState.run: 3,
  PetState.reacting: 3,
  PetState.walk: 2,
  PetState.resting: 2,
  PetState.idle: 1,
};

class PetStateMachine extends ChangeNotifier {
  PetStateMachine({
    PetPersonality? personality,
    void Function(PetState)? onStateChanged,
  }) : personality = personality ?? const PetPersonality(),
       _onStateChanged = onStateChanged;

  final PetPersonality personality;
  final void Function(PetState)? _onStateChanged;

  PetState _currentState = PetState.idle;
  DateTime? _stateEnteredAt;
  final Map<PetTransition, DateTime> _lastTriggered = {};
  PetMoodState? _currentMood;

  static final _rng = Random();

  PetState? _priorState;

  final List<StateTransitionLog> transitionLog = [];

  static final _logger = AppLogger();

  PetState get currentState => _currentState;
  Duration get timeInState => _stateEnteredAt != null
      ? DateTime.now().difference(_stateEnteredAt!)
      : Duration.zero;
  PetMoodState? get currentMood => _currentMood;

  Stream<PetState> get stateStream => _stateController.stream;
  final StreamController<PetState> _stateController =
      StreamController<PetState>.broadcast();

  void setMood(PetMoodState mood) {
    _currentMood = mood;
  }

  List<PetTransition> _getTransitions() {
    return _baseTransitions[_currentState] ?? [];
  }

  void handleEvent(PetEvent event) {
    final transitions = _getTransitions();
    final now = DateTime.now();
    final elapsed = timeInState;

    PetTransition? selected;
    final List<PetTransition> matched = [];

    for (final t in transitions) {
      if (t.event != event) continue;
      if (t.minDuration != null && elapsed < t.minDuration!) continue;
      if (t.cooldown != null) {
        final last = _lastTriggered[t];
        if (last != null && now.difference(last) < t.cooldown!) continue;
      }
      if (t.condition != null && !t.condition!(_currentMood, personality)) {
        continue;
      }
      matched.add(t);
    }

    if (matched.isEmpty) return;

    if (matched.length == 1) {
      selected = matched.first;
    } else {
      final int maxPriority = matched
          .map((t) => _statePriority[t.targetState] ?? 0)
          .reduce((a, b) => a > b ? a : b);
      final highPriority = matched
          .where((t) => (_statePriority[t.targetState] ?? 0) == maxPriority)
          .toList();

      if (highPriority.length == 1) {
        selected = highPriority.first;
      } else {
        double threshold =
            _rng.nextDouble() *
            highPriority.fold<double>(0, (s, t) => s + t.weight);
        for (final t in highPriority) {
          threshold -= t.weight;
          if (threshold <= 0) {
            selected = t;
            break;
          }
        }
        selected ??= highPriority.last;
      }
    }

    var targetState = selected.targetState;
    if (targetState == PetState.idle &&
        (event == PetEvent.cursorExitedZone ||
            event == PetEvent.windowOverlapEnded)) {
      targetState = _priorState ?? PetState.idle;
    }

    _transitionTo(targetState, selected);
  }

  void transitionTo(PetState newState) {
    _transitionTo(newState);
  }

  void _transitionTo(PetState newState, [PetTransition? transition]) {
    if (_currentState == newState) return;
    final previousState = _currentState;

    if (newState == PetState.reacting) {
      _priorState = previousState;
    }

    _currentState = newState;
    _stateEnteredAt = DateTime.now();
    if (transition != null) _lastTriggered[transition] = DateTime.now();

    final entry = StateTransitionLog(
      previousState: previousState,
      newState: newState,
      utcTimestamp: DateTime.now().toUtc(),
    );
    transitionLog.add(entry);
    _logger.info(jsonEncode(entry.toJson()));

    _onStateChanged?.call(newState);
    _stateController.add(newState);
    notifyListeners();
  }

  @override
  void dispose() {
    _stateController.close();
    super.dispose();
  }

  static final Map<PetState, List<PetTransition>> _baseTransitions = {
    PetState.idle: [
      PetTransition(
        event: PetEvent.userClick,
        targetState: PetState.alert,
        weight: 1.0,
        minDuration: const Duration(milliseconds: 500),
      ),
      PetTransition(
        event: PetEvent.userDoubleClick,
        targetState: PetState.happy,
        weight: 1.0,
        minDuration: const Duration(milliseconds: 500),
      ),
      PetTransition(
        event: PetEvent.userHover,
        targetState: PetState.alert,
        weight: 0.8,
        minDuration: const Duration(milliseconds: 200),
      ),
      PetTransition(
        event: PetEvent.userDragStart,
        targetState: PetState.drag,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.focusModeOn,
        targetState: PetState.focusMode,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.idleTimeout,
        targetState: PetState.sleep,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorNearby,
        targetState: PetState.curious,
        weight: 1.5,
      ),
      PetTransition(
        event: PetEvent.cursorEnteredZone,
        targetState: PetState.reacting,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorFastMove,
        targetState: PetState.run,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.throwableSpawned,
        targetState: PetState.chasing,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.windowOverlap,
        targetState: PetState.reacting,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.blink,
        weight: 3.0,
        cooldown: const Duration(seconds: 8),
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.stretch,
        weight: 1.5,
        cooldown: const Duration(seconds: 30),
        condition: (mood, personality) => personality.activityLevel > 0.3,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.walk,
        weight: 2.5,
        cooldown: const Duration(seconds: 10),
        condition: (mood, personality) => personality.activityLevel > 0.2,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.run,
        weight: 1.0,
        cooldown: const Duration(seconds: 25),
        condition: (mood, personality) => personality.activityLevel > 0.5,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.grooming,
        weight: 1.2,
        cooldown: const Duration(seconds: 20),
        condition: (mood, personality) => personality.independence > 0.4,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.exploring,
        weight: 1.8,
        cooldown: const Duration(seconds: 15),
        condition: (mood, personality) => personality.curiosity > 0.5,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.bored,
        weight: 0.8,
        cooldown: const Duration(seconds: 20),
        condition: (mood, personality) => personality.playfulness > 0.7,
      ),
    ],
    PetState.blink: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(milliseconds: 500),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.stretch: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.walk: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 5),
      ),
      PetTransition(
        event: PetEvent.userClick,
        targetState: PetState.alert,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorNearby,
        targetState: PetState.following,
        weight: 1.2,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorEnteredZone,
        targetState: PetState.reacting,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorFastMove,
        targetState: PetState.run,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.throwableSpawned,
        targetState: PetState.chasing,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.windowOverlap,
        targetState: PetState.reacting,
        weight: 1.0,
      ),
    ],
    PetState.run: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.throwableSpawned,
        targetState: PetState.chasing,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
    ],
    PetState.sleep: [
      PetTransition(
        event: PetEvent.activityDetected,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.userClick,
        targetState: PetState.alert,
        weight: 0.8,
        minDuration: const Duration(seconds: 2),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
    ],
    PetState.alert: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(milliseconds: 2000),
      ),
      PetTransition(
        event: PetEvent.userDoubleClick,
        targetState: PetState.happy,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.happy: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.curious: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
      PetTransition(
        event: PetEvent.cursorLeft,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.userClick,
        targetState: PetState.happy,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.exploring: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 6),
      ),
      PetTransition(
        event: PetEvent.cursorNearby,
        targetState: PetState.curious,
        weight: 1.5,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.walk,
        weight: 1.0,
        cooldown: const Duration(seconds: 10),
      ),
    ],
    PetState.grooming: [
      PetTransition(
        event: PetEvent.animationComplete,
        targetState: PetState.grooming,
        weight: 1.0,
        minDuration: const Duration(milliseconds: 100),
      ),
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
      PetTransition(
        event: PetEvent.activityDetected,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.bored: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.walk,
        weight: 1.5,
        cooldown: const Duration(seconds: 8),
      ),
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.playing,
        weight: 0.8,
        cooldown: const Duration(seconds: 15),
        condition: (mood, personality) => personality.playfulness > 0.5,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.following: [
      PetTransition(
        event: PetEvent.cursorLeft,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 1),
      ),
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 0.5,
        minDuration: const Duration(seconds: 10),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
    ],
    PetState.drag: [
      PetTransition(
        event: PetEvent.userDragEnd,
        targetState: PetState.idle,
        weight: 1.0,
      ),
    ],
    PetState.breakReminder: [
      PetTransition(
        event: PetEvent.breakEnded,
        targetState: PetState.happy,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.meetingPaused: [
      PetTransition(
        event: PetEvent.meetingEnded,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
    ],
    PetState.focusMode: [
      PetTransition(
        event: PetEvent.focusModeOff,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
    ],
    PetState.excited: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
    ],
    PetState.sad: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
      PetTransition(
        event: PetEvent.petPlayed,
        targetState: PetState.happy,
        weight: 1.0,
      ),
    ],
    PetState.playing: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 5),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.meetingDetected,
        targetState: PetState.meetingPaused,
        weight: 1.0,
      ),
    ],
    PetState.eating: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
    ],
    PetState.jumping: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 2),
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
    ],
    PetState.celebrating: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.happy,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
    ],
    PetState.dancing: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.happy,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
    ],
    PetState.hiding: [
      PetTransition(
        event: PetEvent.meetingEnded,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 0.5,
        minDuration: const Duration(seconds: 8),
      ),
    ],
    PetState.quiet: [
      PetTransition(
        event: PetEvent.meetingEnded,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 0.5,
        minDuration: const Duration(seconds: 6),
      ),
    ],
    PetState.interacting: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
      PetTransition(
        event: PetEvent.cursorLeft,
        targetState: PetState.idle,
        weight: 1.0,
      ),
    ],
    PetState.affectionate: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
    ],
    PetState.turning: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.walk,
        weight: 1.0,
        minDuration: const Duration(milliseconds: 800),
      ),
    ],
    PetState.resting: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 5),
      ),
      PetTransition(
        event: PetEvent.activityDetected,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorExitedZone,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorFastMove,
        targetState: PetState.run,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.throwableSpawned,
        targetState: PetState.chasing,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
    ],
    PetState.angry: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 2),
      ),
      PetTransition(
        event: PetEvent.cursorLeft,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.breakStarted,
        targetState: PetState.breakReminder,
        weight: 1.0,
      ),
    ],
    PetState.scared: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 3),
      ),
      PetTransition(
        event: PetEvent.activityDetected,
        targetState: PetState.alert,
        weight: 1.0,
      ),
    ],
    PetState.breatheFire: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 4),
      ),
    ],
    PetState.fly: [
      PetTransition(
        event: PetEvent.tick,
        targetState: PetState.idle,
        weight: 1.0,
        minDuration: const Duration(seconds: 6),
      ),
      PetTransition(
        event: PetEvent.cursorNearby,
        targetState: PetState.following,
        weight: 1.5,
      ),
    ],

    PetState.reacting: [
      PetTransition(
        event: PetEvent.cursorExitedZone,
        targetState:
            PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.windowOverlapEnded,
        targetState:
            PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorDwell,
        targetState: PetState.resting,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.cursorFastMove,
        targetState: PetState.run,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.throwableSpawned,
        targetState: PetState.chasing,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
    ],

    PetState.chasing: [
      PetTransition(
        event: PetEvent.throwableFetched,
        targetState: PetState.fetching,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.throwableReturned,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
    ],

    PetState.fetching: [
      PetTransition(
        event: PetEvent.throwableReturned,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
    ],

    PetState.falling: [
      PetTransition(
        event: PetEvent.landedOnSurface,
        targetState: PetState.idle,
        weight: 1.0,
      ),
    ],
  };
}
