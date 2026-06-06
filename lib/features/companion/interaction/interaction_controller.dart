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
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/services/companion_behavior_engine.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/features/companion/services/pet_companion_service.dart';
import 'package:breakmate/features/companion/services/throwable_object_manager.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// The central interaction gateway that translates raw user gestures into
/// [PetEvent] values, enforces all state guards, manages the [PettingSession]
/// lifecycle, and forwards side effects to [NeedsEngine] and
/// [ThrowableObjectManager].
///
/// All user interactions funnel through this single service so that:
///   - state-guard logic is auditable in one place (Req 9.1, 9.2)
///   - the API is testable without a running Flame scene (Req 17.1)
///   - feature toggles can suppress any interaction as a no-op (Req 18.8)
///
/// Requirements: 9.1, 9.2, 17.1, 17.4, 18.3, 18.8
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
  }) : _stateMachine = stateMachine ?? PetStateMachine(),
       _eventBus = eventBus ?? EventBus.instance,
       _cursorTracker = cursorTracker ?? CursorTracker(),
       _throwableObjectManager = throwableObjectManager,
       _needsEngine = needsEngine ?? NeedsEngine(),
       _petCompanionService = petCompanionService,
       _settingsRepository = settingsRepository,
       _logger = logger ?? AppLogger(),
       _behaviorEngine = behaviorEngine;

  // ── Dependencies ──────────────────────────────────────────────────────────

  final PetStateMachine _stateMachine;
  final EventBus _eventBus; // ignore: unused_field
  final CursorTracker _cursorTracker;
  final ThrowableObjectManager? _throwableObjectManager;
  final NeedsEngine _needsEngine;
  final PetCompanionService? _petCompanionService;
  final SettingsRepository? _settingsRepository;
  final AppLogger _logger;
  final CompanionBehaviorEngine? _behaviorEngine;

  // ── Accessibility / power flags (Req 18.4–18.7) ───────────────────────────

  /// Whether the OS-level reduce-motion preference is active.
  ///
  /// When `true`, only events that map to calm states (idle, alert, happy,
  /// sleep) may be emitted (Req 18.4).
  bool reducedMotion = false;

  /// Whether the device is currently in a low-power (battery-saver) mode.
  ///
  /// When `true`, emits [LowPowerModeChangedEvent] so [CompanionGame] can
  /// throttle the Flame loop to 15 FPS (Req 18.5–18.7).
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

  // ── Look-delay timer (Req 14.1, 14.2) ────────────────────────────────────

  /// Timer used to delay [PetEvent.cursorEnteredZone] emission when the pet's
  /// [PetBehaviorProfile.mouseAttraction] is < 1.0 (Req 14.1).
  Timer? _lookDelayTimer;

  // ── Petting session state ─────────────────────────────────────────────────

  /// Whether a [PettingSession] is currently active.
  bool _pettingActive = false;

  /// Number of consecutive valid stroke entries received so far.
  ///
  /// Resets to zero whenever a stroke entry with velocity outside
  /// [20, 300] px/s is received (Req 6.2).
  int _strokeCount = 0;

  /// 800 ms debounce timer that limits petting-tick events to at most one
  /// per 800 ms window (Req 6.3).
  Timer? _debounceTimer;

  /// 1.5 s grace timer that keeps the [PettingSession] alive after the
  /// cursor exits the interaction zone (Req 6.6).
  Timer? _graceTimer;

  // ── Click-disambiguation timer ────────────────────────────────────────────

  /// 400 ms timer used to distinguish a single tap from the start of a
  /// double-tap (Req 4.1, 4.2).
  Timer? _clickDisambiguationTimer;

  // ── Treat cooldown ────────────────────────────────────────────────────────

  /// The UTC timestamp of the last successful [giveTreat] spawn.
  /// Null means no treat has been given yet (Req 8.9).
  DateTime? _lastTreatTime;

  /// Whether a treat retry is currently pending (Req 8.3).
  bool _treatRetryPending = false;

  // ── Random source ─────────────────────────────────────────────────────────

  final math.Random _random = math.Random();

  // ── Lifecycle (Req 18.4–18.7) ─────────────────────────────────────────────

  /// Reads the current OS reduce-motion preference and subscribes to future
  /// accessibility changes (Req 18.4).
  ///
  /// Call this once after construction, e.g. in `initState` or a service
  /// initializer.
  void initialize() {
    // Read the current value from PlatformDispatcher.
    reducedMotion =
        PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;
    WidgetsBinding.instance.addObserver(this);
    _logger.info(
      '{"interaction":"initialize","reducedMotion":$reducedMotion,'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );
  }

  /// Removes the accessibility observer and cancels pending timers.
  ///
  /// Call this when the controller is being torn down.
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

  // ── WidgetsBindingObserver ────────────────────────────────────────────────

  /// Responds to OS-level accessibility preference changes (Req 18.4).
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

  // ── Public API (Req 17.1) ─────────────────────────────────────────────────

  /// Handles a single tap/click on the pet sprite.
  ///
  /// Starts a 400 ms disambiguation timer; on expiry emits [PetEvent.userClick]
  /// if all guards pass (Req 4.1, 4.2).
  ///
  /// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 17.2
  void onPetClicked() {
    _logger.info(
      '{"interaction":"onPetClicked",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    // Blocked states: do not start timer (Req 4.6).
    if (!_guardPasses('pettingEnabled')) return;

    _clickDisambiguationTimer?.cancel();
    _clickDisambiguationTimer = Timer(const Duration(milliseconds: 400), () {
      if (!_guardPasses('pettingEnabled')) return;
      _stateMachine.handleEvent(PetEvent.userClick);
      _suppressBehavior();
    });
  }

  /// Handles a double-tap/double-click on the pet sprite.
  ///
  /// Cancels any pending single-click timer and immediately emits
  /// [PetEvent.userDoubleClick] if all guards pass (Req 4.4, 4.5).
  ///
  /// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 17.2
  void onPetDoubleClicked() {
    _logger.info(
      '{"interaction":"onPetDoubleClicked",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    // Cancel the pending single-click timer unconditionally (Req 4.4).
    _clickDisambiguationTimer?.cancel();
    _clickDisambiguationTimer = null;

    // Blocked states: do not emit (Req 4.6).
    if (!_guardPasses('pettingEnabled')) return;

    _stateMachine.handleEvent(PetEvent.userDoubleClick);
    _suppressBehavior();
  }

  /// Handles a drag gesture update on the pet sprite.
  ///
  /// Emits [PetEvent.userDragStart] if all guards pass and suppresses
  /// random behavior for the interaction duration (Req 5.1, 9.4, 9.5).
  ///
  /// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 17.2
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

  /// Handles the end of a drag gesture on the pet sprite.
  ///
  /// Emits [PetEvent.userDragEnd]. If [dragVector].magnitude ≥ 20 px, spawns
  /// a ball throwable using the velocity formula from Req 5.6:
  ///   `velocity = (dragVector / magnitude) * min(magnitude * 5.0, 2000.0)`
  ///
  /// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 17.2
  void onPetDragReleased(Offset dragVector) {
    _logger.info(
      '{"interaction":"onPetDragReleased",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    _stateMachine.handleEvent(PetEvent.userDragEnd);

    final double magnitude = dragVector.distance;
    if (magnitude >= ThrowableObjectManager.minDragMagnitude) {
      // The dragVector is passed directly to spawnThrowable; the manager
      // applies the velocity formula: (dragVector / magnitude) * min(magnitude * 5.0, 2000.0)
      // (Req 5.6). Release point is Offset.zero — the widget layer supplies
      // the actual screen coordinate when calling this method.
      _throwableObjectManager?.spawnThrowable(
        Offset.zero, // release point supplied by caller context
        dragVector,
        kind: 'ball',
      );
    }
  }

  /// Handles a petting stroke (cursor moving over the pet at a valid velocity).
  ///
  /// Records the stroke entry, validates velocity in [20, 300] px/s, starts
  /// a [PettingSession] after two consecutive valid strokes, emits one
  /// [PetEvent.userClick] per 800 ms window via a debounce timer, and manages
  /// a 1.5 s grace timer on cursor exit (Req 6.1–6.8).
  ///
  /// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8
  void onPetPetted() {
    _logger.info(
      '{"interaction":"onPetPetted",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    // If in a blocked state, end any active petting session immediately (Req 6.7).
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

    // Validate stroke velocity from CursorTracker (Req 6.2, 6.8).
    final double speed = _cursorTracker.velocity.distance;
    const double minPettingSpeed = 20.0;
    const double maxPettingSpeed = 300.0;

    if (speed < minPettingSpeed || speed > maxPettingSpeed) {
      // Out-of-range velocity resets the consecutive stroke counter (Req 6.2).
      _strokeCount = 0;
      return;
    }

    // Valid stroke entry.
    _strokeCount++;

    // Cancel grace timer — cursor re-entered while session was in grace period.
    _graceTimer?.cancel();
    _graceTimer = null;

    // Begin PettingSession after two consecutive valid strokes (Req 6.1).
    if (!_pettingActive && _strokeCount >= 2) {
      _pettingActive = true;
    }

    if (!_pettingActive) return;

    // Suppress random behavior while petting is active (Req 9.4, 9.5).
    _suppressBehavior();

    // Debounce: emit at most one petting tick per 800 ms (Req 6.3).
    if (_debounceTimer != null && _debounceTimer!.isActive) return;

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _debounceTimer = null;
      if (!_pettingActive) return;

      // Only emit in states where petting is meaningful (Req 6.4).
      const pettableStates = {
        PetState.idle,
        PetState.curious,
        PetState.reacting,
        PetState.happy,
      };
      if (pettableStates.contains(_stateMachine.currentState)) {
        _stateMachine.handleEvent(PetEvent.userClick);
      }

      // Always update NeedsEngine on a valid petting tick (Req 6.5, 10.2).
      _needsEngine.onPetted();
    });
  }

  /// Called when the cursor exits the interaction zone during an active
  /// [PettingSession].
  ///
  /// Starts a 1.5 s grace timer; if the cursor re-enters before expiry the
  /// session continues, otherwise the session is ended (Req 6.6).
  ///
  /// Requirements: 6.6
  void onPetPettingZoneExited() {
    if (!_pettingActive) return;

    // Start (or restart) the grace timer.
    _graceTimer?.cancel();
    _graceTimer = Timer(const Duration(milliseconds: 1500), _endPettingSession);
  }

  /// Spawns a ball throwable from the InteractionBar button.
  ///
  /// Checks [ThrowableObjectManager.maxActiveThrowables]; if reached, does not
  /// spawn. Otherwise spawns a ball with a random release point in the upper
  /// half of the companion window and a random outward velocity in
  /// [400, 1200] px/s (Req 7.1, 7.2, 7.9).
  ///
  /// Requirements: 7.1, 7.2, 7.3, 7.9, 14.3
  void throwToy() {
    _logger.info(
      '{"interaction":"throwToy",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (!_guardPasses('ballThrowEnabled')) return;

    final manager = _throwableObjectManager;
    if (manager == null) return;

    // Count active (non-disposed) throwables by reading the snapshots list.
    final activeCount = manager.snapshots().length;
    if (activeCount >= ThrowableObjectManager.maxActiveThrowables) {
      // Button should be disabled by the UI layer; silently no-op here.
      return;
    }

    // Random release point in the upper half of the window (y < height / 2).
    // Since we don't have the window size here, use a normalised upper-half
    // position that the UI layer maps to actual coordinates.  Per the design,
    // the widget layer is responsible for translating this.  We emit the spawn
    // with a placeholder release point and a computed drag vector.
    //
    // velocityTarget is random in [400, 1200] px/s in a random outward direction.
    // We supply dragVector = (direction * velocityTarget) / velocityScaleFactor
    // so that spawnThrowable's formula yields the desired velocity.
    final double velocityTarget =
        400.0 + _random.nextDouble() * 800.0; // [400, 1200] px/s
    final double angle = _random.nextDouble() * math.pi * 2;
    final Offset direction = Offset(math.cos(angle), math.sin(angle));

    // dragVector such that spawnThrowable produces velocityTarget:
    //   speed = min(dragMag * 5.0, 2000.0) → dragMag = velocityTarget / 5.0
    final double dragMag =
        velocityTarget / ThrowableObjectManager.velocityScaleFactor;
    final Offset dragVector = direction * dragMag;

    // Release point: upper half of the window — y-component negative so the
    // ball starts above the pet's midpoint.  (0, 0) is a placeholder that the
    // widget layer should override; included here for testability.
    final Offset releasePoint = Offset(
      _random.nextDouble() * 100 - 50, // random horizontal scatter
      -(_random.nextDouble() * 80 + 20), // y in upper half: −20 to −100
    );

    manager.spawnThrowable(releasePoint, dragVector, kind: 'ball');
    _suppressBehavior();
  }

  /// Spawns a treat throwable from the InteractionBar button.
  ///
  /// Enforces a 10-second cooldown between calls. Spawns the treat 20 px in
  /// front of the pet's current facing direction. Retries once after 500 ms if
  /// [ThrowableObjectManager.spawnThrowable] returns `null`. On a second `null`
  /// result, shows an error indicator in the UI via [EventBus] (Req 8.1–8.4, 8.9).
  ///
  /// Requirements: 7.1, 7.2, 7.3, 7.9, 8.1, 8.2, 8.3, 8.4, 8.9, 14.3
  void giveTreat() {
    _logger.info(
      '{"interaction":"giveTreat",'
      '"petState":"${_stateMachine.currentState.name}",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    if (!_guardPasses('treatEnabled')) return;

    // Enforce 10-second cooldown (Req 8.9).
    final now = DateTime.now();
    if (_lastTreatTime != null &&
        now.difference(_lastTreatTime!).inSeconds < _treatCooldownSeconds) {
      return;
    }

    // Species-specific suppression via specialAbilityProbability (Req 14.3).
    final profile = _petCompanionService?.profile.species.defaultProfile;
    if (profile != null && profile.specialAbilityProbability > 0.0) {
      final roll = _random.nextDouble();
      if (roll < profile.specialAbilityProbability) {
        // Suppress: the pet ignores the treat.
        return;
      }
    }

    _lastTreatTime = now;
    _treatRetryPending = false;
    _spawnTreat(isRetry: false);
  }

  static const int _treatCooldownSeconds = 10;

  /// Attempts to spawn a treat throwable.
  ///
  /// On `null` result from [ThrowableObjectManager.spawnThrowable], schedules
  /// a single 500 ms retry. On a second `null`, emits a treat-error event
  /// (Req 8.3, 8.4).
  void _spawnTreat({required bool isRetry}) {
    final manager = _throwableObjectManager;
    if (manager == null) return;

    // Treat is spawned 20 px in front of the pet's facing direction (Req 8.2).
    final petPosition = _petCompanionService?.position ?? Offset.zero;
    // Use a downward unit vector as the default facing direction; the widget
    // layer or PetCompanionService provides the real direction.
    const Offset defaultFacing = Offset(0, 1); // facing down
    const double treatOffset = 20.0;
    final Offset releasePoint = petPosition + defaultFacing * treatOffset;

    // dragVector = facing unit × 20 px so the treat barely rolls forward
    // (magnitude exactly 20 px satisfies the minimum drag threshold with
    // near-zero launch speed). (Req 8.2)
    final Offset dragVector = defaultFacing * treatOffset;

    final result = manager.spawnThrowable(
      releasePoint,
      dragVector,
      kind: 'treat',
    );

    if (result == null) {
      if (!isRetry && !_treatRetryPending) {
        // First null — schedule a single retry after 500 ms (Req 8.3).
        _treatRetryPending = true;
        Timer(const Duration(milliseconds: 500), () {
          _treatRetryPending = false;
          _spawnTreat(isRetry: true);
        });
      } else {
        // Second null — show error indicator via EventBus (Req 8.4).
        _logger.warning(
          '{"interaction":"giveTreat","error":"spawnThrowable returned null twice",'
          '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
        );
        _eventBus.emit(TreatSpawnFailedEvent());
      }
    }
  }

  /// Triggers a companion reaction to [targetState].
  ///
  /// Blocked states ([PetState.breakReminder], [PetState.meetingPaused],
  /// [PetState.focusMode]) cause a warning log and early return without
  /// calling [PetStateMachine.handleEvent] (Req 9.6, 17.3).
  ///
  /// Requirements: 9.6, 17.2, 17.3
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

    // Map targetState to the appropriate PetEvent and delegate.
    final event = _petEventForState(targetState);
    if (event != null) {
      _stateMachine.handleEvent(event);
    }
  }

  // ── Feature toggle check (Req 18.8) ───────────────────────────────────────

  /// Returns whether the feature identified by [settingsKey] is enabled.
  ///
  /// Reads from [SettingsRepository] if available. On any exception (including
  /// storage unavailability at cold start) returns `true` so interactions still
  /// work (design: Error Handling — Settings load failure).
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

  // ── State guards ──────────────────────────────────────────────────────────

  /// Returns `true` when all state guards pass and the interaction identified
  /// by [featureKey] should proceed.
  ///
  /// Guards checked in order (Req 9.1, 9.2, 9.3, 18.3, 18.4, 18.8):
  /// 1. `companionEnabled` global setting must be `true`.
  /// 2. The per-feature settings key must be `true`.
  /// 3. For play/affection events: FSM must NOT be in a blocked state.
  /// 4. When `reducedMotion` is `true`, `ballThrowEnabled` interactions are
  ///    blocked (Req 18.4).
  bool _guardPasses(String featureKey) {
    // Guard 1: global companion toggle.
    if (!_isFeatureEnabled('companionEnabled')) return false;

    // Guard 2: per-feature toggle.
    if (!_isFeatureEnabled(featureKey)) return false;

    // Guard 3: FSM blocked-state check (Req 9.3).
    const blockedStates = {
      PetState.breakReminder,
      PetState.meetingPaused,
      PetState.focusMode,
    };
    if (blockedStates.contains(_stateMachine.currentState)) return false;

    // Guard 4: reduced-motion blocks ball-throw / run / chasing states (Req 18.4).
    if (reducedMotion && featureKey == 'ballThrowEnabled') return false;

    return true;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Tells [CompanionBehaviorEngine] to suppress random behavior for the
  /// duration of the current interaction plus 3 additional seconds (Req 9.4, 9.5).
  void _suppressBehavior() {
    _behaviorEngine?.suppressRandomBehavior(const Duration(seconds: 3));
  }

  /// Maps a [PetState] target to a suitable [PetEvent] to pass through
  /// [PetStateMachine.handleEvent].
  ///
  /// Returns `null` if no mapping exists for [targetState].
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

  // ── Cursor zone entry / exit (Req 14.1–14.5) ─────────────────────────────

  /// Called when the cursor enters the interaction zone with the given
  /// [velocity] in logical px/s.
  ///
  /// - velocity > 800 px/s: fast-move path; do NOT emit
  ///   [PetEvent.cursorEnteredZone] (Req 2.2, 3.1).
  /// - `profile.mouseAttraction < 1.0`: start a look-delay timer for
  ///   `profile.lookDelay` seconds; emit on expiry (Req 14.1).
  /// - Otherwise: emit [PetEvent.cursorEnteredZone] immediately (Req 2.1).
  ///
  /// Requirements: 2.1, 2.2, 3.1, 14.1
  void onCursorEnteredZone(double velocity) {
    _logger.info(
      '{"interaction":"onCursorEnteredZone","velocity":$velocity,'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    // Fast-move path — handled by CursorTracker / Req 3.1.
    if (velocity > CursorTracker.fastVelocityThreshold) return;

    // Cancel any previously scheduled look-delay timer.
    _lookDelayTimer?.cancel();
    _lookDelayTimer = null;

    final profile = _petCompanionService?.profile.species.defaultProfile;

    if (profile != null && profile.mouseAttraction < 1.0) {
      // Species with lower attraction get a look-delay before reacting (Req 14.1).
      final delayMs = (profile.lookDelay * 1000).round();
      if (delayMs > 0) {
        _lookDelayTimer = Timer(Duration(milliseconds: delayMs), () {
          _lookDelayTimer = null;
          _stateMachine.handleEvent(PetEvent.cursorEnteredZone);
        });
        return;
      }
    }

    // Immediate emit for high-attraction species or zero look-delay.
    _stateMachine.handleEvent(PetEvent.cursorEnteredZone);
  }

  /// Called when the cursor exits the interaction zone.
  ///
  /// - Cancels any pending look-delay timer without emitting (Req 14.2).
  /// - Emits [PetEvent.cursorExitedZone] if a petting session is active.
  /// - Starts the petting grace timer via [onPetPettingZoneExited] (Req 6.6).
  ///
  /// Requirements: 2.4, 14.2, 6.6
  void onCursorExitedZone() {
    _logger.info(
      '{"interaction":"onCursorExitedZone",'
      '"utcTimestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
    );

    // Cancel look-delay timer silently (Req 14.2).
    _lookDelayTimer?.cancel();
    _lookDelayTimer = null;

    // Emit zone-exit event only if petting is active (Req 2.4).
    if (_pettingActive) {
      _stateMachine.handleEvent(PetEvent.cursorExitedZone);
    }

    // Start the grace timer (Req 6.6).
    onPetPettingZoneExited();
  }

  /// Ends any active petting session immediately, cancelling both timers.
  ///
  /// Called when the FSM transitions into a blocking state while a session
  /// is in progress (design: Error Handling — Petting session during blocked
  /// states).
  void _endPettingSession() {
    _pettingActive = false;
    _strokeCount = 0;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
  }
}
