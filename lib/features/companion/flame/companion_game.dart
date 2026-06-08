import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_needs.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_personality.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/flame/companion_component.dart';
import 'package:breakmate/features/companion/flame/micro_particle_factory.dart';
import 'package:breakmate/features/companion/ai/pet_behavior_brain.dart';
import 'package:breakmate/features/companion/services/constraint_window_controller.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/features/companion/services/pet_companion_service.dart';
import 'package:breakmate/features/companion/services/pet_navigation_service.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';
import 'package:breakmate/features/companion/services/settings_persistence.dart';
import 'package:breakmate/features/companion/services/throwable_object_manager.dart';
import 'package:breakmate/features/companion/services/window_monitor.dart';

class CompanionGame extends FlameGame {
  CompanionGame({
    required PetTheme initialTheme,
    this.scaleOverride = 0.0,
    this.isPiP = false,
    this.toyType = 'tennis_ball',
    this.treatType = 'sushi',
  }) : _eventBus = EventBus.instance,
       _petService = PetCompanionService(
         stateMachine: PetStateMachine(personality: PetPersonality()),
         brain: PetBehaviorBrain(),
         navigation: PetNavigationService(),
         profile: getProfileFromTheme(initialTheme),
       ),
       _theme = initialTheme;

  final bool isPiP;
  String toyType;
  String treatType;

  static PetProfile getProfileFromTheme(PetTheme theme) {
    final species = theme.species;
    final variant = PetVariant(
      id: theme.id,
      name: theme.name,
      assetPath: theme.basePath,
      isSpriteSheet: theme.type == PetType.composite,
    );
    return PetProfile(
      id: theme.id,
      name: theme.name,
      species: species,
      variant: variant,
    );
  }

  final EventBus _eventBus;
  final PetCompanionService _petService;
  late StreamSubscription<AppEvent> _eventSubscription;
  late StreamSubscription<PetState> _petStateSubscription;

  // --- Behavior-engine subsystems (task 17.1) ---
  late final SettingsPersistence _settingsPersistence;
  late final NativeDisplayManager _displayManager;
  late final CursorTracker _cursorTracker;
  late final NativeWindowMonitor _windowMonitor;
  late final PhysicsSimulator _physicsSimulator;
  late final ThrowableObjectManager _throwableManager;
  NativeConstraintWindowController? _constraintWindowController;
  PetConfigV2 _petConfig = PetConfigV2.defaults();

  PetTheme _theme;
  double scaleOverride; // 0.0 = auto-scale
  bool _lastGroomWasLick1 = false; // alternates lick1 → lick2 → lick1 …

  // --- Drag-gesture tracking (task 17.4, req 7.1) ---
  Offset? _dragStartPosition;
  bool _isDragging = false;

  // ── Task 8.1 – QuietMode bitmask (Req 15.1–15.7) ──────────────────────────
  // Bit 0x01 = focus mode, 0x02 = meeting, 0x04 = low power
  int _quietModeTriggers = 0;

  /// `true` when any QuietMode trigger is active.
  bool get isQuietMode => _quietModeTriggers != 0;

  // ── Task 8.2 – NeedsEngine (Req 10.2–10.9) ────────────────────────────────
  late final NeedsEngine _needsEngine;
  bool _isPettingActive = false;
  Duration _workSessionElapsed = Duration.zero;

  // ── Task 8.3 – Particle-trigger tracking (Req 13.1–13.7) ─────────────────
  // Tracks how long the pet has been in PetState.sleep continuously.
  double _sleepParticleElapsed = 0.0;
  // True while a sleep-bubble particle is currently alive.
  bool _sleepBubbleActive = false;
  // Counts down the current bubble lifespan so we know when to reset.
  double _sleepBubbleCooldown = 0.0;
  // Duration of a single sleepBubble particle (must match MicroParticleFactory).
  static const double _sleepBubbleDuration = 2.0;
  // Previous state — used to detect eating→happy and idle celebrating transitions.
  PetState _previousState = PetState.idle;
  double _totalTime = 0.0;

  // ── Task 8.5 – DeveloperReactionController ────────────────────────────────
  late final _DeveloperReactionController _devReaction;

  ui.Image? mouseImage;
  ui.Image? pinkBallImage;
  ui.Image? orangeBallImage;
  ui.Image? blueBallImage;
  ui.Image? bunnyFoodsImage;
  ui.Image? dogItemsImage;

  CompanionComponent? petComponent;

  PetTheme get currentTheme => _theme;
  PetState get companionState => _petService.currentState;
  PetCompanionService get petService => _petService;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    // 1. Guard: only macOS and Windows are supported (req 1.8).
    if (!Platform.isMacOS && !Platform.isWindows) {
      _eventBus.emit(
        PlatformErrorEvent(
          message:
              'Unsupported platform. Only macOS and Windows are supported.',
        ),
      );
      return;
    }

    // 2. Load settings before the first tick (req 11.1).
    _settingsPersistence = SettingsPersistence();
    _petConfig = _settingsPersistence.loadSync();

    // 3. Initialise subsystems.
    _physicsSimulator = PhysicsSimulator();
    _displayManager = NativeDisplayManager();
    _cursorTracker = CursorTracker();
    _windowMonitor = NativeWindowMonitor();
    _throwableManager = ThrowableObjectManager(
      physicsSimulator: _physicsSimulator,
    );

    // Task 8.2: Initialise NeedsEngine and restore persisted state (Req 10.9).
    _needsEngine = NeedsEngine(logger: AppLogger());
    _needsEngine.restore();

    // Task 8.5: Initialise developer-reaction controller.
    _devReaction = _DeveloperReactionController(game: this);

    // 4. Enumerate displays with 500ms timeout (req 1.5, 1.6, 1.7).
    List<DisplayBounds> displays;
    try {
      displays = await _displayManager.enumerateDisplays().timeout(
        const Duration(milliseconds: 500),
      );
    } catch (_) {
      _eventBus.emit(
        PlatformErrorEvent(
          message: 'Display enumeration timed out or failed. Terminating.',
        ),
      );
      exit(1);
    }

    if (displays.isEmpty) {
      _eventBus.emit(
        PlatformErrorEvent(
          message: 'No displays found after enumeration. Terminating.',
        ),
      );
      exit(1);
    }

    // 5. Apply loaded config to physics boundary.
    if (isPiP) {
      _physicsSimulator.setBoundary(
        Rect.fromLTWH(0, 24.0, size.x, size.y - 24.0 - 44.0),
      );
    } else {
      _physicsSimulator.setBoundary(_displayManager.unionBounds);
      if (_petConfig.mode == PetMode.singleDisplay &&
          _petConfig.pinnedDisplayId != null) {
        final pinned = displays.cast<DisplayBounds?>().firstWhere(
          (d) => d?.id == _petConfig.pinnedDisplayId,
          orElse: () => null,
        );
        if (pinned != null) _physicsSimulator.setBoundary(pinned.rect);
      }
    }

