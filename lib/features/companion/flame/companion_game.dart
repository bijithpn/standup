import 'dart:async';
import 'dart:io';
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
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/features/companion/flame/components/environment_component.dart';
import 'package:breakmate/features/companion/flame/components/throwable_toy_component.dart';

class CompanionGame extends FlameGame {
  CompanionGame({
    required PetTheme initialTheme,
    this.scaleOverride = 0.0,
    this.isPiP = false,
    this.toyType = 'tennis_ball',
    this.treatType = 'sushi',
    this.backgroundImagePath = 'assets/background/sky/background.png',
  }) : _eventBus = EventBus.instance,
       _petService = PetCompanionService(
         stateMachine: PetStateMachine(personality: PetPersonality()),
         brain: PetBehaviorBrain(),
         navigation: PetNavigationService(),
         profile: getProfileFromTheme(initialTheme),
       ),
       _theme = initialTheme,
       _physicsSimulator = PhysicsSimulator(),
       _needsEngine = NeedsEngine(logger: AppLogger()) {
    _throwableManager = ThrowableObjectManager(
      physicsSimulator: _physicsSimulator,
    );
  }

  final bool isPiP;
  String toyType;
  String treatType;
  String backgroundImagePath;

  Future<void> updateBackgroundImagePath(String path) async {
    if (backgroundImagePath == path) return;
    backgroundImagePath = path;
    if (_environmentComponent != null) {
      await _environmentComponent!.updateSkyImage(path);
    }
  }

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

  late final SettingsPersistence _settingsPersistence;
  late final NativeDisplayManager _displayManager;
  late final CursorTracker _cursorTracker;
  late final NativeWindowMonitor _windowMonitor;
  late final PhysicsSimulator _physicsSimulator;
  late final ThrowableObjectManager _throwableManager;
  NativeConstraintWindowController? _constraintWindowController;
  PetConfigV2 _petConfig = PetConfigV2.defaults();

  PetTheme _theme;
  double scaleOverride;
  bool _lastGroomWasLick1 = false;

  Offset? _dragStartPosition;
  bool _isDragging = false;

  int _quietModeTriggers = 0;

  bool get isQuietMode => _quietModeTriggers != 0;

  late final NeedsEngine _needsEngine;
  bool _isPettingActive = false;
  Duration _workSessionElapsed = Duration.zero;

  double _sleepParticleElapsed = 0.0;
  bool _sleepBubbleActive = false;
  double _sleepBubbleCooldown = 0.0;
  static const double _sleepBubbleDuration = 2.0;
  PetState _previousState = PetState.idle;

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
  ThrowableObjectManager get throwableManager => _throwableManager;
  NeedsEngine get needsEngine => _needsEngine;
  PhysicsSimulator get physicsSimulator => _physicsSimulator;

