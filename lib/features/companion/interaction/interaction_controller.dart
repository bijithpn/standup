import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart'
    show WidgetsBinding, WidgetsBindingObserver;

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/pet_needs.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/services/companion_behavior_engine.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/features/companion/services/pet_companion_service.dart';
import 'package:breakmate/features/companion/services/throwable_object_manager.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class InteractionController with WidgetsBindingObserver {
  InteractionController({
    PetStateMachine? stateMachine,
    EventBus? eventBus,
    CursorTracker? cursorTracker,
    ThrowableObjectManager? throwableObjectManager,
    NeedsEngine? needsEngine,
    PetCompanionService? petCompanionService,
    SettingsRepository? settingsRepository,
    AppLogger? logger,
    CompanionBehaviorEngine? behaviorEngine,
    this.isPiP = false,
  }) : _stateMachine = stateMachine ?? PetStateMachine(),
       _eventBus = eventBus ?? EventBus.instance,
       _cursorTracker = cursorTracker ?? CursorTracker(),
       _throwableObjectManager = throwableObjectManager,
       _needsEngine = needsEngine ?? NeedsEngine(),
       _petCompanionService = petCompanionService,
       _settingsRepository = settingsRepository,
       _logger = logger ?? AppLogger(),
       _behaviorEngine = behaviorEngine;

  final PetStateMachine _stateMachine;
  final EventBus _eventBus; // ignore: unused_field
  final CursorTracker _cursorTracker;
  final ThrowableObjectManager? _throwableObjectManager;
  final NeedsEngine _needsEngine;
  final PetCompanionService? _petCompanionService;
  final SettingsRepository? _settingsRepository;
  final AppLogger _logger;
  final CompanionBehaviorEngine? _behaviorEngine;
  final bool isPiP;

  bool reducedMotion = false;

  bool _lowPower = false;
  bool get lowPower => _lowPower;
  set lowPower(bool value) {
    if (_lowPower == value) return;
    _lowPower = value;
    _eventBus.emit(LowPowerModeChangedEvent(isLowPower: value));
    _logger.info(
      '{"interaction":"lowPowerChanged","isLowPower":$value,'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );
  }

  Timer? _lookDelayTimer;

  bool _pettingActive = false;

  int _strokeCount = 0;

  Timer? _debounceTimer;

  Timer? _graceTimer;

  Timer? _clickDisambiguationTimer;

  DateTime? _lastTreatTime;

  bool _treatRetryPending = false;

  final math.Random _random = math.Random();
  void initialize() {
    reducedMotion =
        PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;
    WidgetsBinding.instance.addObserver(this);
    _logger.info(
      '{"interaction":"initialize","reducedMotion":$reducedMotion,'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lookDelayTimer?.cancel();
    _lookDelayTimer = null;
    _clickDisambiguationTimer?.cancel();
    _clickDisambiguationTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _logger.info(
      '{"interaction":"dispose",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );
  }

  @override
  void didChangeAccessibilityFeatures() {
    final newValue =
        PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;
    if (reducedMotion != newValue) {
      reducedMotion = newValue;
      _logger.info(
        '{"interaction":"accessibilityChanged","reducedMotion":$reducedMotion,'
        '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
      );
    }
  }

  void onPetClicked() {
    _logger.info(
      '{"interaction":"onPetClicked",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (!_guardPasses('pettingEnabled')) return;

    _clickDisambiguationTimer?.cancel();
    _clickDisambiguationTimer = Timer(const Duration(milliseconds: 400), () {
      if (!_guardPasses('pettingEnabled')) return;
      _stateMachine.handleEvent(PetEvent.userClick);
      _suppressBehavior();
    });
  }

  void onPetDoubleClicked() {
    _logger.info(
      '{"interaction":"onPetDoubleClicked",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    _clickDisambiguationTimer?.cancel();
    _clickDisambiguationTimer = null;

    if (!_guardPasses('pettingEnabled')) return;

    _stateMachine.handleEvent(PetEvent.userDoubleClick);
    _suppressBehavior();
  }

  void onPetDragged(Offset delta) {
    _logger.info(
      '{"interaction":"onPetDragged",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (!_guardPasses('ballThrowEnabled')) return;

    _stateMachine.handleEvent(PetEvent.userDragStart);
    _suppressBehavior();
  }

  void onPetDragReleased(Offset dragVector) {
    _logger.info(
      '{"interaction":"onPetDragReleased",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    _stateMachine.handleEvent(PetEvent.userDragEnd);

    final double magnitude = dragVector.distance;
    if (magnitude >= ThrowableObjectManager.minDragMagnitude) {
      _throwableObjectManager?.spawnThrowable(
        Offset.zero,
        dragVector,
        kind: 'ball',
      );
    }
  }

  void onPetPetted() {
    _logger.info(
      '{"interaction":"onPetPetted",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    const blockedStates = {
      PetState.breakReminder,
      PetState.meetingPaused,
      PetState.focusMode,
      PetState.drag,
    };
    if (blockedStates.contains(_stateMachine.currentState)) {
      if (_pettingActive) _endPettingSession();
      return;
    }

    if (!_guardPasses('pettingEnabled')) return;

    final double speed = _cursorTracker.velocity.distance;
    const double minPettingSpeed = 20.0;
    const double maxPettingSpeed = 300.0;

    if (speed < minPettingSpeed || speed > maxPettingSpeed) {
      _strokeCount = 0;
      return;
    }

    _strokeCount++;

    _graceTimer?.cancel();
    _graceTimer = null;

    if (!_pettingActive && _strokeCount >= 2) {
      _pettingActive = true;
    }

    if (!_pettingActive) return;
    _suppressBehavior();
    if (_debounceTimer != null && _debounceTimer!.isActive) return;

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _debounceTimer = null;
      if (!_pettingActive) return;

      const pettableStates = {
        PetState.idle,
        PetState.curious,
        PetState.reacting,
        PetState.happy,
      };
      if (pettableStates.contains(_stateMachine.currentState)) {
        _stateMachine.handleEvent(PetEvent.userClick);
      }

      _needsEngine.onPetted();
    });
  }

  void onPetPettingZoneExited() {
    if (!_pettingActive) return;

    _graceTimer?.cancel();
    _graceTimer = Timer(const Duration(milliseconds: 1500), _endPettingSession);
  }

  void throwToy() {
    _logger.info(
      '{"interaction":"throwToy",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (!_guardPasses('ballThrowEnabled')) return;

    final manager = _throwableObjectManager;
    if (manager == null) return;

    final activeCount = manager.snapshots().length;
    if (activeCount >= ThrowableObjectManager.maxActiveThrowables) {
      return;
    }

    final double velocityTarget = 400.0 + _random.nextDouble() * 800.0;
    final double angle = _random.nextDouble() * math.pi * 2;
    final Offset direction = Offset(math.cos(angle), math.sin(angle));

    final double dragMag =
        velocityTarget / ThrowableObjectManager.velocityScaleFactor;
    final Offset dragVector = direction * dragMag;

    final Offset releasePoint = Offset(
      _random.nextDouble() * 100 - 50,
      -(_random.nextDouble() * 80 + 20),
    );

    final double toySize = isPiP ? 10.0 : 20.0;
    manager.spawnThrowable(
      releasePoint,
      dragVector,
      kind: 'ball',
      customSize: toySize,
    );
    _suppressBehavior();
  }

  void giveTreat() {
    _logger.info(
      '{"interaction":"giveTreat",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (!_guardPasses('treatEnabled')) return;

    final now = DateTime.now();
    if (_lastTreatTime != null &&
        now.difference(_lastTreatTime!).inSeconds < _treatCooldownSeconds) {
      return;
    }

    final profile = _petCompanionService?.profile.species.defaultProfile;
    if (profile != null && profile.specialAbilityProbability > 0.0) {
      final roll = _random.nextDouble();
      if (roll < profile.specialAbilityProbability) {
        return;
      }
    }

    _lastTreatTime = now;
    _treatRetryPending = false;
    _spawnTreat(isRetry: false);
  }

  static const int _treatCooldownSeconds = 10;

  void _spawnTreat({required bool isRetry}) {
    final manager = _throwableObjectManager;
    if (manager == null) return;

    final petPosition = _petCompanionService?.position ?? Offset.zero;

    // Similar to throwToy, throw the treat from above (120px above pet) with a downward velocity
    final double velocityTarget = 300.0 + _random.nextDouble() * 500.0;
    final double angle = (45.0 + _random.nextDouble() * 90.0) * math.pi / 180.0;
    final Offset direction = Offset(math.cos(angle), math.sin(angle));

    final double dragMag =
        velocityTarget / ThrowableObjectManager.velocityScaleFactor;
    final Offset dragVector = direction * dragMag;

    final Offset releasePoint = Offset(
      petPosition.dx + (_random.nextDouble() * 100.0 - 50.0),
      petPosition.dy - 120.0,
    );

    final double treatSize = isPiP ? 10.0 : 20.0;
    final result = manager.spawnThrowable(
      releasePoint,
      dragVector,
      kind: 'treat',
      customSize: treatSize,
    );

    if (result == null) {
      if (!isRetry && !_treatRetryPending) {
        _treatRetryPending = true;
        Timer(const Duration(milliseconds: 500), () {
          _treatRetryPending = false;
          _spawnTreat(isRetry: true);
        });
      } else {
        _logger.warning(
          '{"interaction":"giveTreat","error":"spawnThrowable returned null twice",'
          '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
        );
        _eventBus.emit(TreatSpawnFailedEvent());
      }
    }
  }

  void triggerCompanionReaction(PetState targetState) {
    _logger.info(
      '{"interaction":"triggerCompanionReaction",'
      '"targetState":"${targetState.name}",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (!_isFeatureEnabled('companionEnabled')) return;
    if (!_isFeatureEnabled('developerReactions')) return;

    const blockedStates = {
      PetState.breakReminder,
      PetState.meetingPaused,
      PetState.focusMode,
    };

    if (blockedStates.contains(targetState)) {
      _logger.warning(
        '{"interaction":"triggerCompanionReaction",'
        '"blocked":"${targetState.name}",'
        '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
      );
      return;
    }

    final event = _petEventForState(targetState);
    if (event != null) {
      _stateMachine.handleEvent(event);
    }
  }

  bool _isFeatureEnabled(String settingsKey) {
    try {
      final settings = _settingsRepository?.currentSettings;
      if (settings == null) return true;
      switch (settingsKey) {
        case 'companionEnabled':
          return settings.companionEnabled;
        case 'pettingEnabled':
          return settings.pettingEnabled;
        case 'ballThrowEnabled':
          return settings.ballThrowEnabled;
        case 'treatEnabled':
          return settings.treatEnabled;
        case 'developerReactions':
          return settings.developerReactions;
        case 'quietModeAutoActivate':
          return settings.quietModeAutoActivate;
        default:
          return true;
      }
    } catch (_) {
      return true;
    }
  }

  bool _guardPasses(String featureKey) {
    if (!_isFeatureEnabled('companionEnabled')) return false;

    if (!_isFeatureEnabled(featureKey)) return false;

    const blockedStates = {
      PetState.breakReminder,
      PetState.meetingPaused,
      PetState.focusMode,
    };
    if (blockedStates.contains(_stateMachine.currentState)) return false;

    if (reducedMotion && featureKey == 'ballThrowEnabled') return false;

    return true;
  }

  void _suppressBehavior() {
    _behaviorEngine?.suppressRandomBehavior(const Duration(seconds: 3));
  }

  PetEvent? _petEventForState(PetState targetState) {
    switch (targetState) {
      case PetState.alert:
        return PetEvent.userClick;
      case PetState.happy:
        return PetEvent.userDoubleClick;
      case PetState.celebrating:
        return PetEvent.breakCompleted;
      case PetState.sad:
        return PetEvent.breakEnded;
      case PetState.sleep:
        return PetEvent.idleTimeout;
      case PetState.resting:
        return PetEvent.cursorDwell;
      default:
        return null;
    }
  }

  void onCursorEnteredZone(double velocity) {
    _logger.info(
      '{"interaction":"onCursorEnteredZone","velocity":$velocity,'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (velocity > CursorTracker.fastVelocityThreshold) return;

    _lookDelayTimer?.cancel();
    _lookDelayTimer = null;

    final profile = _petCompanionService?.profile.species.defaultProfile;

    if (profile != null && profile.mouseAttraction < 1.0) {
      final delayMs = (profile.lookDelay * 1000).round();
      if (delayMs > 0) {
        _lookDelayTimer = Timer(Duration(milliseconds: delayMs), () {
          _lookDelayTimer = null;
          _stateMachine.handleEvent(PetEvent.cursorEnteredZone);
        });
        return;
      }
    }

    _stateMachine.handleEvent(PetEvent.cursorEnteredZone);
  }

  void onCursorExitedZone() {
    _logger.info(
      '{"interaction":"onCursorExitedZone",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    _lookDelayTimer?.cancel();
    _lookDelayTimer = null;

    if (_pettingActive) {
      _stateMachine.handleEvent(PetEvent.cursorExitedZone);
    }

    onPetPettingZoneExited();
  }

  void _endPettingSession() {
    _pettingActive = false;
    _strokeCount = 0;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
  }
}