    // 6. Set up constraint window controller if in constrained mode.
    if (_petConfig.mode == PetMode.constrained) {
      _constraintWindowController = NativeConstraintWindowController(
        physicsSimulator: _physicsSimulator,
        displays: displays,
      );
      await _constraintWindowController!.show(
        initialSize: _petConfig.constraintWindowBounds.size,
      );
      _physicsSimulator.setConstraintBoundary(
        _constraintWindowController!.bounds,
      );
    }

    // Load toy/treat sprites
    try {
      mouseImage = await PetAssetLoader.loadImage('assets/ui/icons/mouse_sheet.png');
      pinkBallImage = await PetAssetLoader.loadImage('assets/ui/icons/pinkball_sheet.png');
      orangeBallImage = await PetAssetLoader.loadImage('assets/ui/icons/orangeball_sheet.png');
      bunnyFoodsImage = await PetAssetLoader.loadImage('assets/characters/pets/bunnyfoods_2.png');
      dogItemsImage = await PetAssetLoader.loadImage('assets/characters/pets/dogitems_2.png');
    } catch (e) {
      debugPrint('Error loading companion toy/treat assets: $e');
    }

    // 7. Existing initialization.
    await super.onLoad();
    _eventSubscription = _eventBus.stream.listen(_handleAppEvent);
    _petStateSubscription = _petService.stateMachine.stateStream.listen((
      state,
    ) {
      _applyPetStateToComponent(state);
    });
    _petService.initialize(
      screenSize: Size(size.x, size.y),
      startPosition: _petConfig.lastAnchorPoint != Offset.zero
          ? _petConfig.lastAnchorPoint
          : null,
    );
    await _loadAndAttachPet();
  }

  @override
  void onRemove() {
    _eventSubscription.cancel();
    _petStateSubscription.cancel();
    _petService.stateMachine.dispose();
    _petService.dispose();
    // Task 8.2: Persist NeedsEngine state on removal (Req 10.9).
    _needsEngine.persist();
    super.onRemove();
  }

  void _handleAppEvent(AppEvent event) {
    _mapAppEventToPetEvent(event);
  }

  void _mapAppEventToPetEvent(AppEvent event) {
    PetEvent? petEvent;

    if (event is CompanionStateChangedEvent) {
      _applyCompanionState(event.state);
      return;
    }

    // TimerStateChangedEvent is NOT mapped to PetEvent.tick — the update() loop
    // already fires tick at 1 Hz. Mapping it here caused double-ticks every
    // timer update, which jittered the FSM.
    if (event is TimerStateChangedEvent) {
      // Sync context flags so the AI brain has accurate app state
      _petService.syncContextFlags(
        isBreakActive: event.state == TimerStateEvent.breakActive,
        isIdle: event.state == TimerStateEvent.idle,
        totalWorkTodaySeconds: event.totalWorkTodaySeconds,
      );
      _workSessionElapsed = Duration(seconds: event.workElapsedSeconds);
      // Task 8.5: forward to developer-reaction controller (Req 11.6).
      _devReaction.onTimerStateChanged(event);
      return;
    } else if (event is BreakStartedEvent) {
      _petService.syncContextFlags(isBreakActive: true);
      petEvent = PetEvent.breakStarted;
      // Task 8.5: forward to developer-reaction controller (Req 11.2).
      _devReaction.onBreakStarted(event);
    } else if (event is BreakEndedEvent) {
      _petService.syncContextFlags(isBreakActive: false);
      petEvent = PetEvent.breakEnded;
      // Task 8.5: forward to developer-reaction controller (Req 12.2, 12.3).
      _devReaction.onBreakEnded(event);
    } else if (event is MeetingDetectedEvent) {
      _petService.syncContextFlags(isMeetingDetected: event.isActive);
      petEvent = event.isActive
          ? PetEvent.meetingDetected
          : PetEvent.meetingEnded;
      // Task 8.1: set/clear QuietMode bit 0x02 (Req 15.2).
      _updateQuietModeBit(0x02, event.isActive);
      // Task 8.5: forward to developer-reaction controller (Req 11.4, 11.5).
      _devReaction.onMeetingDetected(event);
    } else if (event is FocusModeEvent) {
      _petService.syncContextFlags(isFocusMode: event.isActive);
      petEvent = event.isActive ? PetEvent.focusModeOn : PetEvent.focusModeOff;
      // Task 8.1: set/clear QuietMode bit 0x01 (Req 15.1).
      _updateQuietModeBit(0x01, event.isActive);
    } else if (event is LowPowerModeChangedEvent) {
      // Task 8.1: set/clear QuietMode bit 0x04 (Req 15.3).
      _updateQuietModeBit(0x04, event.isLowPower);
      updateEnergyStatus(isLowPowerMode: event.isLowPower);
      return;
    } else if (event is IdleDetectedEvent) {
      _petService.syncContextFlags(isIdle: event.isIdle);
      petEvent = event.isIdle
          ? PetEvent.idleTimeout
          : PetEvent.activityDetected;
    } else if (event is CompanionInteractionEvent) {
      switch (event.interactionType) {
        case 'tap':
        case 'click':
          petEvent = PetEvent.userClick;
          break;
        case 'doubleTap':
        case 'doubleClick':
          petEvent = PetEvent.userDoubleClick;
          break;
        case 'hover':
          petEvent = PetEvent.userHover;
          break;
        case 'dragStart':
        case 'drag':
          petEvent = PetEvent.userDragStart;
          break;
        case 'dragEnd':
          petEvent = PetEvent.userDragEnd;
          break;
        case 'stretch':
          _applyPetStateToComponent(PetState.stretch);
          return;
        case 'happy':
          _applyPetStateToComponent(PetState.happy);
          return;
        case 'blink':
          _applyPetStateToComponent(PetState.blink);
          return;
        // Task 8.3: petting interaction sets active flag (Req 13.1).
        case 'petting':
          _isPettingActive = true;
          return;
        case 'pettingEnd':
          _isPettingActive = false;
          return;
      }
    }
    if (petEvent != null) {
      _petService.handleEvent(petEvent);
    }

    // --- Behavior-engine event → FSM mappings (task 17.3) ---
    if (event is CursorEnteredZoneEvent) {
      _petService.handleEvent(PetEvent.cursorEnteredZone);
    } else if (event is CursorExitedZoneEvent) {
      _petService.handleEvent(PetEvent.cursorExitedZone);
    } else if (event is CursorDwellEvent) {
      _petService.handleEvent(PetEvent.cursorDwell);
    } else if (event is CursorFastMoveEvent) {
      _petService.handleEvent(PetEvent.cursorFastMove);
    } else if (event is ThrowableSpawnedEvent) {
      _petService.handleEvent(PetEvent.throwableSpawned);
    } else if (event is ThrowableStationaryEvent) {
      _petService.handleEvent(PetEvent.throwableStationary);
      // Task 8.3: spawn bounce particle at throwable position (Req 13.5).
      _spawnBounceParticle();
    } else if (event is ThrowableFetchedEvent) {
      _petService.handleEvent(PetEvent.throwableFetched);
    } else if (event is ThrowableReturnedEvent) {
      _petService.handleEvent(PetEvent.throwableReturned);
    } else if (event is ThrowableDisposedEvent) {
      // throwable disposed (e.g. timeout or unreachable) → return pet to idle
      _petService.handleEvent(PetEvent.throwableReturned);
    } else if (event is PetWindowOverlapEvent) {
      if (event.started) {
        _petService.handleEvent(PetEvent.windowOverlap);
      } else {
        _petService.handleEvent(PetEvent.windowOverlapEnded);
      }
    } else if (event is PetStandingSurfaceLostEvent) {
      _petService.handleEvent(PetEvent.surfaceLost);
    } else if (event is PetLandedEvent) {
      _petService.handleEvent(PetEvent.landedOnSurface);
    } else if (event is PlatformErrorEvent) {
      // Surface platform errors in the UI and terminate.
      debugPrint('[PlatformError] ${event.message}');
      exit(1);
    } else if (event is ConstraintWindowBoundsChangedEvent) {
      _constraintWindowController?.onBoundsChanged(event.bounds);
    } else if (event is DisplayDisconnectedEvent) {
      // If the pinned display was disconnected, revert to free-roam.
      if (_petConfig.mode == PetMode.singleDisplay &&
          _petConfig.pinnedDisplayId == event.displayId) {
        _petConfig = _petConfig.copyWith(
          mode: PetMode.freeRoam,
          pinnedDisplayId: null,
        );
        if (isPiP) {
          _physicsSimulator.setBoundary(
            Rect.fromLTWH(0, 24.0, size.x, size.y - 24.0 - 44.0),
          );
        } else {
          _physicsSimulator.setBoundary(_displayManager.unionBounds);
        }
        _settingsPersistence.scheduleWrite(_petConfig);
      }
    }
  }

  // ── Task 8.1 – QuietMode helpers (Req 15.1–15.7) ─────────────────────────

  void _updateQuietModeBit(int bit, bool active) {
    final bool wasQuiet = isQuietMode;
    if (active) {
      _quietModeTriggers |= bit;
    } else {
      _quietModeTriggers &= ~bit;
    }
    final bool nowQuiet = isQuietMode;
    if (!wasQuiet && nowQuiet) {
      _onQuietModeActivated();
    } else if (wasQuiet && !nowQuiet) {
      _onQuietModeDeactivated();
    }
  }

  void _onQuietModeActivated() {
    // QuietMode speed multiplier (0.6) is applied dynamically inside CompanionComponent.update()
    // Remove all in-flight ParticleSystemComponent children.
    for (final particle
        in children.whereType<ParticleSystemComponent>().toList()) {
      particle.removeFromParent();
    }
    _sleepBubbleActive = false;
  }

  void _onQuietModeDeactivated() {
    // QuietMode speed multiplier (0.6) is reverted to 1.0 dynamically inside CompanionComponent.update()
  }

  // ── Task 8.3 – Particle helpers ───────────────────────────────────────────

  void _spawnParticle(ParticleSystemComponent? component) {
    if (component != null) {
      add(component);
    }
  }

  void _spawnBounceParticle() {
    final pos = _petCenter;
    _spawnParticle(MicroParticleFactory.bounce(pos, quietMode: isQuietMode));
  }

  void _onPettingTick() {
    final pos = _petCenter;
    _spawnParticle(MicroParticleFactory.heart(pos, quietMode: isQuietMode));
  }

  void _onEatingToHappy() {
    final pos = _petCenter;
    _spawnParticle(MicroParticleFactory.crumbs(pos, quietMode: isQuietMode));
  }

  void _onCelebratingEntered() {
    final pos = _petCenter;
    _spawnParticle(MicroParticleFactory.sparkle(pos, quietMode: isQuietMode));
  }

  void _tickSleepBubble(double dt) {
    if (_petService.currentState != PetState.sleep) {
      _sleepParticleElapsed = 0.0;
      _sleepBubbleActive = false;
      _sleepBubbleCooldown = 0.0;
      return;
    }

    _sleepParticleElapsed += dt;

    if (_sleepBubbleActive) {
      // Count down while the bubble is alive; once its lifespan ends, reset.
      _sleepBubbleCooldown -= dt;
      if (_sleepBubbleCooldown <= 0.0) {
        _sleepBubbleActive = false;
      }
      return;
    }

    // Only spawn after 3 s of continuous sleep.
    if (_sleepParticleElapsed >= 3.0) {
      final pos = _petCenter;
      final component = MicroParticleFactory.sleepBubble(
        pos,
        quietMode: isQuietMode,
      );
      if (component != null) {
        _sleepBubbleActive = true;
        _sleepBubbleCooldown = _sleepBubbleDuration;
        add(component);
      }
    }
  }

  void _applyCompanionState(CompanionState state) {
    switch (state) {
      case CompanionState.idle:
        _petService.stateMachine.transitionTo(PetState.idle);
      case CompanionState.walking:
        _petService.stateMachine.transitionTo(PetState.walk);
      case CompanionState.sleeping:
        _petService.stateMachine.transitionTo(PetState.sleep);
      case CompanionState.alert:
        _petService.stateMachine.transitionTo(PetState.alert);
      case CompanionState.dragging:
        _petService.stateMachine.transitionTo(PetState.drag);
      case CompanionState.happy:
        _petService.stateMachine.transitionTo(PetState.happy);
      case CompanionState.stretch:
        _petService.stateMachine.transitionTo(PetState.stretch);
      case CompanionState.blink:
        _petService.stateMachine.transitionTo(PetState.blink);
      case CompanionState.breakReminder:
        _petService.stateMachine.transitionTo(PetState.breakReminder);
      case CompanionState.meetingPaused:
        _petService.stateMachine.transitionTo(PetState.meetingPaused);
      case CompanionState.focusMode:
        _petService.stateMachine.transitionTo(PetState.focusMode);
      default:
        break;
    }
  }

  void _applyPetStateToComponent(PetState state) {
    final animState = _mapPetStateToAnimationState(state);
    // Guarantee: if the mapped animation doesn't exist, fall back to idle.
    final safeState = (petComponent?.animations?.containsKey(animState) == true)
        ? animState
        : PetAnimationState.idle;
    petComponent?.changeState(safeState);
  }

  PetAnimationState _mapPetStateToAnimationState(PetState state) {
    switch (state) {
      case PetState.idle:
      case PetState.resting:
      case PetState.bored:
      case PetState.quiet:
        return PetAnimationState.idle;
      case PetState.blink:
        return PetAnimationState.blink;
      case PetState.stretch:
        return PetAnimationState.stretch;
      case PetState.celebrating:
      case PetState.dancing:
        return PetAnimationState.celebrate;
      case PetState.walk:
      case PetState.exploring:
      case PetState.following:
      case PetState.turning:
        return PetAnimationState.walkSide;
      case PetState.run:
      case PetState.jumping:
      case PetState.playing:
        return PetAnimationState.run;
      case PetState.sleep:
        return PetAnimationState.sleep;
      case PetState.alert:
      case PetState.curious:
      case PetState.interacting:
      case PetState.scared:
      case PetState.hiding:
      case PetState.angry:
        return PetAnimationState.notification;
      case PetState.happy:
      case PetState.excited:
      case PetState.affectionate:
        return PetAnimationState.excited;
      case PetState.breakReminder:
        return PetAnimationState.breakMode;
      case PetState.meetingPaused:
      case PetState.sad:
        return PetAnimationState.sad;
      case PetState.focusMode:
        return PetAnimationState.focusMode;
      case PetState.grooming:
        // Alternate lick1 → lick2 → lick1 … for a natural grooming sequence.
        if (_theme.animations.containsKey(PetAnimationState.lick1)) {
          _lastGroomWasLick1 = !_lastGroomWasLick1;
          return _lastGroomWasLick1
              ? PetAnimationState.lick1
              : PetAnimationState.lick2;
        }
        return PetAnimationState.idle;
      case PetState.eating:
        return PetAnimationState.idle;
      case PetState.drag:
        return PetAnimationState.idle;
      case PetState.breatheFire:
        return PetAnimationState.breatheFire;
      case PetState.fly:
        return PetAnimationState.fly;
      // Behavior-engine states — mappings completed in task 15.1
      case PetState.chasing:
        return PetAnimationState.chasing;
      case PetState.fetching:
        return PetAnimationState.fetching;
      case PetState.falling:
        return PetAnimationState.falling;
      case PetState.reacting:
        return PetAnimationState.reacting;
    }
  }

  double _effectiveScale(double spriteSize) {
    double scale;
    if (scaleOverride > 0.0) {
      scale = scaleOverride;
    } else {
      final double baselineHeight = size.y > 400.0 ? 300.0 : size.y;
      final double target = baselineHeight * 0.45;
      scale = (target / spriteSize).clamp(3.0, 10.0);
    }

    // Normalize smaller sprites (like 16x16) to the 32x32 baseline visual size
    scale = scale * (32.0 / spriteSize);

    // Enlarge the pet in PiP mode for better visibility
    if (isPiP) {
      scale *= 1.5;
    }

    return scale;
  }

  double _getGroundOffset() {
    if (_petService.profile.species == PetSpecies.flamingo) {
      return _effectiveScale(_theme.spriteSize.toDouble()) * 20.0;
    }
    return 0.0;
  }

  void _updateNavigationPaddings() {
    if (petComponent == null) return;
    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);
    final double scaledHalfW = (spriteSize * scale) / 2;
    final double scaledHalfH = (spriteSize * scale) / 2;
    final double groundOffset = _getGroundOffset();

    double minX = scaledHalfW + 4.0;
    double maxX = size.x - scaledHalfW - 4.0;
    if (minX > maxX) {
      minX = size.x / 2;
      maxX = size.x / 2;
    }

    // Top padding needs to account for the drag handle (24.0 or 32.0, assuming 24.0 here)
    // and the visual offset if the sprite is shifted down.
    double minY = isPiP ? (24.0 + scaledHalfH + 4.0 - groundOffset) : (scaledHalfH + 4.0 - groundOffset);
    
    // Bottom padding needs to account for the interaction bar (44.0)
    // and the visual offset.
    double maxY = isPiP
        ? (size.y - 44.0 - scaledHalfH - 4.0 + groundOffset)
        : (size.y - scaledHalfH - 4.0 + groundOffset);
        
    if (minY > maxY) {
      final double safeCenterY = isPiP
          ? 24.0 + (size.y - 24.0 - 44.0) / 2
          : size.y / 2;
      minY = safeCenterY;
      maxY = safeCenterY;
    }

    _petService.navigation.updatePaddings(
      left: minX,
      right: size.x - maxX,
      top: minY,
      bottom: size.y - maxY,
    );
  }

  Future<void> _loadAndAttachPet() async {
    final animations = await PetAssetLoader.loadAnimations(_petService.profile);
    if (animations.isEmpty) return;

    children.whereType<CompanionComponent>().toList().forEach(
      (c) => c.removeFromParent(),
    );

    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);

    petComponent = CompanionComponent(
      animations: animations,
      initialState: _mapPetStateToAnimationState(_petService.currentState),
    );

    petComponent!.size = Vector2(spriteSize, spriteSize);
    petComponent!.scale = Vector2.all(scale);

    final double scaledHalfW = (spriteSize * scale) / 2;
    final double scaledHalfH = (spriteSize * scale) / 2;
    final double groundOffset = _getGroundOffset();
    final double initialY = isPiP
        ? size.y - 44.0 - scaledHalfH - 4.0 + groundOffset
        : size.y - scaledHalfH - 4.0 + groundOffset;

    petComponent!.position = Vector2(size.x / 2, initialY);

    add(petComponent!);

    _updateNavigationPaddings();

    final currentPos = _petService.navigation.currentPosition;
    final minY = isPiP ? (24.0 + scaledHalfH + 4.0 - groundOffset) : (scaledHalfH + 4.0 - groundOffset);
    final maxY = isPiP
        ? (size.y - 44.0 - scaledHalfH - 4.0 + groundOffset)
        : (size.y - scaledHalfH - 4.0 + groundOffset);
    if (currentPos.dy < minY ||
        currentPos.dy > maxY ||
        currentPos.dx < scaledHalfW + 4.0 ||
        currentPos.dx > size.x - scaledHalfW - 4.0) {
      _petService.navigation.teleport(Offset(size.x / 2, initialY));
    }

    // Always sync the component's visual position to the nav position to
    // prevent a 1-frame jump on first load when the nav position (size.y/2)
    // differs from the initial component placement (initialY near bottom).
    final syncedPos = _petService.navigation.currentPosition;
    petComponent!.position = Vector2(syncedPos.dx, syncedPos.dy);
  }

  Future<void> updateTheme(PetTheme newTheme) async {
    if (_theme.id == newTheme.id && petComponent != null) return;

    // Aggressively clear caches to evict old theme assets
    PetAssetLoader.clearCache();
    Flame.images.clear(_theme.id);

    _theme = newTheme;
    _petService.updateProfile(getProfileFromTheme(newTheme));
    await _loadAndAttachPet();
  }

  void updateScale(double newScale) {
    if (scaleOverride == newScale) return;
    scaleOverride = newScale;
    _applyScale();
  }

  void updateToyType(String newToyType) {
    if (toyType == newToyType) return;
    toyType = newToyType;
  }

  void updateTreatType(String newTreatType) {
    if (treatType == newTreatType) return;
    treatType = newTreatType;
  }

  void _applyScale() {
    if (petComponent == null) return;
    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);
    petComponent!.scale = Vector2.all(scale);

    final double scaledHalfH = (spriteSize * scale) / 2;
    final double groundOffset = _getGroundOffset();
    final double initialY = isPiP
        ? size.y - 44.0 - scaledHalfH - 4.0 + groundOffset
        : size.y - scaledHalfH - 4.0 + groundOffset;

    petComponent!.position = Vector2(petComponent!.position.x, initialY);
    _updateNavigationPaddings();
    _petService.navigation.teleport(Offset(petComponent!.position.x, initialY));
  }

  void triggerState(PetAnimationState state) {
    petComponent?.changeState(state);
  }

  void setWanderingEnabled(bool enabled) {
    petComponent?.setWanderingEnabled(enabled);
  }

  void updateMouseFollow(Map<dynamic, dynamic> data) {
    petComponent?.updateMouseFollow(data);
  }

  void onUserInteraction(String type, {Offset? position}) {
    switch (type) {
      case 'tap':
        _petService.handleEvent(PetEvent.userClick);
        break;
      case 'doubleTap':
        _petService.handleEvent(PetEvent.userDoubleClick);
        break;
      case 'hover':
        _petService.handleEvent(PetEvent.userHover);
        break;
      case 'dragStart':
        _petService.handleEvent(PetEvent.userDragStart);
        if (position != null) onDragStart(position);
        break;
      case 'dragEnd':
        _petService.handleEvent(PetEvent.userDragEnd);
        if (position != null) onDragEnd(position);
        break;
    }
  }

  /// Called when a drag gesture begins (req 7.1).
  void onDragStart(Offset startPosition) {
    _dragStartPosition = startPosition;
    _isDragging = true;
  }

  /// Called when a drag gesture ends (req 7.1).
  ///
  /// If the drag vector is ≥ 20 logical pixels, spawns a throwable object at
  /// [releasePosition] with a velocity derived from the drag direction.
  void onDragEnd(Offset releasePosition) {
    if (_isDragging && _dragStartPosition != null) {
      final Offset dragVector = releasePosition - _dragStartPosition!;
      _throwableManager.spawnThrowable(releasePosition, dragVector);
    }
    _dragStartPosition = null;
    _isDragging = false;
  }

  // --- Mode switching (task 17.5) ---

  /// Switches the pet's movement mode and reconfigures subsystems accordingly.
  ///
  /// * [PetMode.constrained]: creates and shows the [_constraintWindowController]
  ///   if not already present, then notifies physics.
  /// * [PetMode.singleDisplay]: restricts physics boundary to a single display
  ///   — use [setPinnedDisplay] after this call to specify which display.
  /// * [PetMode.freeRoam]: hides the constraint window (if visible), clears
  ///   constraint boundary, and restores the full union boundary.
  ///
  /// Persists the updated config via [_settingsPersistence].
  Future<void> setMode(PetMode mode) async {
    if (_petConfig.mode == mode) return;
    _petConfig = _petConfig.copyWith(mode: mode);

    switch (mode) {
      case PetMode.constrained:
        if (_constraintWindowController == null) {
          final displays = await _displayManager.enumerateDisplays();
          _constraintWindowController = NativeConstraintWindowController(
            physicsSimulator: _physicsSimulator,
            displays: displays,
          );
        }
        await _constraintWindowController!.show(
          initialSize: _petConfig.constraintWindowBounds.size,
        );
        _physicsSimulator.setConstraintBoundary(
          _constraintWindowController!.bounds,
        );

      case PetMode.singleDisplay:
        await _constraintWindowController?.hide();
        _physicsSimulator.setConstraintBoundary(null);
        if (isPiP) {
          _physicsSimulator.setBoundary(
            Rect.fromLTWH(0, 24.0, size.x, size.y - 24.0 - 44.0),
          );
        } else {
          _physicsSimulator.setBoundary(_displayManager.unionBounds);
        }

      case PetMode.freeRoam:
        await _constraintWindowController?.hide();
        _physicsSimulator.setConstraintBoundary(null);
        if (isPiP) {
          _physicsSimulator.setBoundary(
            Rect.fromLTWH(0, 24.0, size.x, size.y - 24.0 - 44.0),
          );
        } else {
          _physicsSimulator.setBoundary(_displayManager.unionBounds);
        }
    }

    _settingsPersistence.scheduleWrite(_petConfig);
  }

  /// Pins the pet to a specific display when in [PetMode.singleDisplay] mode.
  ///
  /// Looks up [displayId] in the current display list and restricts the
  /// physics boundary to that display's rect. If the display is not found, the
  /// boundary falls back to the union of all displays.
  Future<void> setPinnedDisplay(String displayId) async {
    final displays = await _displayManager.enumerateDisplays();
    final DisplayBounds? target = displays.cast<DisplayBounds?>().firstWhere(
      (d) => d?.id == displayId,
      orElse: () => null,
    );
    _petConfig = _petConfig.copyWith(
      mode: PetMode.singleDisplay,
      pinnedDisplayId: displayId,
    );
    if (isPiP) {
      _physicsSimulator.setBoundary(
        Rect.fromLTWH(0, 24.0, size.x, size.y - 24.0 - 44.0),
      );
    } else {
      _physicsSimulator.setBoundary(
        target?.rect ?? _displayManager.unionBounds,
      );
    }
    _settingsPersistence.scheduleWrite(_petConfig);
  }

  bool _isOnBattery = false;
  bool _isAppActive = true;
  bool _isLowPowerMode = false;

  bool get isThrottled => _isOnBattery || !_isAppActive || _isLowPowerMode;

  void updateEnergyStatus({
    bool? isOnBattery,
    bool? isAppActive,
    bool? isLowPowerMode,
  }) {
    _isOnBattery = isOnBattery ?? _isOnBattery;
    _isAppActive = isAppActive ?? _isAppActive;
    _isLowPowerMode = isLowPowerMode ?? _isLowPowerMode;
  }

  double _tickAccumulator = 0.0;
  double _timeSinceLastFrame = 0.0;

  @override
  void update(double dt) {
    _totalTime += dt;
    if (isThrottled) {
      _timeSinceLastFrame += dt;
      const throttledFrameTime = 1.0 / 15.0; // 15 FPS
      if (_timeSinceLastFrame < throttledFrameTime) {
        return;
      }

      _runSubsystemTick(_timeSinceLastFrame);
      super.update(_timeSinceLastFrame);

      // FSM tick at 1 Hz — behavior decisions don't need frame-rate precision
      _tickAccumulator += _timeSinceLastFrame;
      if (_tickAccumulator >= 1.0) {
        _petService.handleEvent(PetEvent.tick);
        _tickAccumulator = 0.0;
      }

      // Service update: navigation + AI decisions (no notifyListeners inside)
      _petService.update(_timeSinceLastFrame);

      _timeSinceLastFrame = 0.0;
    } else {
      _runSubsystemTick(dt);
      super.update(dt);

      // FSM tick at 1 Hz — behavior decisions don't need frame-rate precision
      _tickAccumulator += dt;
      if (_tickAccumulator >= 1.0) {
        _petService.handleEvent(PetEvent.tick);
        _tickAccumulator = 0.0;
      }

      // Service update: navigation + AI decisions (no notifyListeners inside)
      _petService.update(dt);
    }
  }

  /// Execute the 6-step behavior-engine tick in strict order (req 9.1, 5.1, 6.1, 8.4).
  void _runSubsystemTick(double dt) {
    // 1. Flush pending settings write.
    _settingsPersistence.flushPendingWrite();

    // 2. Poll display changes.
    _displayManager.poll();

    // 3. Sample cursor position and emit zone events.
    final petCenter = _petCenter;
    _cursorTracker.sample(dt, petCenter);

    // 4. Query visible windows and diff for surface/overlap events.
    _windowMonitor.update(_petBounds);

    // 5. Step physics.
    _physicsSimulator.step(dt);

    // 6. Tick throwable objects.
    _throwableManager.tick(dt, petBounds: _petBounds, petAnchor: petCenter);

    // --- Pet Chase & Fetch Targeting ---
    final curState = _petService.currentState;
    if (curState == PetState.chasing) {
      final targetId = _throwableManager.chaseTarget;
      if (targetId != null) {
        try {
          final state = _physicsSimulator.getState(targetId);
          _petService.navigation.setTarget(Offset(state.x, state.y));
          _petService.navigation.updateConfig(wanderSpeed: 160.0);
        } catch (_) {}
      }
    } else if (curState == PetState.fetching) {
      final snapshots = _throwableManager.snapshots();
      if (snapshots.isNotEmpty) {
        final activeToy = snapshots.firstWhere(
          (t) =>
              t.lifecycle == ThrowableLifecycle.stationary ||
              t.lifecycle == ThrowableLifecycle.beingFetched,
          orElse: () => snapshots.first,
        );
        if (activeToy.lifecycle == ThrowableLifecycle.stationary) {
          _petService.navigation.setTarget(activeToy.position);
          _petService.navigation.updateConfig(wanderSpeed: 100.0);
        } else if (activeToy.lifecycle == ThrowableLifecycle.beingFetched) {
          _petService.navigation.setTarget(activeToy.spawnOrigin);
          _petService.navigation.updateConfig(wanderSpeed: 70.0);
        }
      }
    }

    // 7. Persist position change (req 11.4) — update lastAnchorPoint each tick.
    final Offset currentPos = petCenter;
    if (currentPos != _petConfig.lastAnchorPoint) {
      _petConfig = _petConfig.copyWith(lastAnchorPoint: currentPos);
      _settingsPersistence.scheduleWrite(_petConfig);
    }

    // ── Task 8.2: Tick NeedsEngine (Req 10.2–10.9) ─────────────────────────
    _needsEngine.tick(
      dt,
      _petService.currentState,
      _isPettingActive,
      _workSessionElapsed,
    );

    // ── Task 8.3: State-change particle triggers ────────────────────────────
    final currentState = _petService.currentState;

    // Detect celebrating state entry.
    if (currentState == PetState.celebrating &&
        _previousState != PetState.celebrating) {
      _onCelebratingEntered();
    }

    // Detect eating→happy transition for crumbs.
    if (currentState == PetState.happy && _previousState == PetState.eating) {
      _onEatingToHappy();
    }

    // Petting tick: spawn heart particle while petting is active.
    if (_isPettingActive) {
      _onPettingTick();
    }

    // Sleep bubble repeating cycle.
    _tickSleepBubble(dt);

    _previousState = currentState;

    // ── Task 8.5: Tick developer-reaction controller ────────────────────────
    _devReaction.tick(dt);
  }

  /// Pet anchor point in global screen coordinates.
  Offset get _petCenter {
    if (petComponent == null) return Offset.zero;
    return Offset(petComponent!.position.x, petComponent!.position.y);
  }

  /// Pet bounding rect in global screen coordinates.
  Rect get _petBounds {
    if (petComponent == null) return Rect.zero;
    final double hw = petComponent!.size.x / 2;
    final double hh = petComponent!.size.y / 2;
    final Offset center = _petCenter;
    return Rect.fromLTWH(center.dx - hw, center.dy - hh, hw * 2, hh * 2);
  }

  // ── Task 8.5 – triggerCompanionReaction (Req 9.6) ────────────────────────

  static const Set<PetState> _blockedReactionTargets = {
    PetState.breakReminder,
    PetState.meetingPaused,
    PetState.focusMode,
  };

  static final AppLogger _logger = AppLogger();

  /// Triggers a companion reaction by mapping [targetState] to the appropriate
  /// [PetEvent] and forwarding to the FSM via [PetStateMachine.handleEvent].
  ///
  /// Protected states ([PetState.breakReminder], [PetState.meetingPaused],
  /// [PetState.focusMode]) are rejected with a warning log (Req 9.6).
  void triggerCompanionReaction(PetState targetState) {
    if (_blockedReactionTargets.contains(targetState)) {
      _logger.warning(
        'triggerCompanionReaction: rejected protected state ${targetState.name}',
      );
      return;
    }

    final PetEvent? event = _petEventForState(targetState);
    if (event != null) {
      _petService.handleEvent(event);
    }
  }

  PetEvent? _petEventForState(PetState state) {
    switch (state) {
      case PetState.idle:
        return PetEvent.tick;
      case PetState.alert:
        return PetEvent.userClick;
      case PetState.happy:
        return PetEvent.userDoubleClick;
      case PetState.celebrating:
        return PetEvent.breakCompleted;
      case PetState.sleep:
        return PetEvent.idleTimeout;
      case PetState.resting:
        return PetEvent.cursorDwell;
      case PetState.sad:
        return PetEvent.breakEnded;
      default:
        return PetEvent.userClick;
    }
  }

  Size? _lastInitializedSize;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x > 0 && size.y > 0) {
      final newSize = Size(size.x, size.y);
      if (_lastInitializedSize != newSize) {
        _lastInitializedSize = newSize;
        final double spriteSize = _theme.spriteSize.toDouble();
        final double scale = _effectiveScale(spriteSize);
        final double scaledHalfH = (spriteSize * scale) / 2;
        final double groundOffset = _getGroundOffset();

        final double initialY = isPiP
            ? size.y - 44.0 - scaledHalfH - 4.0 + groundOffset
            : size.y - scaledHalfH - 4.0 + groundOffset;

        _petService.initialize(
          screenSize: newSize,
          startPosition: Offset(size.x / 2, initialY),
        );
      }
    }

    if (petComponent != null) {
      final double spriteSize = _theme.spriteSize.toDouble();
      final double scale = _effectiveScale(spriteSize);
      petComponent!.scale = Vector2.all(scale);

      final double scaledHalfW = (spriteSize * scale) / 2;
      double newX;
      if (spriteSize * scale < size.x) {
        newX = petComponent!.position.x.clamp(
          scaledHalfW,
          size.x - scaledHalfW,
        );
      } else {
        newX = size.x / 2;
      }

      final double scaledHalfH = (spriteSize * scale) / 2;
      final double groundOffset = _getGroundOffset();
      final double initialY = isPiP
          ? size.y - 44.0 - scaledHalfH - 4.0 + groundOffset
          : size.y - scaledHalfH - 4.0 + groundOffset;

      petComponent!.position = Vector2(newX, initialY);
      _updateNavigationPaddings();
      _petService.navigation.teleport(Offset(newX, initialY));
    }
  }

  @override
  void render(Canvas canvas) {
    // 1. Let the engine render all existing components (pet, particles, etc.)
    super.render(canvas);

    // 2. Draw active throwables
    final snapshots = _throwableManager.snapshots();
    for (final toy in snapshots) {
      canvas.save();

      Offset position;
      if (toy.lifecycle == ThrowableLifecycle.beingFetched) {
        // Attach to pet's snout/face area.
        if (petComponent != null) {
          final direction = petComponent!.scale.x.sign;
          final snoutOffset = Offset(
            direction *
                (petComponent!.size.x * petComponent!.scale.x.abs() * 0.3),
            -petComponent!.size.y * petComponent!.scale.y.abs() * 0.1,
          );
          position = petComponent!.position.toOffset() + snoutOffset;
        } else {
          position = toy.position;
        }
      } else {
        position = toy.position;
      }

      PhysicsEntityState? state;
      try {
        state = _physicsSimulator.getState(toy.physicsId);
      } catch (_) {}

      // Draw trails if airborne and moving fast
      if (state != null && toy.lifecycle == ThrowableLifecycle.flying) {
        final double vx = state.vx;
        final double vy = state.vy;
        final double speed = sqrt(vx * vx + vy * vy);
        if (speed > 10.0) {
          final double dx = vx / speed;
          final double dy = vy / speed;
          final double baseOffset = (speed * 0.02).clamp(4.0, 15.0);
          for (int step = 3; step >= 1; step--) {
            final double offsetDist = baseOffset * step;
            final double trailX = -dx * offsetDist;
            final double trailY = -dy * offsetDist;
            final double opacity = 0.15 * (4 - step);

            canvas.save();
            canvas.translate(position.dx + trailX, position.dy + trailY);
            canvas.rotate((_totalTime - step * 0.016) * (speed * 0.01));

            if (toy.kind == 'treat') {
              _drawSushiVector(canvas, opacity);
            } else {
              _drawTennisBallVector(canvas, opacity);
            }
            canvas.restore();
          }
        }
      }

      // Handle fetching offset (Req 7.8, 14.2)
      Offset renderPos = position;
      if (toy.lifecycle == ThrowableLifecycle.beingFetched) {
        final comp = petComponent;
        if (comp != null) {
          // Default center-snout offset
          double snoutX = 0;
          double snoutY = comp.size.y * 0.35;

          // Species-specific snout overrides
          final species = _petService.profile.species;
          if (species == PetSpecies.cat) {
            snoutX = comp.isFlipped ? -comp.size.x * 0.25 : comp.size.x * 0.25;
            snoutY = comp.size.y * 0.45;
          } else if (species == PetSpecies.dog) {
            snoutX = comp.isFlipped ? -comp.size.x * 0.35 : comp.size.x * 0.35;
            snoutY = comp.size.y * 0.55;
          } else if (species == PetSpecies.flamingo) {
            // Flamingo head is higher up and further forward
            snoutX = comp.isFlipped ? -comp.size.x * 0.15 : comp.size.x * 0.15;
            snoutY = comp.size.y * 0.25;
          }

          renderPos = comp.position.toOffset() +
              Offset(comp.size.x / 2 + snoutX, snoutY);
        }
      }

      canvas.translate(renderPos.dx, renderPos.dy);

      // Apply spin if airborne
      if (toy.lifecycle == ThrowableLifecycle.flying && state != null) {
        final double vx = state.vx;
        final double vy = state.vy;
        final double speed = sqrt(vx * vx + vy * vy);
        final double spinSpeed = speed * 0.01;
        canvas.rotate(_totalTime * spinSpeed);
      }

      if (toy.kind == 'treat') {
        _drawTreat(
          canvas,
          toy.lifecycle == ThrowableLifecycle.beingFetched,
          1.0,
        );
      } else {
        _drawToy(
          canvas,
          toy.lifecycle == ThrowableLifecycle.beingFetched,
          1.0,
        );
      }

      canvas.restore();
    }
  }

  void _drawToy(Canvas canvas, bool isBeingCarried, [double opacity = 1.0]) {
    if (!isBeingCarried) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2 * opacity)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 9), width: 14, height: 4),
        shadowPaint,
      );
    }

    final destRect = Rect.fromCenter(center: Offset.zero, width: 20, height: 20);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..filterQuality = FilterQuality.medium;

    if (toyType == 'toy_mouse' && mouseImage != null) {
      canvas.drawImageRect(
        mouseImage!,
        const Rect.fromLTWH(0, 0, 32, 32),
        destRect,
        paint,
      );
    } else if (toyType == 'pink_yarn' && pinkBallImage != null) {
      canvas.drawImageRect(
        pinkBallImage!,
        const Rect.fromLTWH(0, 0, 15, 16),
        destRect,
        paint,
      );
    } else if (toyType == 'orange_yarn' && orangeBallImage != null) {
      canvas.drawImageRect(
        orangeBallImage!,
        const Rect.fromLTWH(0, 0, 15, 16),
        destRect,
        paint,
      );
    } else if (toyType == 'tennis_ball' && blueBallImage != null) {
      canvas.drawImageRect(
        blueBallImage!,
        const Rect.fromLTWH(0, 0, 15, 16),
        destRect,
        paint,
      );
    } else {
      _drawTennisBallVector(canvas, opacity);
    }
  }

  void _drawTennisBallVector(Canvas canvas, double opacity) {
    final ballPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(-3, -3),
        10.0,
        [
          const Color(0xFFE6FF55).withValues(alpha: opacity),
          const Color(0xFF9EBF00).withValues(alpha: opacity),
          const Color(0xFF5D7300).withValues(alpha: opacity),
        ],
        [0.0, 0.7, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 10.0, ballPaint);

    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    final path1 = Path();
    path1.addArc(
      Rect.fromCircle(center: const Offset(-10, 0), radius: 10),
      -pi / 3,
      2 * pi / 3,
    );
    canvas.drawPath(path1, seamPaint);

    final path2 = Path();
    path2.addArc(
      Rect.fromCircle(center: const Offset(10, 0), radius: 10),
      2 * pi / 3,
      2 * pi / 3,
    );
    canvas.drawPath(path2, seamPaint);
  }

  void _drawTreat(Canvas canvas, bool isBeingCarried, [double opacity = 1.0]) {
    if (!isBeingCarried) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2 * opacity)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 9), width: 14, height: 4),
        shadowPaint,
      );
    }

    final destRect = Rect.fromCenter(center: Offset.zero, width: 20, height: 20);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..filterQuality = FilterQuality.medium;

    if (treatType == 'carrot' && bunnyFoodsImage != null) {
      canvas.drawImageRect(
        bunnyFoodsImage!,
        const Rect.fromLTWH(0, 0, 16, 16),
        destRect,
        paint,
      );
    } else if (treatType == 'bone' && dogItemsImage != null) {
      canvas.drawImageRect(
        dogItemsImage!,
        const Rect.fromLTWH(0, 0, 32, 32),
        destRect,
        paint,
      );
    } else {
      _drawSushiVector(canvas, opacity);
    }
  }

  void _drawSushiVector(Canvas canvas, double opacity) {
    final noriPaint = Paint()
      ..color = const Color(0xFF1B2421).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 10.0, noriPaint);

    final ricePaint = Paint()
      ..color = const Color(0xFFF5F5F0).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 7.5, ricePaint);

    final salmonPaint = Paint()
      ..color = const Color(0xFFFF5C5C).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-1.5, -0.5), 3.5, salmonPaint);

    final avocadoPaint = Paint()
      ..color = const Color(0xFF7CB342).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(2.0, 1.5), 2.0, avocadoPaint);
  }
}

