import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'pet_mood.dart';
import 'pet_personality.dart';
import 'behavior_engine_models.dart';
import '../../../core/utils/logger.dart';

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
  // Behavior-engine states (pet-behavior-engine spec)
  chasing,    // pursuing a throwable object
  fetching,   // carrying throwable back to origin
  falling,    // airborne, gravity applied by PhysicsSimulator
  reacting,   // cursor/window interaction response
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
  animationComplete, // fired by CompanionComponent when a non-looping anim finishes
  // Behavior-engine events (pet-behavior-engine spec)
  cursorEnteredZone,   // cursor inside 80px radius, velocity ≤800
  cursorExitedZone,    // cursor left 80px radius
  cursorDwell,         // stationary in zone ≥3s
  cursorFastMove,      // velocity >800 px/s
  throwableSpawned,    // new ThrowableObject created
  throwableStationary, // ThrowableObject became stationary
  throwableFetched,    // pet reached throwable
  throwableReturned,   // pet returned to throw origin
  landedOnSurface,     // Falling → landed
  windowOverlap,       // pet bounds overlap app window
  windowOverlapEnded,  // overlap cleared
  surfaceLost,         // standing window closed/minimized
  loopBlocked,         // looping animation is blocked on final frame
}

/// Weighted transition with conditions.
class PetTransition {
  final PetEvent event;
  final PetState targetState;
  final double weight; // Higher = more likely when multiple transitions match
  final Duration?
  minDuration; // Minimum time in current state before this transition
  final Duration? cooldown; // Cooldown after this transition fires
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

/// Priority values for behavior-engine states.
///
/// Higher number wins when multiple transition targets are active simultaneously.
/// States not listed here have an implicit priority of 0.
const Map<PetState, int> _statePriority = {
  PetState.falling:  5,
  PetState.chasing:  4,
  PetState.fetching: 4,
  PetState.run:      3,
  PetState.reacting: 3,
  PetState.walk:     2,
  PetState.resting:  2,
  PetState.idle:     1,
};

/// Abstracted state machine with weighted transitions and mood awareness.
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

  // Single Random instance — avoids per-call allocation
  static final _rng = Random();

  // Prior-state stack: stores the state active before the most recent
  // transition into [PetState.reacting], so cursorExitedZone /
  // windowOverlapEnded can restore it (requirements 5.4, 6.6).
  PetState? _priorState;

  // Transition log: every _transitionTo() call appends an entry (req 8.9).
  final List<StateTransitionLog> transitionLog = [];

  // Shared AppLogger instance for structured JSON logging.
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

    // Filter matching transitions inline to avoid list allocation when possible
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
      // Priority resolution: among matched transitions, pick the one whose
      // target state has the highest priority.  Only fall back to weighted
      // random when all targets share the same priority.
      final int maxPriority = matched
          .map((t) => _statePriority[t.targetState] ?? 0)
          .reduce((a, b) => a > b ? a : b);
      final highPriority =
          matched.where((t) => (_statePriority[t.targetState] ?? 0) == maxPriority).toList();

      if (highPriority.length == 1) {
        selected = highPriority.first;
      } else {
        // Multiple transitions at the same priority — use weighted random.
        double threshold = _rng.nextDouble() *
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

    // Resolve the sentinel "restore prior" target to the actual prior state.
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

    // Before entering reacting, record the prior state so we can restore it.
    if (newState == PetState.reacting) {
      _priorState = previousState;
    }

    _currentState = newState;
    _stateEnteredAt = DateTime.now();
    if (transition != null) _lastTriggered[transition] = DateTime.now();

    // Append to transition log and emit structured log line (req 8.9).
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

  /// Base transition table.
  ///
  /// Design rules:
  /// - [PetEvent.randomBehavior] transitions ONLY exist on states where ambient
  ///   AI-driven behavior changes make sense (idle, bored, exploring). This
  ///   prevents the brain from hijacking high-priority states like drag, sleep,
  ///   breakReminder, or meetingPaused.
  /// - High-priority system events (breakStarted, meetingDetected, focusModeOn)
  ///   are present on every interruptible state so they always win.
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
      // Behavior-engine interrupts
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
      // Ambient AI-driven behaviors — only fire from idle
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
      // Behavior-engine interrupts
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
      // Behavior-engine interrupts
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
      // Can chain into another walk from exploring
      PetTransition(
        event: PetEvent.randomBehavior,
        targetState: PetState.walk,
        weight: 1.0,
        cooldown: const Duration(seconds: 10),
      ),
    ],
    PetState.grooming: [
      // animationComplete fires when lick1 finishes — chain to lick2 (grooming2)
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
      // Behavior-engine interrupts
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
    // -------------------------------------------------------------------------
    // Behavior-engine states (pet-behavior-engine spec)
    // -------------------------------------------------------------------------

    /// Cursor / window interaction response state.
    ///
    /// Transitions:
    ///   cursorExitedZone    → restore prior state (idle sentinel resolved in handleEvent)
    ///   windowOverlapEnded  → restore prior state (idle sentinel resolved in handleEvent)
    ///   cursorDwell         → resting (cursor held still ≥3 s inside zone)
    ///   cursorFastMove      → run    (priority 3, overrides reacting at equal priority)
    ///   throwableSpawned    → chasing (priority 4, supersedes reacting priority 3)
    ///   surfaceLost         → falling (priority 5, supersedes all)
    PetState.reacting: [
      PetTransition(
        event: PetEvent.cursorExitedZone,
        targetState: PetState.idle, // sentinel — handleEvent resolves to _priorState
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.windowOverlapEnded,
        targetState: PetState.idle, // sentinel — handleEvent resolves to _priorState
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

    /// Pet is pursuing a throwable object.
    ///
    /// Transitions:
    ///   throwableStationary → fetching (when pet bounds overlap stationary throwable;
    ///                          the overlap condition is checked by the caller before
    ///                          firing throwableStationary — see ThrowableObjectManager)
    ///   throwableFetched    → idle    (throwable disposed / timed out / unreachable)
    ///   surfaceLost         → falling (priority 5)
    PetState.chasing: [
      PetTransition(
        event: PetEvent.throwableStationary,
        targetState: PetState.fetching,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.throwableFetched,
        targetState: PetState.idle,
        weight: 1.0,
      ),
      PetTransition(
        event: PetEvent.surfaceLost,
        targetState: PetState.falling,
        weight: 1.0,
      ),
    ],

    /// Pet is carrying a throwable back to the throw origin.
    ///
    /// Transitions:
    ///   throwableReturned → idle    (pet anchor within 10 px of spawnOrigin)
    ///   surfaceLost       → falling (priority 5)
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

    /// Pet is airborne; gravity is applied by PhysicsSimulator.
    ///
    /// Transitions:
    ///   landedOnSurface → idle
    PetState.falling: [
      PetTransition(
        event: PetEvent.landedOnSurface,
        targetState: PetState.idle,
        weight: 1.0,
      ),
    ],
  };
}
