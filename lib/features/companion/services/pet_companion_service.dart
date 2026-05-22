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
  PetProfile _profile;

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
  PetStateMachine get stateMachine => _stateMachine;
  PetNavigationService get navigation => _navigation;
  PetState get currentState => _stateMachine.currentState;
  PetMoodState get mood => _mood;
  PetBehaviorContext get context => _context;
  PetProfile get profile => _profile;
  Offset get position => _navigation.currentPosition;

  /// Update active pet profile dynamically (e.g. on theme/breed switches).
  void updateProfile(PetProfile newProfile) {
    _profile = newProfile;
    _mood = PetMoodState(
      mood: newProfile.initialMood ?? PetMood.relaxed,
      since: DateTime.now(),
    );
    _context = _context.copyWith(
      profile: newProfile,
      currentMood: _mood,
    );
    notifyListeners();
  }

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
  void updateCursorPosition(Offset cursorPos, {bool? forceFollowing}) {
    _navigation.updateCursorPosition(cursorPos, forceFollowing: forceFollowing);
    final distance = (cursorPos - _navigation.currentPosition).distance;
    _context = _context.copyWith(
      cursorPosition: cursorPos,
      isCursorNearby: distance < 300.0,
    );
  }

  /// Explicitly set whether the pet is currently following the cursor.
  void setCursorFollowing(bool following) {
    _navigation.setCursorFollowing(following);
  }

  /// Trigger an event in the state machine.
  void handleEvent(PetEvent event) {
    _stateMachine.handleEvent(event);
  }

  /// Make an AI-driven behavior decision.
  void _makeBehaviorDecision() {
    final nextState = _brain.decideNextState(_context);
    _brain.recordStateSelection(nextState);

    // AI directly commands the state transition
    _stateMachine.transitionTo(nextState);
  }

  /// Apply state-specific navigation behavior.
  void _applyStateBehavior() {
    switch (_stateMachine.currentState) {
      case PetState.walk:
      case PetState.exploring:
      case PetState.curious:
        _navigation.updateConfig(wanderSpeed: 60.0);
        break;
      case PetState.run:
      case PetState.jumping:
        _navigation.updateConfig(wanderSpeed: 180.0);
        break;
      case PetState.following:
      case PetState.playing:
        // These states are driven by cursor attraction
        _navigation.updateConfig(wanderSpeed: 120.0);
        break;
      default:
        // All other states (idle, sleep, alert, happy, sad, etc) are stationary
        _navigation.updateConfig(wanderSpeed: 0.0);
        break;
    }
  }
}
