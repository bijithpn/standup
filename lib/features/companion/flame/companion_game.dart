import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/features/companion/assets/pet_asset_loader.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/cat_state_machine.dart';
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
      _stateMachine = CatStateMachine(),
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
  final CatStateMachine _stateMachine;
  final PetCompanionService _petService;
  late StreamSubscription<AppEvent> _eventSubscription;
  late StreamSubscription<PetState> _petStateSubscription;

  CatTheme _theme;
  double scaleOverride; // 0.0 = auto-scale

  CompanionComponent? catComponent;

  CatTheme get currentTheme => _theme;
  CatState get companionState => _stateMachine.currentState;
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
    _petService.dispose();
    super.onRemove();
  }

  CatEvent? _mapAppEventToCatEvent(AppEvent event) {
    if (event is TimerStateChangedEvent) {
      return CatEvent.tick;
    } else if (event is BreakStartedEvent) {
      return CatEvent.breakStarted;
    } else if (event is BreakEndedEvent) {
      return CatEvent.breakEnded;
    } else if (event is MeetingDetectedEvent) {
      return event.isActive ? CatEvent.meetingDetected : CatEvent.meetingEnded;
    } else if (event is FocusModeEvent) {
      return event.isActive ? CatEvent.focusModeOn : CatEvent.focusModeOff;
    } else if (event is IdleDetectedEvent) {
      return event.isIdle ? CatEvent.idleTimeout : CatEvent.activityDetected;
    } else if (event is CompanionInteractionEvent) {
      switch (event.interactionType) {
        case 'tap':
          return CatEvent.userClick;
        case 'doubleTap':
          return CatEvent.userDoubleClick;
        case 'hover':
          return CatEvent.userHover;
        case 'dragStart':
          return CatEvent.userDragStart;
        case 'dragEnd':
          return CatEvent.userDragEnd;
      }
    }
    return null;
  }

  void _handleAppEvent(AppEvent event) {
    final CatEvent? catEvent = _mapAppEventToCatEvent(event);
    if (catEvent != null) {
      _stateMachine.handleEvent(catEvent);
      _applyStateToComponent();
    }
    _mapAppEventToPetEvent(event);
  }

  void _mapAppEventToPetEvent(AppEvent event) {
    PetEvent? petEvent;
    if (event is TimerStateChangedEvent) {
      petEvent = PetEvent.tick;
    } else if (event is BreakStartedEvent) {
      petEvent = PetEvent.breakStarted;
    } else if (event is BreakEndedEvent) {
      petEvent = PetEvent.breakEnded;
    } else if (event is MeetingDetectedEvent) {
      petEvent = event.isActive
          ? PetEvent.meetingDetected
          : PetEvent.meetingEnded;
    } else if (event is FocusModeEvent) {
      petEvent = event.isActive ? PetEvent.focusModeOn : PetEvent.focusModeOff;
    } else if (event is IdleDetectedEvent) {
      petEvent = event.isIdle
          ? PetEvent.idleTimeout
          : PetEvent.activityDetected;
    } else if (event is CompanionInteractionEvent) {
      switch (event.interactionType) {
        case 'tap':
          petEvent = PetEvent.userClick;
          break;
        case 'doubleTap':
          petEvent = PetEvent.userDoubleClick;
          break;
        case 'hover':
          petEvent = PetEvent.userHover;
          break;
        case 'dragStart':
          petEvent = PetEvent.userDragStart;
          break;
        case 'dragEnd':
          petEvent = PetEvent.userDragEnd;
          break;
      }
    }
    if (petEvent != null) {
      _petService.handleEvent(petEvent);
    }
  }

  void _applyStateToComponent() {
    if (_stateMachine.currentState == CatState.idle) {
      return;
    }
    final animState = _mapCatStateToAnimationState(_stateMachine.currentState);
    catComponent?.changeState(animState);
  }

  void _applyPetStateToComponent(PetState state) {
    final animState = _mapPetStateToAnimationState(state);
    catComponent?.changeState(animState);
  }

  CatAnimationState _mapCatStateToAnimationState(CatState state) {
    switch (state) {
      case CatState.idle:
        return CatAnimationState.idle;
      case CatState.blink:
        return CatAnimationState.idle;
      case CatState.stretch:
        return CatAnimationState.celebrate;
      case CatState.walk:
        return CatAnimationState.walk;
      case CatState.sleep:
        return CatAnimationState.sleep;
      case CatState.alert:
        return CatAnimationState.notification;
      case CatState.happy:
        return CatAnimationState.excited;
      case CatState.drag:
        return CatAnimationState.idle;
      case CatState.breakReminder:
        return CatAnimationState.breakMode;
      case CatState.meetingPaused:
        return CatAnimationState.sad;
      case CatState.focusMode:
        return CatAnimationState.focusMode;
    }
  }

  CatAnimationState _mapPetStateToAnimationState(PetState state) {
    switch (state) {
      case PetState.idle:
      case PetState.blink:
      case PetState.resting:
        return CatAnimationState.idle;
      case PetState.stretch:
      case PetState.celebrating:
      case PetState.dancing:
        return CatAnimationState.celebrate;
      case PetState.walk:
      case PetState.following:
      case PetState.exploring:
        return CatAnimationState.walk;
      case PetState.run:
      case PetState.jumping:
        return CatAnimationState.run;
      case PetState.sleep:
      case PetState.quiet:
        return CatAnimationState.sleep;
      case PetState.alert:
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
      case PetState.curious:
      case PetState.interacting:
        return CatAnimationState.notification;
      case PetState.playing:
        return CatAnimationState.run;
      case PetState.eating:
      case PetState.grooming:
        return CatAnimationState.idle;
      case PetState.bored:
        return CatAnimationState.idle;
      case PetState.drag:
        return CatAnimationState.idle;
      case PetState.turning:
        return CatAnimationState.walk;
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
      initialState: _mapCatStateToAnimationState(_stateMachine.currentState),
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
        _stateMachine.handleEvent(CatEvent.userClick);
        _petService.handleEvent(PetEvent.userClick);
        break;
      case 'doubleTap':
        _stateMachine.handleEvent(CatEvent.userDoubleClick);
        _petService.handleEvent(PetEvent.userDoubleClick);
        break;
      case 'hover':
        _stateMachine.handleEvent(CatEvent.userHover);
        _petService.handleEvent(PetEvent.userHover);
        break;
      case 'dragStart':
        _stateMachine.handleEvent(CatEvent.userDragStart);
        _petService.handleEvent(PetEvent.userDragStart);
        break;
      case 'dragEnd':
        _stateMachine.handleEvent(CatEvent.userDragEnd);
        _petService.handleEvent(PetEvent.userDragEnd);
        break;
    }
    _applyStateToComponent();
  }

  @override
  void update(double dt) {
    super.update(dt);

    _stateMachine.handleEvent(CatEvent.tick);
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
