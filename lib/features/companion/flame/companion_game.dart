import 'dart:async';
import 'package:flame/game.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_personality.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/flame/companion_component.dart';
import 'package:breakmate/features/companion/ai/pet_behavior_brain.dart';
import 'package:breakmate/features/companion/services/pet_companion_service.dart';
import 'package:breakmate/features/companion/services/pet_navigation_service.dart';

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

  PetTheme _theme;
  double scaleOverride; // 0.0 = auto-scale
  bool _lastGroomWasLick1 = false; // alternates lick1 → lick2 → lick1 …

  CompanionComponent? petComponent;

  PetTheme get currentTheme => _theme;
  PetState get companionState => _petService.currentState;
  PetCompanionService get petService => _petService;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _eventSubscription = _eventBus.stream.listen(_handleAppEvent);
    _petStateSubscription = _petService.stateMachine.stateStream.listen((
      state,
    ) {
      _applyPetStateToComponent(state);
    });
    _petService.initialize(screenSize: Size(size.x, size.y));
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

  void onUserInteraction(String type) {
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
        break;
      case 'dragEnd':
        _petService.handleEvent(PetEvent.userDragEnd);
        break;
    }
  }

  double _tickAccumulator = 0.0;

  @override
  void update(double dt) {
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