// =============================================================================
// _DeveloperReactionController — Task 8.5 (Req 11.1–12.5)
// =============================================================================

/// Private helper that lives inside [CompanionGame] and owns all
/// developer-productivity reaction logic.
///
/// All reactions are suppressed when [CompanionGame.isQuietMode] is `true`
/// (Req 12.5).
class _DeveloperReactionController {
  _DeveloperReactionController({required this.game});

  final CompanionGame game;

  static final AppLogger _log = AppLogger();

  // ── State (Req design doc: DeveloperReaction counters) ───────────────────

  /// Number of consecutive work blocks completed without a skipped break.
  /// Resets to zero when a break is skipped (Req 12.1).
  int _consecutiveWorkBlocksCompleted = 0;

  /// Prevents the celebration reaction from firing more than once per block
  /// (Req 11.2).
  bool _celebrationFiredThisBlock = false;

  /// Prevents the one-hour milestone from firing more than once per session
  /// (Req 12.4).
  bool _oneHourMilestoneFired = false;

  /// Prevents the alert reaction from firing more than once per cycle
  /// (Req 11.6).
  bool _alertFiredThisCycle = false;

  // ── System-idle tracking (Req 11.1) ──────────────────────────────────────

  /// Continuous seconds the system has been idle.
  double _systemIdleSeconds = 0.0;

