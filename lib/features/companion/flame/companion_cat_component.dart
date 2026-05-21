import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/flame/companion_game.dart';

class CompanionCatComponent extends SpriteAnimationGroupComponent<CatAnimationState>
    with HasGameReference<CompanionGame>, TapCallbacks, HoverCallbacks {
  // Movement velocities
  double _direction = 1.0; // 1.0 = Right, -1.0 = Left
  double _speed = 0.0;
  
  // State machine & timing
  double _stateElapsed = 0.0;
  CatAnimationState? _previousState;
  
  // Random wandering logic (only active when idle)
  final Random _random = Random();
  double _behaviorTimer = 0.0;
  bool _isWanderingEnabled = true;

  // Interaction state
  CatAnimationState? _interactionRevertState;

  CompanionCatComponent({
    required Map<CatAnimationState, SpriteAnimation> animations,
    CatAnimationState initialState = CatAnimationState.idle,
  }) : super(
          animations: animations,
          current: initialState,
          anchor: Anchor.center,
        );

  @override
  void onMount() {
    super.onMount();
    _updateFlip();
    _resetBehaviorTimer();
  }

  /// Changes the active animation state.
  /// If it is a non-looping animation, it tracks it to return to the previous state.
  void changeState(CatAnimationState newState, {bool force = false}) {
    if (current == newState && !force) return;

    final currentAnim = animations?[current];
    final isNewAnimLooping = animations?[newState]?.loop ?? true;

    // If changing from a looping animation to a non-looping one, save the previous state
    if (currentAnim != null && currentAnim.loop && !isNewAnimLooping) {
      _previousState = current;
    } else if (isNewAnimLooping) {
      _previousState = null;
    }

    current = newState;
    _stateElapsed = 0.0;
    _updateSpeedAndBehavior();
    _updateFlip();
  }

  /// Sets whether the cat is allowed to wander randomly (e.g. disabled during Focus mode).
  void setWanderingEnabled(bool enabled) {
    _isWanderingEnabled = enabled;
    if (!enabled) {
      _behaviorTimer = 0.0;
    }
  }

  /// Computes appropriate horizontal speed based on the current state.
  void _updateSpeedAndBehavior() {
    switch (current) {
      case CatAnimationState.walk:
        _speed = 15.0; // Moderate walking speed
        break;
      case CatAnimationState.excited:
      case CatAnimationState.breakMode:
        _speed = 40.0; // Fast excited running
        break;
      case CatAnimationState.celebrate:
        _speed = 50.0; // Bounding celebration speed
        break;
      default:
        _speed = 0.0; // Static states (idle, sleeping, typing, etc.)
        break;
    }
  }

  /// Flips the sprite horizontally using the scale vector based on movement direction.
  void _updateFlip() {
    // If direction is -1 (left), flip the sprite. Otherwise, reset scale to positive.
    if (_direction < 0) {
      if (scale.x > 0) scale.x = -scale.x.abs();
    } else {
      if (scale.x < 0) scale.x = scale.x.abs();
    }
  }

  void _resetBehaviorTimer() {
    // Decides next action in 10 to 20 seconds
    _behaviorTimer = 10.0 + _random.nextDouble() * 10.0;
  }

  /// Standard random wandering state machine for companion idle times.
  void _performRandomBehavior() {
    if (!_isWanderingEnabled) return;

    final double roll = _random.nextDouble();
    if (roll < 0.35) {
      // 35% chance to wander/walk
      _direction = _random.nextBool() ? 1.0 : -1.0;
      changeState(CatAnimationState.walk);
    } else if (roll < 0.60) {
      // 25% chance to type/paw
      changeState(CatAnimationState.typing);
    } else if (roll < 0.85) {
      // 25% chance to curl up and sleep
      changeState(CatAnimationState.sleep);
    } else {
      // 15% chance to sit/groom
      changeState(CatAnimationState.idle);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Auto-revert non-looping animations back to idle when finished
    if (animationTickers?[current]?.done() == true) {
      animationTickers?[current]?.reset();
      changeState(CatAnimationState.idle);
    }

    _stateElapsed += dt;

    // 1. Manage non-looping animation expiration
    final currentAnim = animations?[current];
    if (currentAnim != null && !currentAnim.loop) {
      final double totalDuration = currentAnim.frames.fold<double>(
        0.0,
        (sum, frame) => sum + frame.stepTime,
      );
      if (_stateElapsed >= totalDuration) {
        // Return to previous looping state or default to idle
        if (_previousState != null) {
          changeState(_previousState!);
        } else {
          changeState(CatAnimationState.idle);
        }
        return;
      }
    }

    // 2. Horizontal physics/movement & boundary rebound checks
    final double scaledWidth = size.x * scale.x.abs();
    if (scaledWidth < game.size.x) {
      if (_speed > 0) {
        position.x += _direction * _speed * dt;

        final double halfWidth = scaledWidth / 2;
        // Rebound left edge
        if (position.x < halfWidth) {
          position.x = halfWidth;
          _direction = 1.0;
          _updateFlip();
        }
        // Rebound right edge
        else if (position.x > game.size.x - halfWidth) {
          position.x = game.size.x - halfWidth;
          _direction = -1.0;
          _updateFlip();
        }
      }
    } else {
      // If the cat is wider or equal to the window, center it and don't walk or oscillate
      position.x = game.size.x / 2;
      if (current == CatAnimationState.walk ||
          current == CatAnimationState.excited ||
          current == CatAnimationState.breakMode ||
          current == CatAnimationState.celebrate) {
        changeState(CatAnimationState.idle);
      }
    }

    // 3. Wandering AI Behavior Timer ticks
    if (_isWanderingEnabled && _speed == 0.0) {
      _behaviorTimer -= dt;
      if (_behaviorTimer <= 0) {
        _performRandomBehavior();
        _resetBehaviorTimer();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    // Use medium quality for smooth scaling at the 4-5x magnification used in the companion
    paint.filterQuality = FilterQuality.medium;
    super.render(canvas);
    canvas.restore();
  }

  // --- TapCallbacks (click interaction) ---

  @override
  void onTapDown(TapDownEvent event) {
    final currentState = current;
    if (currentState != null && !_isNonLoopingState(currentState)) {
      _interactionRevertState = currentState;
    }
    game.onUserInteraction('tap');
    changeState(CatAnimationState.excited);
  }

  @override
  void onTapUp(TapUpEvent event) {
    game.onUserInteraction('doubleTap');
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_interactionRevertState != null) {
        changeState(_interactionRevertState!);
        _interactionRevertState = null;
      } else {
        changeState(CatAnimationState.idle);
      }
    });
  }

  @override
  void onHoverEnter() {
    game.onUserInteraction('hover');
    final currentState = current;
    if (currentState == CatAnimationState.idle || currentState == CatAnimationState.walk) {
      _interactionRevertState = currentState;
      changeState(CatAnimationState.notification);
    }
  }

  @override
  void onHoverExit() {
    if (_interactionRevertState != null) {
      changeState(_interactionRevertState!);
      _interactionRevertState = null;
    }
  }

  bool _isNonLoopingState(CatAnimationState state) {
    return state == CatAnimationState.celebrate ||
           state == CatAnimationState.excited ||
           state == CatAnimationState.notification;
  }
}
