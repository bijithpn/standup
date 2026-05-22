import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/features/companion/assets/pet_asset_loader.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/domain/pet_personality.dart';
import 'package:standup/features/companion/domain/pet_profile.dart';
import 'package:standup/features/companion/domain/pet_state_machine.dart';
import 'package:standup/features/companion/domain/pet_type.dart';
import 'package:standup/features/companion/flame/companion_component.dart';
import 'package:standup/features/companion/ai/pet_behavior_brain.dart';
import 'package:standup/features/companion/services/pet_companion_service.dart';
import 'package:standup/features/companion/services/pet_navigation_service.dart';

class CompanionGame extends FlameGame {
  CompanionGame({required CatTheme initialTheme, this.scaleOverride = 0.0})
    : _eventBus = EventBus.instance,
      _petService = PetCompanionService(
        stateMachine: PetStateMachine(personality: PetPersonality()),
        brain: PetBehaviorBrain(),
        navigation: PetNavigationService(),
        profile: getProfileFromTheme(initialTheme),
      ),
      _theme = initialTheme;

  static PetProfile getProfileFromTheme(CatTheme theme) {
    final species = theme.isDog ? PetSpecies.dog : PetSpecies.cat;
    final variant = PetVariant(
      id: theme.id,
      name: theme.name,
      assetPath: theme.basePath,
      isSpriteSheet: theme.type == CatType.composite,
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

  CatTheme _theme;
  double scaleOverride; // 0.0 = auto-scale
  bool _lastGroomWasLick1 = false; // alternates lick1 → lick2 → lick1 …

  CompanionComponent? catComponent;

  CatTheme get currentTheme => _theme;
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
    await _loadAndAttachCat();
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
    // changeState() also does this check, but being explicit here avoids
    // a silent no-op when the component has no animation for the state.
    final safeState = (catComponent?.animations?.containsKey(animState) == true)
        ? animState
        : CatAnimationState.idle;
    catComponent?.changeState(safeState);
  }

  CatAnimationState _mapPetStateToAnimationState(PetState state) {
    switch (state) {
      case PetState.idle:
      case PetState.blink:
      case PetState.resting:
      case PetState.bored:
      case PetState.quiet:
        return CatAnimationState.idle;
      case PetState.stretch:
        return CatAnimationState.stretch;
      case PetState.celebrating:
      case PetState.dancing:
        return CatAnimationState.celebrate;
      case PetState.walk:
      case PetState.exploring:
      case PetState.following:
      case PetState.turning:
        return CatAnimationState.walk;
      case PetState.run:
      case PetState.jumping:
      case PetState.playing:
        return CatAnimationState.run;
      case PetState.sleep:
        return CatAnimationState.sleep;
      case PetState.alert:
      case PetState.curious:
      case PetState.interacting:
      case PetState.scared:
      case PetState.hiding:
        return CatAnimationState.notification;
      case PetState.happy:
      case PetState.excited:
      case PetState.affectionate:
        return CatAnimationState.excited;
      case PetState.breakReminder:
        return CatAnimationState.breakMode;
      case PetState.meetingPaused:
      case PetState.sad:
        return CatAnimationState.sad;
      case PetState.focusMode:
        return CatAnimationState.focusMode;
      case PetState.grooming:
        // Alternate lick1 → lick2 → lick1 … for a natural grooming sequence.
        // Falls back to idle if the theme has no lick animations.
        if (_theme.animations.containsKey(CatAnimationState.lick1)) {
          _lastGroomWasLick1 = !_lastGroomWasLick1;
          return _lastGroomWasLick1 ? CatAnimationState.lick1 : CatAnimationState.lick2;
        }
        return CatAnimationState.idle;
      case PetState.eating:
        return CatAnimationState.idle;
      case PetState.drag:
        return CatAnimationState.idle;
    }
  }

  double _effectiveScale(double spriteSize) {
    if (scaleOverride > 0.0) return scaleOverride;
    final double baselineHeight = size.y > 400.0 ? 300.0 : size.y;
    final double target = baselineHeight * 0.45;
    return (target / spriteSize).clamp(3.0, 10.0);
  }

  Future<void> _loadAndAttachCat() async {
    final animations = await PetAssetLoader.loadAnimations(_petService.profile);
    if (animations.isEmpty) return;

    children.whereType<CompanionComponent>().toList().forEach(
      (c) => c.removeFromParent(),
    );

    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);

    catComponent = CompanionComponent(
      animations: animations,
      initialState: _mapPetStateToAnimationState(_petService.currentState),
    );

    catComponent!.size = Vector2(spriteSize, spriteSize);
    catComponent!.scale = Vector2.all(scale);

    final double scaledHalfH = (spriteSize * scale) / 2;
    catComponent!.position = Vector2(size.x / 2, size.y - scaledHalfH - 4.0);

    add(catComponent!);
  }

  Future<void> updateTheme(CatTheme newTheme) async {
    if (_theme.id == newTheme.id && catComponent != null) return;
    _theme = newTheme;
    _petService.updateProfile(getProfileFromTheme(newTheme));
    await _loadAndAttachCat();
  }

  void updateScale(double newScale) {
    if (scaleOverride == newScale) return;
    scaleOverride = newScale;
    _applyScale();
  }

  void _applyScale() {
    if (catComponent == null) return;
    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);
    catComponent!.scale = Vector2.all(scale);

    final double scaledHalfH = (spriteSize * scale) / 2;
    catComponent!.position = Vector2(
      catComponent!.position.x,
      size.y - scaledHalfH - 4.0,
    );
  }

  void triggerState(CatAnimationState state) {
    catComponent?.changeState(state);
  }

  void setWanderingEnabled(bool enabled) {
    catComponent?.setWanderingEnabled(enabled);
  }

  void updateMouseFollow(Map<dynamic, dynamic> data) {
    catComponent?.updateMouseFollow(data);
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

    if (catComponent != null) {
      final double spriteSize = _theme.spriteSize.toDouble();
      final double scale = _effectiveScale(spriteSize);
      catComponent!.scale = Vector2.all(scale);

      final double scaledHalfW = (spriteSize * scale) / 2;
      double newX;
      if (spriteSize * scale < size.x) {
        newX = catComponent!.position.x.clamp(
          scaledHalfW,
          size.x - scaledHalfW,
        );
      } else {
        newX = size.x / 2;
      }

      final double scaledHalfH = (spriteSize * scale) / 2;
      catComponent!.position = Vector2(newX, size.y - scaledHalfH - 4.0);
    }
  }
}