  /// Seconds the pet has been continuously in [PetState.idle].
  double _idleStateSeconds = 0.0;

  // ── Work-block elapsed tracking ───────────────────────────────────────────

  /// Elapsed seconds in the current work block (since last BreakEndedEvent /
  /// session start).  Updated by [onTimerStateChanged].
  int _workBlockElapsedSeconds = 0;

  // ── Countdown tracking (Req 11.6) ────────────────────────────────────────

  int _countdownSeconds = 9999;

  // ── Per-frame tick ────────────────────────────────────────────────────────

  void tick(double dt) {
    // ── Req 11.1: system idle > 5 min while pet in idle → idleTimeout ──────
    if (game._petService.currentState == PetState.idle) {
      _idleStateSeconds += dt;
      _systemIdleSeconds += dt;
      if (_systemIdleSeconds > 5 * 60 && !game.isQuietMode) {
        _log.info('_DeveloperReactionController: system idle timeout (5 min)');
        _emitIdleTimeout();
        _systemIdleSeconds = 0.0; // reset so it doesn't re-fire every frame
      }
    } else {
      _idleStateSeconds = 0.0;
      _systemIdleSeconds = 0.0;
    }

    // ── Req 11.3: late-night idle ≥ 120 s (22:00–05:00) ──────────────────
    if (game._petService.currentState == PetState.idle &&
        _idleStateSeconds >= 120.0 &&
        !game.isQuietMode) {
      final hour = DateTime.now().hour;
      final isLateNight = hour >= 22 || hour < 5;
      if (isLateNight) {
        _log.info(
          '_DeveloperReactionController: late-night idle ≥ 120 s, triggering sleep',
        );
        _emitIdleTimeout();
        _idleStateSeconds = 0.0; // reset so it doesn't re-fire every frame
      }
    }
  }

