import 'dart:async';
import 'dart:io';
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_personality.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/flame/companion_component.dart';
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
  CompanionGame({required PetTheme initialTheme, this.scaleOverride = 0.0})
    : _eventBus = EventBus.instance,
      _petService = PetCompanionService(
        stateMachine: PetStateMachine(personality: PetPersonality()),
        brain: PetBehaviorBrain(),
        navigation: PetNavigationService(),
        profile: getProfileFromTheme(initialTheme),
      ),
      _theme = initialTheme;

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
      _eventBus.emit(PlatformErrorEvent(
          message: 'Unsupported platform. Only macOS and Windows are supported.'));
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
    _throwableManager = ThrowableObjectManager(physicsSimulator: _physicsSimulator);

    // 4. Enumerate displays with 500ms timeout (req 1.5, 1.6, 1.7).
    List<DisplayBounds> displays;
    try {
      displays = await _displayManager
          .enumerateDisplays()
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      _eventBus.emit(PlatformErrorEvent(
          message: 'Display enumeration timed out or failed. Terminating.'));
      exit(1);
    }

    if (displays.isEmpty) {
      _eventBus.emit(PlatformErrorEvent(
          message: 'No displays found after enumeration. Terminating.'));
      exit(1);
    }

    // 5. Apply loaded config to physics boundary.
    _physicsSimulator.setBoundary(_displayManager.unionBounds);
    if (_petConfig.mode == PetMode.singleDisplay &&
        _petConfig.pinnedDisplayId != null) {
      final pinned = displays.cast<DisplayBounds?>().firstWhere(
            (d) => d?.id == _petConfig.pinnedDisplayId,
            orElse: () => null,
          );
      if (pinned != null) _physicsSimulator.setBoundary(pinned.rect);
    }

    // 6. Set up constraint window controller if in constrained mode.
    if (_petConfig.mode == PetMode.constrained) {
      _constraintWindowController = NativeConstraintWindowController(
        physicsSimulator: _physicsSimulator,
        displays: displays,
      );
      await _constraintWindowController!
          .show(initialSize: _petConfig.constraintWindowBounds.size);
      _physicsSimulator
          .setConstraintBoundary(_constraintWindowController!.bounds);
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
      return;
    } else if (event is BreakStartedEvent) {
      _petService.syncContextFlags(isBreakActive: true);
      petEvent = PetEvent.breakStarted;
    } else if (event is BreakEndedEvent) {
      _petService.syncContextFlags(isBreakActive: false);
      petEvent = PetEvent.breakEnded;
    } else if (event is MeetingDetectedEvent) {
      _petService.syncContextFlags(isMeetingDetected: event.isActive);
      petEvent = event.isActive
          ? PetEvent.meetingDetected
          : PetEvent.meetingEnded;
    } else if (event is FocusModeEvent) {
      _petService.syncContextFlags(isFocusMode: event.isActive);
      petEvent = event.isActive ? PetEvent.focusModeOn : PetEvent.focusModeOff;
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
    } else if (event is ThrowableDisposedEvent) {
      // throwable returned/disposed → return pet to idle
      _petService.handleEvent(PetEvent.throwableFetched);
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
        _physicsSimulator.setBoundary(_displayManager.unionBounds);
        _settingsPersistence.scheduleWrite(_petConfig);
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
    if (scaleOverride > 0.0) return scaleOverride;
    final double baselineHeight = size.y > 400.0 ? 300.0 : size.y;
    final double target = baselineHeight * 0.45;
    return (target / spriteSize).clamp(3.0, 10.0);
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

    final double scaledHalfH = (spriteSize * scale) / 2;
    petComponent!.position = Vector2(size.x / 2, size.y - scaledHalfH - 4.0);

    add(petComponent!);
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

  void _applyScale() {
    if (petComponent == null) return;
    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);
    petComponent!.scale = Vector2.all(scale);

    final double scaledHalfH = (spriteSize * scale) / 2;
    petComponent!.position = Vector2(
      petComponent!.position.x,
      size.y - scaledHalfH - 4.0,
    );
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
        await _constraintWindowController!
            .show(initialSize: _petConfig.constraintWindowBounds.size);
        _physicsSimulator
            .setConstraintBoundary(_constraintWindowController!.bounds);

      case PetMode.singleDisplay:
        await _constraintWindowController?.hide();
        _physicsSimulator.setConstraintBoundary(null);
        _physicsSimulator.setBoundary(_displayManager.unionBounds);

      case PetMode.freeRoam:
        await _constraintWindowController?.hide();
        _physicsSimulator.setConstraintBoundary(null);
        _physicsSimulator.setBoundary(_displayManager.unionBounds);
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
    _physicsSimulator.setBoundary(target?.rect ?? _displayManager.unionBounds);
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
    _throwableManager.tick(dt,
        petBounds: _petBounds, petAnchor: petCenter);

    // 7. Persist position change (req 11.4) — update lastAnchorPoint each tick.
    final Offset currentPos = petCenter;
    if (currentPos != _petConfig.lastAnchorPoint) {
      _petConfig = _petConfig.copyWith(lastAnchorPoint: currentPos);
      _settingsPersistence.scheduleWrite(_petConfig);
    }
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

        _petService.initialize(
          screenSize: newSize,
          startPosition: Offset(size.x / 2, size.y - scaledHalfH - 4.0),
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
      petComponent!.position = Vector2(newX, size.y - scaledHalfH - 4.0);
    }
  }
}
