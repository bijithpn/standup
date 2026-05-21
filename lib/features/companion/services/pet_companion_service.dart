import 'package:flutter/material.dart';
import 'package:standup/features/companion/ai/pet_behavior_brain.dart';
import 'package:standup/features/companion/domain/pet_behavior_context.dart';
import 'package:standup/features/companion/domain/pet_mood.dart';
import 'package:standup/features/companion/domain/pet_profile.dart';
import 'package:standup/features/companion/domain/pet_state_machine.dart';
import 'package:standup/features/companion/services/pet_navigation_service.dart';

/// High-level companion service that orchestrates the pet's autonomous behavior
/// by integrating the behavior brain, state machine, mood system, and navigation.
class PetCompanionService extends ChangeNotifier {
  final PetStateMachine _stateMachine;
  final PetBehaviorBrain _brain;
  final PetNavigationService _navigation;
  final PetProfile _profile;

  PetMoodState _mood;
  PetBehaviorContext _context;
  DateTime _lastBehaviorDecision = DateTime.now();
  final Duration _decisionInterval = const Duration(seconds: 2);

  PetCompanionService({
    required PetStateMachine stateMachine,
    required PetBehaviorBrain brain,
    required PetNavigationService navigation,
    required PetProfile profile,
  }) : _stateMachine = stateMachine,
       _brain = brain,
       _navigation = navigation,
       _profile = profile,
       _mood = PetMoodState(
         mood: profile.initialMood ?? PetMood.relaxed,
         since: DateTime.now(),
       ),
       _context = PetBehaviorContext(
         profile: profile,
         currentMood: PetMoodState(
           mood: profile.initialMood ?? PetMood.relaxed,
           since: DateTime.now(),
         ),
         lastStateChange: DateTime.now(),
         timeInCurrentState: Duration.zero,
       );

  // Getters
  PetState get currentState => _stateMachine.currentState;
  PetMoodState get mood => _mood;
  PetBehaviorContext get context => _context;
  PetProfile get profile => _profile;
  Offset get position => _navigation.currentPosition;

  /// Initialize the service with screen size and starting position.
  void initialize({required Size screenSize, Offset? startPosition}) {
    _navigation.initialize(
      screenSize: screenSize,
      startPosition: startPosition,
    );
    _context = _context.copyWith(
      screenSize: screenSize,
      petPosition: startPosition,
    );
  }

  /// Main update loop - call every frame.
  void update(double dt) {
    final now = DateTime.now();

    // Update mood decay
    if (!_mood.isActive(now)) {
      _mood = _mood.copyWith(intensity: 0.0, since: now);
    }

    // Update navigation and get new position
    final newPosition = _navigation.update(dt);

    // Update context with current state
    _context = _context.copyWith(
      petPosition: newPosition,
      timeInCurrentState: _stateMachine.timeInState,
    );

    // Periodic behavior decision
    if (now.difference(_lastBehaviorDecision) >= _decisionInterval) {
      _makeBehaviorDecision();
      _lastBehaviorDecision = now;
    }

    // Apply state-driven navigation behavior
    _applyStateBehavior();

    notifyListeners();
  }

  /// Update cursor position for attraction behavior.
  void updateCursorPosition(Offset cursorPos) {
    _navigation.updateCursorPosition(cursorPos);
    final distance = (cursorPos - _navigation.currentPosition).distance;
    _context = _context.copyWith(
      cursorPosition: cursorPos,
      isCursorNearby: distance < 300.0,
    );
  }

  /// Trigger an event in the state machine.
  void handleEvent(PetEvent event) {
    _stateMachine.handleEvent(event);
  }

  /// Make an AI-driven behavior decision.
  void _makeBehaviorDecision() {
    final nextState = _brain.decideNextState(_context);
    _brain.recordStateSelection(nextState);

    // Map state decision to appropriate event
    final event = _mapStateToEvent(nextState);
    if (event != null) {
      _stateMachine.handleEvent(event);
    }
  }

  /// Apply state-specific navigation behavior.
  void _applyStateBehavior() {
    switch (_stateMachine.currentState) {
      case PetState.walk:
        _navigation.updateConfig(wanderSpeed: 60.0);
        break;
      case PetState.run:
        _navigation.updateConfig(wanderSpeed: 180.0);
        break;
      case PetState.sleep:
      case PetState.resting:
        // Stationary states - minimal movement
        _navigation.updateConfig(wanderSpeed: 0.0);
        break;
      case PetState.following:
      case PetState.playing:
        // These states are driven by cursor attraction
        break;
      default:
        _navigation.updateConfig(wanderSpeed: 60.0);
        break;
    }
  }

  /// Map a state decision to a triggering event.
  PetEvent? _mapStateToEvent(PetState state) {
    switch (state) {
      case PetState.walk:
      case PetState.run:
        return PetEvent.activityDetected;
      case PetState.sleep:
      case PetState.resting:
        return PetEvent.idleTimeout;
      case PetState.playing:
      case PetState.interacting:
        return PetEvent.cursorNearby;
      case PetState.curious:
      case PetState.exploring:
        return PetEvent.randomBehavior;
      case PetState.hiding:
      case PetState.quiet:
        return PetEvent.meetingDetected;
      case PetState.celebrating:
      case PetState.dancing:
        return PetEvent.breakStarted;
      default:
        return PetEvent.randomBehavior;
    }
  }
}