  void _emitIdleTimeout() {
    game._petService.handleEvent(PetEvent.idleTimeout);
  }

  // ── BreakStartedEvent (Req 11.2) ──────────────────────────────────────────

  void onBreakStarted(BreakStartedEvent event) {
    // Req 11.2: work block ≥ 25 min → celebrate, once per block.
    if (!_celebrationFiredThisBlock &&
        _workBlockElapsedSeconds >= 25 * 60 &&
        !game.isQuietMode) {
      _log.info(
        '_DeveloperReactionController: ≥25 min work block, triggering celebrating',
      );
      game.triggerCompanionReaction(PetState.celebrating);
      _celebrationFiredThisBlock = true;
    }

    // Reset the break-cycle alert flag (Req 11.6).
    _alertFiredThisCycle = false;
  }

  // ── BreakEndedEvent (Req 12.2, 12.3) ─────────────────────────────────────

  void onBreakEnded(BreakEndedEvent event) {
    if (event.skipped) {
      // Req 12.2: skipped break → sad.
      if (!game.isQuietMode) {
        game.triggerCompanionReaction(PetState.sad);
      }
      // Req 12.1: reset consecutive-block counter on skip.
      _consecutiveWorkBlocksCompleted = 0;
    } else {
      // Req 12.3: completed break → happy.
      if (!game.isQuietMode) {
        game.triggerCompanionReaction(PetState.happy);
      }
      // Req 12.1: increment consecutive counter and check milestone.
      _consecutiveWorkBlocksCompleted++;
      if (_consecutiveWorkBlocksCompleted % 3 == 0 && !game.isQuietMode) {
        _log.info(
          '_DeveloperReactionController: $_consecutiveWorkBlocksCompleted consecutive blocks → sparkle',
        );
        game.triggerCompanionReaction(PetState.celebrating);
        final pos = game._petCenter;
        game._spawnParticle(
          MicroParticleFactory.sparkle(pos, quietMode: game.isQuietMode),
        );
      }
    }

    // Reset per-block flags for the next work block.
    _celebrationFiredThisBlock = false;
    _workBlockElapsedSeconds = 0;

    // Req 12.4: reset the one-hour milestone on any break end so it can fire
    // again in the next session.
    _oneHourMilestoneFired = false;
  }

