import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/features/companion/data/cat_asset_loader.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/cat_state_machine.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/flame/companion_cat_component.dart';

class CompanionGame extends FlameGame {
  CompanionGame({
    required CatTheme initialTheme,
    this.scaleOverride = 0.0,
  })  : _eventBus = EventBus.instance,
        _stateMachine = CatStateMachine(),
        _theme = initialTheme;

  final EventBus _eventBus;
  final CatStateMachine _stateMachine;
  late StreamSubscription<AppEvent> _eventSubscription;

  CatTheme _theme;
  double scaleOverride; // 0.0 = auto-scale

  CompanionCatComponent? catComponent;


  CatTheme get currentTheme => _theme;
  CatState get companionState => _stateMachine.currentState;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _eventSubscription = _eventBus.stream.listen(_handleAppEvent);
    await _loadAndAttachCat();
  }

  @override
  void onRemove() {
    _eventSubscription.cancel();
    super.onRemove();
  }

  void _handleAppEvent(AppEvent event) {
    final CatEvent? catEvent = _mapAppEventToCatEvent(event);
    if (catEvent != null) {
      _stateMachine.handleEvent(catEvent);
      _applyStateToComponent();
    }
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
        default:
          return null;
      }
    }
    return null;
  }

  void _applyStateToComponent() {
    final animState = _mapCatStateToAnimationState(_stateMachine.currentState);
    if (_stateMachine.currentState == CatState.idle) {
      // If the state machine is idle, let the cat component manage its own wandering/idle states smoothly
      final currentComponentState = catComponent?.current;
      if (currentComponentState == CatAnimationState.idle ||
          currentComponentState == CatAnimationState.walk ||
          currentComponentState == CatAnimationState.typing ||
          currentComponentState == CatAnimationState.sleep) {
        return;
      }
    }
    catComponent?.changeState(animState);
  }

  CatAnimationState _mapCatStateToAnimationState(CatState state) {
    switch (state) {
      case CatState.idle:
        return CatAnimationState.idle;
      case CatState.blink:
        return CatAnimationState.idle; // blink is a short idle variant
      case CatState.stretch:
        return CatAnimationState.celebrate; // stretch animation
      case CatState.walk:
        return CatAnimationState.walk;
      case CatState.sleep:
        return CatAnimationState.sleep;
      case CatState.alert:
        return CatAnimationState.notification;
      case CatState.happy:
        return CatAnimationState.excited;
      case CatState.drag:
        return CatAnimationState.idle; // no special drag anim
      case CatState.breakReminder:
        return CatAnimationState.breakMode;
      case CatState.meetingPaused:
        return CatAnimationState.sad;
      case CatState.focusMode:
        return CatAnimationState.focusMode;
    }
  }

  /// Auto-scales so the cat occupies ~45% of the window height.
  double _effectiveScale(double spriteSize) {
    if (scaleOverride > 0.0) return scaleOverride;
    final double target = size.y * 0.45;
    return (target / spriteSize).clamp(3.0, 10.0);
  }

  Future<void> _loadAndAttachCat() async {
    final animations = await CatAssetLoader.loadAnimations(_theme);
    if (animations.isEmpty) return;

    // Remove any existing CompanionCatComponent to prevent multiple overlapping cats safely
    children.whereType<CompanionCatComponent>().toList().forEach((c) => c.removeFromParent());

    final double spriteSize = _theme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);

    catComponent = CompanionCatComponent(
      animations: animations,
      initialState: _mapCatStateToAnimationState(_stateMachine.currentState),
    );

    catComponent!.size = Vector2(spriteSize, spriteSize);
    catComponent!.scale = Vector2.all(scale);

    final double scaledHalfH = (spriteSize * scale) / 2;
    catComponent!.position = Vector2(
      size.x / 2,
      size.y - scaledHalfH - 4.0,
    );

    add(catComponent!);
  }

  Future<void> updateTheme(CatTheme newTheme) async {
    if (_theme.id == newTheme.id && catComponent != null) return;
    _theme = newTheme;
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

  /// Handle user interactions from the component
  void onUserInteraction(String type) {
    switch (type) {
      case 'tap':
        _stateMachine.handleEvent(CatEvent.userClick);
        break;
      case 'doubleTap':
        _stateMachine.handleEvent(CatEvent.userDoubleClick);
        break;
      case 'hover':
        _stateMachine.handleEvent(CatEvent.userHover);
        break;
      case 'dragStart':
        _stateMachine.handleEvent(CatEvent.userDragStart);
        break;
      case 'dragEnd':
        _stateMachine.handleEvent(CatEvent.userDragEnd);
        break;
    }
    _applyStateToComponent();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Periodically tick the state machine for time-based transitions
    _stateMachine.handleEvent(CatEvent.tick);
    _applyStateToComponent();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (catComponent != null) {
      final double spriteSize = _theme.spriteSize.toDouble();
      final double scale = _effectiveScale(spriteSize);
      catComponent!.scale = Vector2.all(scale);

      final double scaledHalfW = (spriteSize * scale) / 2;
      double newX;
      if (spriteSize * scale < size.x) {
        newX = catComponent!.position.x.clamp(scaledHalfW, size.x - scaledHalfW);
      } else {
        newX = size.x / 2;
      }

      final double scaledHalfH = (spriteSize * scale) / 2;
      catComponent!.position = Vector2(newX, size.y - scaledHalfH - 4.0);
    }
  }
}
