import 'package:flutter/material.dart';
import 'package:standup/features/companion/ai/pet_behavior_brain.dart';
import 'package:standup/features/companion/domain/pet_behavior_context.dart';
import 'package:standup/features/companion/domain/pet_mood.dart';
import 'package:standup/features/companion/domain/pet_profile.dart';
import 'package:standup/features/companion/domain/pet_state_machine.dart';
import 'package:standup/features/companion/domain/pet_type.dart';
import 'package:standup/features/companion/services/pet_navigation_service.dart';

class PetCompanionService extends ChangeNotifier {
  final PetStateMachine _stateMachine;
  final PetBehaviorBrain _brain;
  final PetNavigationService _navigation;
  PetProfile _profile;

  PetMoodState _mood;
  PetBehaviorContext _context;

  // Throttle AI decisions to every 4s — no need for frame-rate precision
  DateTime _lastBehaviorDecision = DateTime.now();
  static const Duration _decisionInterval = Duration(seconds: 4);

  // Throttle context.copyWith to every 500ms to avoid per-frame allocations
  DateTime _lastContextUpdate = DateTime.now();
  static const Duration _contextUpdateInterval = Duration(milliseconds: 500);

  bool _isBreakActive = false;
  bool _isMeetingDetected = false;
  bool _isFocusMode = false;
  bool _isIdle = false;

  PetCompanionService({
    required PetStateMachine stateMachine,
    required PetBehaviorBrain brain,
    required PetNavigationService navigation,
    required PetProfile profile,
  })  : _stateMachine = stateMachine,
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
        ) {
    _navigation.setSpecies(isDog: profile.species == PetSpecies.dog);
  }

  PetStateMachine get stateMachine => _stateMachine;
  PetNavigationService get navigation => _navigation;
  PetState get currentState => _stateMachine.currentState;
  PetMoodState get mood => _mood;
  PetBehaviorContext get context => _context;
  PetProfile get profile => _profile;
  Offset get position => _navigation.currentPosition;

  void updateProfile(PetProfile newProfile) {
    _profile = newProfile;
    _mood = PetMoodState(mood: newProfile.initialMood ?? PetMood.relaxed, since: DateTime.now());
    _navigation.setSpecies(isDog: newProfile.species == PetSpecies.dog);
    _context = _context.copyWith(profile: newProfile, currentMood: _mood);
    notifyListeners(); // Profile change is a real UI event — notify is correct here
  }

  void initialize({required Size screenSize, Offset? startPosition}) {
    _navigation.initialize(screenSize: screenSize, startPosition: startPosition);
    _context = _context.copyWith(screenSize: screenSize, petPosition: startPosition);
  }

  void syncContextFlags({
    bool? isBreakActive,
    bool? isMeetingDetected,
    bool? isFocusMode,
    bool? isIdle,
  }) {
    _isBreakActive = isBreakActive ?? _isBreakActive;
    _isMeetingDetected = isMeetingDetected ?? _isMeetingDetected;
    _isFocusMode = isFocusMode ?? _isFocusMode;
    _isIdle = isIdle ?? _isIdle;
    // Flags change infrequently — safe to copyWith here
    _context = _context.copyWith(
      isBreakActive: _isBreakActive,
      isMeetingDetected: _isMeetingDetected,
      isFocusMode: _isFocusMode,
      isIdle: _isIdle,
    );
  }

  /// Main update — called every frame. Must be allocation-minimal.
  void update(double dt) {
    final now = DateTime.now();

    // Mood decay check (cheap — just a DateTime comparison)
    if (!_mood.isActive(now)) {
      _mood = PetMoodState(
        mood: PetMood.relaxed,
        intensity: 0.5,
        since: now,
        decayDuration: const Duration(minutes: 5),
      );
      _stateMachine.setMood(_mood);
    }

    // Navigation update (always runs — drives position)
    final newPos = _navigation.update(dt);

    // Throttle context.copyWith to avoid per-frame object allocation
    if (now.difference(_lastContextUpdate) >= _contextUpdateInterval) {
      _context = _context.copyWith(
        petPosition: newPos,
        timeInCurrentState: _stateMachine.timeInState,
      );
      _lastContextUpdate = now;
    }

    // AI behavior decision at low frequency
    if (now.difference(_lastBehaviorDecision) >= _decisionInterval) {
      _makeBehaviorDecision();
      _lastBehaviorDecision = now;
    }

    _applyStateBehavior();

    // DO NOT call notifyListeners() here — this runs at 60fps and would
    // cause Provider to rebuild the entire widget tree every frame.
    // Listeners are notified only on profile changes (updateProfile).
  }

  void updateCursorPosition(Offset cursorPos, {bool? forceFollowing}) {
    _navigation.updateCursorPosition(cursorPos, forceFollowing: forceFollowing);
    // Update context cursor fields at low cost (no copyWith — direct field update
    // is not possible with immutable context, so we only do it on the throttle cycle)
  }

  void setCursorFollowing(bool following) {
    _navigation.setCursorFollowing(following);
  }

  void handleEvent(PetEvent event) {
    _stateMachine.handleEvent(event);
  }

  void _makeBehaviorDecision() {
    final suggestedState = _brain.decideNextState(_context);
    _brain.recordStateSelection(suggestedState);
    _stateMachine.handleEvent(PetEvent.randomBehavior);
  }

  void _applyStateBehavior() {
    switch (_stateMachine.currentState) {
      case PetState.walk:
      case PetState.exploring:
        _navigation.updateConfig(wanderSpeed: 60.0);
        if (_navigation.needsWanderTarget) _navigation.generateWanderTarget();
        break;
      case PetState.curious:
        _navigation.updateConfig(wanderSpeed: 30.0);
        break;
      case PetState.run:
      case PetState.jumping:
        _navigation.updateConfig(wanderSpeed: 160.0);
        if (_navigation.needsWanderTarget) _navigation.generateWanderTarget();
        break;
      case PetState.following:
      case PetState.playing:
        _navigation.updateConfig(wanderSpeed: 100.0);
        break;
      default:
        _navigation.updateConfig(wanderSpeed: 0.0);
        break;
    }
  }
}