  Color get environmentTint => _environmentComponent?.ambientTint ?? Colors.white;
  EnvironmentComponent? _environmentComponent;
  PositionComponent? _pipWorld;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      _eventBus.emit(
        PlatformErrorEvent(
          message:
              'Unsupported platform. Only macOS and Windows are supported.',
        ),
      );
      return;
    }

    _settingsPersistence = SettingsPersistence();
    _petConfig = _settingsPersistence.loadSync();

    _displayManager = NativeDisplayManager();
    _cursorTracker = CursorTracker();
    _windowMonitor = NativeWindowMonitor();

    _needsEngine.restore();

    _devReaction = _DeveloperReactionController(game: this);

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

    if (isPiP) {
      try {
        _pipWorld = PositionComponent();
        _environmentComponent = EnvironmentComponent(
          backgroundImagePath: backgroundImagePath,
        );
        _pipWorld!.add(_environmentComponent!);
        await add(_pipWorld!);
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
      _physicsSimulator.setBoundary(
        Rect.fromLTWH(0, 24.0, size.x * 1.3, size.y - 24.0 - 52.0),
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

    try {
      mouseImage = await PetAssetLoader.loadImage(
        'assets/ui/icons/mouse_sheet.png',
      );
      pinkBallImage = await PetAssetLoader.loadImage(
        'assets/ui/icons/pinkball_sheet.png',
      );
      orangeBallImage = await PetAssetLoader.loadImage(
        'assets/ui/icons/orangeball_sheet.png',
      );
      bunnyFoodsImage = await PetAssetLoader.loadImage(
        'assets/characters/pets/bunnyfoods_2.png',
      );
      dogItemsImage = await PetAssetLoader.loadImage(
        'assets/characters/pets/dogitems_2.png',
      );
    } catch (e) {
      debugPrint('Error loading companion toy/treat assets: $e');
    }

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

    if (event is TimerStateChangedEvent) {
      _petService.syncContextFlags(
        isBreakActive: event.state == TimerStateEvent.breakActive,
        isIdle: event.state == TimerStateEvent.idle,
        totalWorkTodaySeconds: event.totalWorkTodaySeconds,
      );
      _workSessionElapsed = Duration(seconds: event.workElapsedSeconds);
      _devReaction.onTimerStateChanged(event);
      return;
    } else if (event is BreakStartedEvent) {
      _petService.syncContextFlags(isBreakActive: true);
      petEvent = PetEvent.breakStarted;
      _devReaction.onBreakStarted(event);
    } else if (event is BreakEndedEvent) {
      _petService.syncContextFlags(isBreakActive: false);
      petEvent = PetEvent.breakEnded;
      _devReaction.onBreakEnded(event);
    } else if (event is MeetingDetectedEvent) {
      _petService.syncContextFlags(isMeetingDetected: event.isActive);
      petEvent = event.isActive
          ? PetEvent.meetingDetected
          : PetEvent.meetingEnded;
      _updateQuietModeBit(0x02, event.isActive);
      _devReaction.onMeetingDetected(event);
    } else if (event is FocusModeEvent) {
      _petService.syncContextFlags(isFocusMode: event.isActive);
      petEvent = event.isActive ? PetEvent.focusModeOn : PetEvent.focusModeOff;
      _updateQuietModeBit(0x01, event.isActive);
    } else if (event is LowPowerModeChangedEvent) {
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
      final snapshots = _throwableManager.snapshots();
      final toyState = snapshots.firstWhere(
        (t) => t.id == event.objectId,
        orElse: () => snapshots.first,
      );
      final toyComponent = ThrowableToyComponent(
        physicsId: event.objectId,
        kind: toyState.kind,
        type: toyState.kind == 'treat' ? treatType : toyType,
        spawnOrigin: toyState.spawnOrigin,
      )..priority = 10;
      if (isPiP && _pipWorld != null) {
        _pipWorld!.add(toyComponent);
      } else {
        add(toyComponent);
      }
    } else if (event is ThrowableStationaryEvent) {
      _petService.handleEvent(PetEvent.throwableStationary);
      _spawnBounceParticle();
    } else if (event is ThrowableFetchedEvent) {
      _petService.handleEvent(PetEvent.throwableFetched);
    } else if (event is ThrowableReturnedEvent) {
      _petService.handleEvent(PetEvent.throwableReturned);
      _needsEngine.onBallFetched();
      _petService.stateMachine.transitionTo(PetState.celebrating);
    } else if (event is ThrowableEatenEvent) {
      _petService.handleEvent(PetEvent.throwableEaten);
      _needsEngine.onTreatEaten();
      _onEatingStarted();
    } else if (event is ThrowableDisposedEvent) {
      ThrowableToyComponent? target;
      if (isPiP && _pipWorld != null) {
        target = _pipWorld!.children
            .whereType<ThrowableToyComponent>()
            .cast<ThrowableToyComponent?>()
            .firstWhere((c) => c?.physicsId == event.objectId, orElse: () => null);
      } else {
        target = children
            .whereType<ThrowableToyComponent>()
            .cast<ThrowableToyComponent?>()
            .firstWhere((c) => c?.physicsId == event.objectId, orElse: () => null);
      }
      final isTreat = target?.kind == 'treat';
      if (!isTreat) {
        _petService.handleEvent(PetEvent.throwableReturned);
      }
      target?.removeFromParent();
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
      debugPrint('[PlatformError] ${event.message}');
      exit(1);
    } else if (event is ConstraintWindowBoundsChangedEvent) {
      _constraintWindowController?.onBoundsChanged(event.bounds);
    } else if (event is DisplayDisconnectedEvent) {
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
    for (final particle
        in children.whereType<ParticleSystemComponent>().toList()) {
      particle.removeFromParent();
    }
    _sleepBubbleActive = false;
  }

  void _onQuietModeDeactivated() {}

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

  void _onEatingStarted() {
    final pos = _petCenter;
    _spawnParticle(MicroParticleFactory.crumbs(pos, quietMode: isQuietMode));
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
      _sleepBubbleCooldown -= dt;
      if (_sleepBubbleCooldown <= 0.0) {
        _sleepBubbleActive = false;
      }
      return;
    }

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
        if (_theme.animations.containsKey(PetAnimationState.lick1)) {
          _lastGroomWasLick1 = !_lastGroomWasLick1;
          return _lastGroomWasLick1
              ? PetAnimationState.lick1
              : PetAnimationState.lick2;
        }
        return PetAnimationState.idle;
      case PetState.eating:
        if (_theme.animations.containsKey(PetAnimationState.lick1)) {
          return PetAnimationState.lick1;
        } else if (_theme.animations.containsKey(PetAnimationState.excited)) {
          return PetAnimationState.excited;
        }
        return PetAnimationState.idle;
      case PetState.drag:
        return PetAnimationState.idle;
      case PetState.breatheFire:
        return PetAnimationState.breatheFire;
      case PetState.fly:
        return PetAnimationState.fly;
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

    scale = scale * (32.0 / spriteSize);

    if (isPiP) {
      scale *= 1.0;
    }

    return scale;
  }

  double _getGroundOffset() {
    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);
    if (_theme.spriteSize == 32) {
      return scale * 5.0;
    } else if (_theme.spriteSize == 50) {
      return scale * 18.0;
    } else if (_theme.spriteSize == 64) {
      return scale * 16.0;
    } else if (_theme.spriteSize == 128) {
      return scale * 20.0;
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

    final double worldWidth = isPiP ? size.x * 1.3 : size.x;

    double minX = scaledHalfW + 4.0;
    double maxX = worldWidth - scaledHalfW - 4.0;
    if (minX > maxX) {
      minX = worldWidth / 2;
      maxX = worldWidth / 2;
    }

    final double groundY = isPiP
        ? (size.y - 52.0 - scaledHalfH + groundOffset)
        : (size.y - scaledHalfH - 4.0 + groundOffset);

    _petService.navigation.updatePaddings(
      left: minX,
      right: worldWidth - maxX,
      top: groundY,
      bottom: size.y - groundY,
    );
  }

  Future<void> _loadAndAttachPet() async {
    final animations = await PetAssetLoader.loadAnimations(_petService.profile);
    if (animations.isEmpty) return;

    children.whereType<CompanionComponent>().toList().forEach(
      (c) => c.removeFromParent(),
    );
    _pipWorld?.children.whereType<CompanionComponent>().toList().forEach(
      (c) => c.removeFromParent(),
    );

    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);

    petComponent = CompanionComponent(
      animations: animations,
      initialState: _mapPetStateToAnimationState(_petService.currentState),
    )..priority = 5;

    petComponent!.size = Vector2(spriteSize, spriteSize);
    petComponent!.scale = Vector2.all(scale);

    final double scaledHalfW = (spriteSize * scale) / 2;
    final double scaledHalfH = (spriteSize * scale) / 2;
    final double groundOffset = _getGroundOffset();
    final double initialY = isPiP
        ? size.y - 52.0 - scaledHalfH + groundOffset
        : size.y - scaledHalfH - 4.0 + groundOffset;

    final double worldWidth = isPiP ? size.x * 1.3 : size.x;
    petComponent!.position = Vector2(worldWidth / 2, initialY);

    if (isPiP && _pipWorld != null) {
      _pipWorld!.add(petComponent!);
    } else {
      add(petComponent!);
    }

    _updateNavigationPaddings();

    final currentPos = _petService.navigation.currentPosition;
    final minY = isPiP
        ? (size.y - 52.0 - scaledHalfH + groundOffset)
        : (scaledHalfH + 4.0 - groundOffset);
    final maxY = isPiP
        ? (size.y - 52.0 - scaledHalfH + groundOffset)
        : (size.y - scaledHalfH - 4.0 + groundOffset);
    if (currentPos.dy < minY ||
        currentPos.dy > maxY ||
        currentPos.dx < scaledHalfW + 4.0 ||
        currentPos.dx > worldWidth - scaledHalfW - 4.0) {
      _petService.navigation.teleport(Offset(worldWidth / 2, initialY));
    }

    final syncedPos = _petService.navigation.currentPosition;
    petComponent!.position = Vector2(syncedPos.dx, syncedPos.dy);
  }

  Offset screenToWorld(Offset screenOffset) {
    if (!isPiP || _pipWorld == null) return screenOffset;
    return screenOffset - _pipWorld!.position.toOffset();
  }

  Future<void> updateTheme(PetTheme newTheme) async {
    if (_theme.id == newTheme.id && petComponent != null) return;

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
        ? size.y - 52.0 - scaledHalfH + groundOffset
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

  void onDragStart(Offset startPosition) {
    _dragStartPosition = startPosition;
    _isDragging = true;
  }

  void onDragEnd(Offset releasePosition) {
    if (_isDragging && _dragStartPosition != null) {
      final Offset dragVector = releasePosition - _dragStartPosition!;
      final double worldWidth = size.x * 1.3;
      final double groundHeight = size.y - 52.0 - (_theme.spriteSize.toDouble() * _effectiveScale(_theme.spriteSize.toDouble())) / 2 + _getGroundOffset();
      final returnTarget = isPiP ? Offset(worldWidth / 2, groundHeight) : null;
      final double toySize = isPiP ? 10.0 : 20.0;
      _throwableManager.spawnThrowable(
        releasePosition,
        dragVector,
        returnTarget: returnTarget,
        customSize: toySize,
      );
    }
    _dragStartPosition = null;
    _isDragging = false;
  }

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
            Rect.fromLTWH(0, 24.0, size.x * 1.3, size.y - 24.0 - 52.0),
          );
        } else {
          _physicsSimulator.setBoundary(_displayManager.unionBounds);
        }

      case PetMode.freeRoam:
        await _constraintWindowController?.hide();
        _physicsSimulator.setConstraintBoundary(null);
        if (isPiP) {
          _physicsSimulator.setBoundary(
            Rect.fromLTWH(0, 24.0, size.x * 1.3, size.y - 24.0 - 52.0),
          );
        } else {
          _physicsSimulator.setBoundary(_displayManager.unionBounds);
        }
    }

    _settingsPersistence.scheduleWrite(_petConfig);
  }

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
        Rect.fromLTWH(0, 24.0, size.x * 1.3, size.y - 24.0 - 52.0),
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
    if (isThrottled) {
      _timeSinceLastFrame += dt;
      const throttledFrameTime = 1.0 / 15.0;
      if (_timeSinceLastFrame < throttledFrameTime) {
        return;
      }

      _runSubsystemTick(_timeSinceLastFrame);
      super.update(_timeSinceLastFrame);

      _tickAccumulator += _timeSinceLastFrame;
      if (_tickAccumulator >= 1.0) {
        _petService.handleEvent(PetEvent.tick);
        _tickAccumulator = 0.0;
      }

      _petService.update(_timeSinceLastFrame);

      _timeSinceLastFrame = 0.0;
    } else {
      _runSubsystemTick(dt);
      super.update(dt);

      _tickAccumulator += dt;
      if (_tickAccumulator >= 1.0) {
        _petService.handleEvent(PetEvent.tick);
        _tickAccumulator = 0.0;
      }

      _petService.update(dt);
    }
  }

  void _runSubsystemTick(double dt) {
    _settingsPersistence.flushPendingWrite();

    _displayManager.poll();

    final petCenter = _petCenter;
    _cursorTracker.sample(dt, petCenter);

    _windowMonitor.update(_petBounds);

    _physicsSimulator.step(dt);

    _throwableManager.tick(dt, petBounds: _petBounds, petAnchor: petCenter);

    final curState = _petService.currentState;
    if (curState == PetState.chasing) {
      final targetId = _throwableManager.chaseTarget;
      if (targetId != null) {
        try {
          final state = _physicsSimulator.getState(targetId);
          final double spriteSize = _theme.spriteSize.toDouble();
          final double scale = _effectiveScale(spriteSize);
          final double scaledHalfH = (spriteSize * scale) / 2;
          final double groundOffset = _getGroundOffset();
          final double targetY = isPiP
              ? size.y - 52.0 - scaledHalfH + groundOffset
              : size.y - scaledHalfH - 4.0 + groundOffset;
          _petService.navigation.setTarget(Offset(state.x, targetY));
          _petService.navigation.updateConfig(wanderSpeed: 160.0);
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
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
        final double spriteSize = _theme.spriteSize.toDouble();
        final double scale = _effectiveScale(spriteSize);
        final double scaledHalfH = (spriteSize * scale) / 2;
        final double groundOffset = _getGroundOffset();
        final double groundY = isPiP
            ? size.y - 52.0 - scaledHalfH + groundOffset
            : size.y - scaledHalfH - 4.0 + groundOffset;

        if (activeToy.lifecycle == ThrowableLifecycle.stationary) {
          _petService.navigation.setTarget(Offset(activeToy.position.dx, groundY));
          _petService.navigation.updateConfig(wanderSpeed: 100.0);
        } else if (activeToy.lifecycle == ThrowableLifecycle.beingFetched) {
          _petService.navigation.setTarget(Offset(activeToy.spawnOrigin.dx, groundY));
          _petService.navigation.updateConfig(wanderSpeed: 70.0);
        }
      }
    }

    final Offset currentPos = petCenter;
    if (currentPos != _petConfig.lastAnchorPoint) {
      _petConfig = _petConfig.copyWith(lastAnchorPoint: currentPos);
      _settingsPersistence.scheduleWrite(_petConfig);
    }

    _needsEngine.tick(
      dt,
      _petService.currentState,
      _isPettingActive,
      _workSessionElapsed,
    );

    final currentState = _petService.currentState;

    if (currentState == PetState.celebrating &&
        _previousState != PetState.celebrating) {
      _onCelebratingEntered();
    }

    if (currentState == PetState.happy && _previousState == PetState.eating) {
      _onEatingToHappy();
      _spawnParticle(MicroParticleFactory.heart(_petCenter, quietMode: isQuietMode));
    }

    if (_isPettingActive) {
      _onPettingTick();
    }

    _tickSleepBubble(dt);

    _previousState = currentState;

    _devReaction.tick(dt);

    if (isPiP && petComponent != null && _pipWorld != null) {
      final petX = petComponent!.position.x;
      final viewHalfW = size.x / 2;
      final double worldWidth = size.x * 1.3;
      final double camX = petX.clamp(viewHalfW, worldWidth - viewHalfW);
      _pipWorld!.position = Vector2(-(camX - viewHalfW), 0.0);
    }
  }

  Offset get _petCenter {
    if (petComponent == null) return Offset.zero;
    return Offset(petComponent!.position.x, petComponent!.position.y);
  }

  Rect get _petBounds {
    if (petComponent == null) return Rect.zero;
    final double hw = (petComponent!.size.x * petComponent!.scale.x.abs()) / 2;
    final double hh = (petComponent!.size.y * petComponent!.scale.y.abs()) / 2;
    final Offset center = _petCenter;
    return Rect.fromLTWH(center.dx - hw, center.dy - hh, hw * 2, hh * 2);
  }

  static const Set<PetState> _blockedReactionTargets = {
    PetState.breakReminder,
    PetState.meetingPaused,
    PetState.focusMode,
  };

  static final AppLogger _logger = AppLogger();

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
      final double worldWidth = isPiP ? size.x * 1.3 : size.x;
      final newSize = Size(worldWidth, size.y);
      if (_lastInitializedSize != newSize) {
        _lastInitializedSize = newSize;
        final double spriteSize = _theme.spriteSize.toDouble();
        final double scale = _effectiveScale(spriteSize);
        final double scaledHalfH = (spriteSize * scale) / 2;
        final double groundOffset = _getGroundOffset();

        final double initialY = isPiP
            ? size.y - 52.0 - scaledHalfH + groundOffset
            : size.y - scaledHalfH - 4.0 + groundOffset;

        _petService.initialize(
          screenSize: newSize,
          startPosition: Offset(worldWidth / 2, initialY),
        );
      }
    }

    if (petComponent != null) {
      final double spriteSize = _theme.spriteSize.toDouble();
      final double scale = _effectiveScale(spriteSize);
      petComponent!.scale = Vector2.all(scale);

      final double scaledHalfW = (spriteSize * scale) / 2;
      final double worldWidth = isPiP ? size.x * 1.3 : size.x;
      double newX;
      if (spriteSize * scale < worldWidth) {
        newX = petComponent!.position.x.clamp(
          scaledHalfW,
          worldWidth - scaledHalfW,
        );
      } else {
        newX = worldWidth / 2;
      }

      final double scaledHalfH = (spriteSize * scale) / 2;
      final double groundOffset = _getGroundOffset();
      final double initialY = isPiP
          ? size.y - 52.0 - scaledHalfH + groundOffset
          : size.y - scaledHalfH - 4.0 + groundOffset;

      petComponent!.position = Vector2(newX, initialY);
      _updateNavigationPaddings();
      _petService.navigation.teleport(Offset(newX, initialY));
    }
  }
}

