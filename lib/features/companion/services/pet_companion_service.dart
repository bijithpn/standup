import 'dart:math';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/ai/pet_behavior_brain.dart';
import 'package:breakmate/features/companion/domain/pet_behavior_context.dart';
import 'package:breakmate/features/companion/domain/pet_mood.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/services/pet_navigation_service.dart';

class PetCompanionService extends ChangeNotifier {
  final PetStateMachine _stateMachine;
  final PetBehaviorBrain _brain;
  final PetNavigationService _navigation;
  PetProfile _profile;

  PetMoodState _mood;
  PetBehaviorContext _context;

  DateTime _lastBehaviorDecision = DateTime.now();
  static const Duration _decisionInterval = Duration(seconds: 4);

  // Throttle context.copyWith to every 500ms to avoid per-frame allocations
  DateTime _lastContextUpdate = DateTime.now();
  static const Duration _contextUpdateInterval = Duration(milliseconds: 500);

  bool _isBreakActive = false;
  bool _isMeetingDetected = false;
  bool _isFocusMode = false;
  bool _isIdle = false;

  double _curiosity = 0.5;
  double _fatigue = 0.0;
  double _boredom = 0.0;
  Duration _totalWorkToday = Duration.zero;

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
         curiosity: 0.5,
         fatigue: 0.0,
         boredom: 0.0,
       ) {
    _navigation.setSpecies(profile.species);
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
    _mood = PetMoodState(
      mood: newProfile.initialMood ?? PetMood.relaxed,
      since: DateTime.now(),
    );
    _navigation.setSpecies(newProfile.species);
    _context = _context.copyWith(profile: newProfile, currentMood: _mood);
    notifyListeners(); // Profile change is a real UI event — notify is correct here
  }

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

  void syncContextFlags({
    bool? isBreakActive,
    bool? isMeetingDetected,
    bool? isFocusMode,
    bool? isIdle,
    int? totalWorkTodaySeconds,
  }) {
    _isBreakActive = isBreakActive ?? _isBreakActive;
    _isMeetingDetected = isMeetingDetected ?? _isMeetingDetected;
    _isFocusMode = isFocusMode ?? _isFocusMode;
    _isIdle = isIdle ?? _isIdle;
    if (totalWorkTodaySeconds != null) {
      _totalWorkToday = Duration(seconds: totalWorkTodaySeconds);
    }
    _context = _context.copyWith(
      isBreakActive: _isBreakActive,
      isMeetingDetected: _isMeetingDetected,
      isFocusMode: _isFocusMode,
      isIdle: _isIdle,
      totalWorkToday: _totalWorkToday,
    );
  }

  /// Main update — called every frame. Must be allocation-minimal.
  void update(double dt) {
    final now = DateTime.now();

    if (!_mood.isActive(now)) {
      _mood = PetMoodState(
        mood: PetMood.relaxed,
        intensity: 0.5,
        since: now,
        decayDuration: const Duration(minutes: 5),
      );
      _stateMachine.setMood(_mood);
    }

    final profileMultiplier = _profile.species.defaultProfile;
    if (_stateMachine.currentState == PetState.sleep) {
      _fatigue = (_fatigue - 0.1 * dt).clamp(0.0, 1.0);
    } else {
      double rate = 0.005; // Base passive rate
      if (_stateMachine.currentState == PetState.walk ||
          _stateMachine.currentState == PetState.exploring ||
          _stateMachine.currentState == PetState.following) {
        rate = 0.015;
      } else if (_stateMachine.currentState == PetState.run ||
          _stateMachine.currentState == PetState.jumping ||
          _stateMachine.currentState == PetState.playing) {
        rate = 0.035;
      }
      _fatigue = (_fatigue + rate * profileMultiplier.sleepLikelihood * dt)
          .clamp(0.0, 1.0);
    }

    if (_stateMachine.currentState == PetState.following ||
        _stateMachine.currentState == PetState.playing) {
      _curiosity = (_curiosity - 0.02 * dt).clamp(0.0, 1.0);
    } else {
      _curiosity = (_curiosity + 0.005 * profileMultiplier.mouseAttraction * dt)
          .clamp(0.0, 1.0);
    }

    if (_stateMachine.currentState == PetState.idle ||
        _stateMachine.currentState == PetState.resting) {
      _boredom = (_boredom + 0.015 * dt).clamp(0.0, 1.0);
    } else {
      _boredom = (_boredom - 0.05 * dt).clamp(0.0, 1.0);
    }

    final newPos = _navigation.update(dt);

    // Throttle context.copyWith to avoid per-frame object allocation
    if (now.difference(_lastContextUpdate) >= _contextUpdateInterval) {
      _context = _context.copyWith(
        petPosition: newPos,
        timeInCurrentState: _stateMachine.timeInState,
        curiosity: _curiosity,
        fatigue: _fatigue,
        boredom: _boredom,
      );
      _lastContextUpdate = now;
    }

    if (now.difference(_lastBehaviorDecision) >= _decisionInterval) {
      _makeBehaviorDecision();
      _lastBehaviorDecision = now;
    }

    _applyStateBehavior();
  }

  void updateCursorPosition(Offset cursorPos, {bool? forceFollowing}) {
    final double dist = (_navigation.currentPosition - cursorPos).distance;
    if (dist > 10.0) {
      final profileMultiplier = _profile.species.defaultProfile;
      _curiosity = (_curiosity + 0.02 * profileMultiplier.mouseAttraction)
          .clamp(0.0, 1.0);
    }

    _navigation.updateCursorPosition(cursorPos, forceFollowing: forceFollowing);

    if (_navigation.isAnnoyed &&
        _stateMachine.currentState == PetState.following) {
      _stateMachine.transitionTo(PetState.angry);
      return;
    }

    final wasFollowing = _navigation.isCursorFollowing;
    final isNowFollowing = forceFollowing ?? wasFollowing;

    if (isNowFollowing) {
      final cur = _stateMachine.currentState;
      if (cur == PetState.grooming ||
          cur == PetState.stretch ||
          cur == PetState.celebrating ||
          cur == PetState.alert ||
          cur == PetState.angry ||
          cur == PetState.breakReminder ||
          cur == PetState.meetingPaused ||
          cur == PetState.focusMode ||
          cur == PetState.drag ||
          cur == PetState.sleep) {
        return; // Don't interrupt these states
      }

      if (cur != PetState.following) {
        _stateMachine.transitionTo(PetState.following);
      }
    } else if (wasFollowing && !isNowFollowing) {
      _stateMachine.handleEvent(PetEvent.cursorLeft);
    }
  }

  void setCursorFollowing(bool following) {
    _navigation.setCursorFollowing(following);
  }

  void handleEvent(PetEvent event) {
    _stateMachine.handleEvent(event);
  }

  final Random _rng = Random();

  void _makeBehaviorDecision() {
    final cur = _stateMachine.currentState;
    if (cur == PetState.idle ||
        cur == PetState.resting ||
        cur == PetState.bored ||
        cur == PetState.exploring) {
      final suggestedState = _brain.decideNextState(_context);
      _brain.recordStateSelection(suggestedState);
      _stateMachine.transitionTo(suggestedState);
    } else {
      _stateMachine.handleEvent(PetEvent.randomBehavior);
    }
  }

  void _applyStateBehavior() {
    switch (_stateMachine.currentState) {
      case PetState.walk:
      case PetState.exploring:
        final double speed = 45.0 + _rng.nextDouble() * 30.0;
        _navigation.updateConfig(wanderSpeed: speed);
        if (_navigation.needsWanderTarget) _navigation.generateWanderTarget();
        break;
      case PetState.curious:
        final double speed = 25.0 + _rng.nextDouble() * 15.0;
        _navigation.updateConfig(wanderSpeed: speed);
        break;
      case PetState.run:
      case PetState.jumping:
        final double speed = 140.0 + _rng.nextDouble() * 50.0;
        _navigation.updateConfig(wanderSpeed: speed);
        if (_navigation.needsWanderTarget) _navigation.generateWanderTarget();
        break;
      case PetState.following:
      case PetState.playing:
        _navigation.updateConfig(wanderSpeed: 0.0);
        break;
      case PetState.chasing:
      case PetState.fetching:
        break;
      default:
        _navigation.updateConfig(wanderSpeed: 0.0);
        break;
    }
  }
}