  // ── MeetingDetectedEvent (Req 11.4, 11.5) ────────────────────────────────

  void onMeetingDetected(MeetingDetectedEvent event) {
    // The FSM transition (meetingDetected / meetingEnded) is already handled by
    // CompanionGame._mapAppEventToPetEvent.  Nothing extra needed here.
    _log.info(
      '_DeveloperReactionController: meeting detected isActive=${event.isActive}',
    );
  }

  // ── TimerStateChangedEvent (Req 11.6, 12.4) ──────────────────────────────

  void onTimerStateChanged(TimerStateChangedEvent event) {
    _workBlockElapsedSeconds = event.workElapsedSeconds;
    _countdownSeconds = event.countdownSeconds;

    // Req 11.6: countdown ≤ 60 s, running, break not yet started → alert once.
    if (event.state == TimerStateEvent.running &&
        _countdownSeconds <= 60 &&
        !_alertFiredThisCycle &&
        !game.isQuietMode) {
      _log.info(
        '_DeveloperReactionController: countdown ≤60 s, triggering alert',
      );
      game.triggerCompanionReaction(PetState.alert);
      _alertFiredThisCycle = true;
    }

    // Req 12.4: 3600 s elapsed → resting, once per work session.
    if (event.workElapsedSeconds >= 3600 &&
        !_oneHourMilestoneFired &&
        !game.isQuietMode) {
      _log.info('_DeveloperReactionController: 1-hour milestone → resting');
      game.triggerCompanionReaction(PetState.resting);
      _oneHourMilestoneFired = true;
    }
  }

}