class _DeveloperReactionController {
  _DeveloperReactionController({required this.game});

  final CompanionGame game;

  static final AppLogger _log = AppLogger();

  int _consecutiveWorkBlocksCompleted = 0;

  bool _celebrationFiredThisBlock = false;

  bool _oneHourMilestoneFired = false;

  bool _alertFiredThisCycle = false;

  double _systemIdleSeconds = 0.0;

  double _idleStateSeconds = 0.0;

  int _workBlockElapsedSeconds = 0;

  int _countdownSeconds = 9999;

  void tick(double dt) {
    if (game._petService.currentState == PetState.idle) {
      _idleStateSeconds += dt;
      _systemIdleSeconds += dt;
      if (_systemIdleSeconds > 5 * 60 && !game.isQuietMode) {
        _log.info('_DeveloperReactionController: system idle timeout (5 min)');
        _emitIdleTimeout();
        _systemIdleSeconds = 0.0;
      }
    } else {
      _idleStateSeconds = 0.0;
      _systemIdleSeconds = 0.0;
    }

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
        _idleStateSeconds = 0.0;
      }
    }
  }

  void _emitIdleTimeout() {
    game._petService.handleEvent(PetEvent.idleTimeout);
  }

  void onBreakStarted(BreakStartedEvent event) {
    if (!_celebrationFiredThisBlock &&
        _workBlockElapsedSeconds >= 25 * 60 &&
        !game.isQuietMode) {
      _log.info(
        '_DeveloperReactionController: ≥25 min work block, triggering celebrating',
      );
      game.triggerCompanionReaction(PetState.celebrating);
      _celebrationFiredThisBlock = true;
    }
    _alertFiredThisCycle = false;
  }

  void onBreakEnded(BreakEndedEvent event) {
    if (event.skipped) {
      if (!game.isQuietMode) {
        game.triggerCompanionReaction(PetState.sad);
      }
      _consecutiveWorkBlocksCompleted = 0;
    } else {
      if (!game.isQuietMode) {
        game.triggerCompanionReaction(PetState.happy);
      }
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

    _celebrationFiredThisBlock = false;
    _workBlockElapsedSeconds = 0;
    _oneHourMilestoneFired = false;
  }

  void onMeetingDetected(MeetingDetectedEvent event) {
    _log.info(
      '_DeveloperReactionController: meeting detected isActive=${event.isActive}',
    );
  }

  void onTimerStateChanged(TimerStateChangedEvent event) {
    _workBlockElapsedSeconds = event.workElapsedSeconds;
    _countdownSeconds = event.countdownSeconds;

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

    if (event.workElapsedSeconds >= 3600 &&
        !_oneHourMilestoneFired &&
        !game.isQuietMode) {
      _log.info('_DeveloperReactionController: 1-hour milestone → resting');
      game.triggerCompanionReaction(PetState.resting);
      _oneHourMilestoneFired = true;
    }
  }
}
