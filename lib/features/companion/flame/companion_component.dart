import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/flame/companion_game.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';

enum MouseFollowState {
  idle,
  stalk,
  chase,
  caught,
  satisfied,
}

enum FreeWanderingState {
  groundWalk,
  groundSniff,
  wallClimb,
  wallSit,
  leap,
  sleep,
  idle,
}

/// Generic companion component that works for any pet type (cat, dog, etc.).
/// The active [CatTheme] determines breed-specific physics and behavior.
class CompanionComponent extends SpriteAnimationGroupComponent<CatAnimationState>
    with HasGameReference<CompanionGame>, TapCallbacks, HoverCallbacks {
  // Movement velocities
  double _direction = 1.0; // 1.0 = Right, -1.0 = Left, or for climbing: 1.0 = Down, -1.0 = Up
  double _speed = 0.0;
  final Vector2 _velocity = Vector2.zero();

  // State machine & timing
  double _stateElapsed = 0.0;
  CatAnimationState? _previousState;

  // Random wandering logic
  final Random _random = Random();
  double _behaviorTimer = 0.0;
  bool _isWanderingEnabled = true;
  FreeWanderingState _wanderState = FreeWanderingState.idle;

  // Interaction state
  CatAnimationState? _interactionRevertState;

  // Mouse follow state FSM
  bool _isFollowingMouse = false;
  MouseFollowState _mouseState = MouseFollowState.idle;
  double _stalkTimer = 0.0;
  double _satisfiedTimer = 0.0;
  double _caughtTimer = 0.0;
  Vector2? _targetMouse;

  CompanionComponent({
    required Map<CatAnimationState, SpriteAnimation> animations,
    CatAnimationState initialState = CatAnimationState.idle,
  }) : super(
          animations: animations,
          current: initialState,
          anchor: Anchor.center,
        );

  // --- Breed-Specific Physics & Stride Profiles ---

  bool get _isDog => game.currentTheme.isDog;

  double get _strideFrequency {
    final id = game.currentTheme.id;
    if (id == CatTheme.keyCorgi) return 1.95; // Corgis move short legs extremely fast
    if (id == CatTheme.keyHusky || id == CatTheme.keyCollie) return 1.0;
    if (_isDog) return 1.25;
    if (id == CatTheme.keyLargeCat) return 0.72; // Slow lazy heavy walk
    return 1.15; // Nimble cats
  }

  double get _maxChaseSpeed {
    final id = game.currentTheme.id;
    if (id == CatTheme.keyCorgi) return 330.0; // Short legs are slower
    if (id == CatTheme.keyHusky || id == CatTheme.keyCollie) return 590.0;
    if (_isDog) return 470.0;
    if (id == CatTheme.keyLargeCat) return 370.0;
    return 490.0; // Nimble chasing cats
  }

  double get _climbProbability {
    if (_isDog) return 0.0; // Dogs can never climb walls
    final id = game.currentTheme.id;
    if (id == CatTheme.keyLargeCat) return 0.12;
    return 0.38;
  }

  @override
  void onMount() {
    super.onMount();
    _updateFlip();
    _resetBehaviorTimer();
  }

  /// Changes the active animation state.
  /// Tracks previous looping state to revert to after non-looping animations finish.
  void changeState(CatAnimationState newState, {bool force = false}) {
    if (current == newState && !force) return;

    final currentAnim = animations?[current];
    final isNewAnimLooping = animations?[newState]?.loop ?? true;

    // If changing FROM a looping anim TO a non-looping one, save the previous state
    if (currentAnim != null && currentAnim.loop && !isNewAnimLooping) {
      _previousState = current;
    } else if (isNewAnimLooping) {
      _previousState = null;
    }

    // Reset the ticker for the new state so it plays from the beginning cleanly
    animationTickers?[newState]?.reset();

    current = newState;
    _stateElapsed = 0.0;
    _updateSpeedAndBehavior();
    _updateFlip();
  }

  /// Sets whether the companion is allowed to wander randomly.
  void setWanderingEnabled(bool enabled) {
    _isWanderingEnabled = enabled;
    if (!enabled) {
      _behaviorTimer = 0.0;
    }
  }

  /// Computes appropriate speed based on the current animation state.
  void _updateSpeedAndBehavior() {
    if (_isFollowingMouse) {
      _speed = 0.0;
      return;
    }

    switch (current) {
      case CatAnimationState.walk:
        if (_wanderState == FreeWanderingState.wallClimb) {
          _speed = 22.0; // Slower realistic vertical climb
        } else {
          _speed = _isDog ? 28.0 : 18.0; // Natural ground gait speed
        }
        break;
      case CatAnimationState.excited:
      case CatAnimationState.breakMode:
        _speed = _isDog ? 62.0 : 44.0;
        break;
      case CatAnimationState.celebrate:
        _speed = 52.0;
        break;
      default:
        _speed = 0.0;
        break;
    }
  }

  /// Flips the sprite horizontally based on movement direction.
  void _updateFlip() {
    if (_direction < 0) {
      if (scale.x > 0) scale.x = -scale.x.abs();
    } else {
      if (scale.x < 0) scale.x = scale.x.abs();
    }
  }

  void _resetBehaviorTimer() {
    _behaviorTimer = 9.0 + _random.nextDouble() * 11.0;
  }

  /// Breed-specific organic free-wandering behavior generator.
  void _performRandomBehavior() {
    if (!_isWanderingEnabled) return;

    final double roll = _random.nextDouble();

    if (_isDog) {
      // ----------------------------------------------------
      // DOG WANDERING SELECTION
      // ----------------------------------------------------
      if (roll < 0.35) {
        // Walk horizontally
        _wanderState = FreeWanderingState.groundWalk;
        _direction = _random.nextBool() ? 1.0 : -1.0;
        changeState(CatAnimationState.walk);
        _resetBehaviorTimer();
      } else if (roll < 0.60) {
        // Olfactory Sniff pause (dog-specific ground investigation)
        _wanderState = FreeWanderingState.groundSniff;
        changeState(animations?.containsKey(CatAnimationState.typing) == true
            ? CatAnimationState.typing
            : CatAnimationState.sad);
        _behaviorTimer = 2.0 + _random.nextDouble() * 3.5;
      } else if (roll < 0.80) {
        // Sit down attentively
        _wanderState = FreeWanderingState.idle;
        changeState(CatAnimationState.idle);
        _resetBehaviorTimer();
      } else if (roll < 0.92) {
        // Happy barking/wagging tail alert
        _wanderState = FreeWanderingState.idle;
        changeState(CatAnimationState.notification);
        _behaviorTimer = 1.5;
      } else {
        // Resting sleep
        _wanderState = FreeWanderingState.sleep;
        changeState(CatAnimationState.sleep);
        _behaviorTimer = 8.0 + _random.nextDouble() * 9.0;
      }
    } else {
      // ----------------------------------------------------
      // CAT WANDERING SELECTION
      // ----------------------------------------------------
      if (_wanderState == FreeWanderingState.wallClimb || _wanderState == FreeWanderingState.wallSit) {
        // Currently on a wall drape
        if (roll < 0.40) {
          // Continue climbing up/down
          _wanderState = FreeWanderingState.wallClimb;
          _direction = _random.nextBool() ? 1.0 : -1.0;
          changeState(CatAnimationState.walk);
          _behaviorTimer = 3.5 + _random.nextDouble() * 5.0;
        } else if (roll < 0.70) {
          // Sit on wall edge
          _wanderState = FreeWanderingState.wallSit;
          changeState(animations?.containsKey(CatAnimationState.lick1) == true
              ? CatAnimationState.lick1
              : CatAnimationState.idle);
          _behaviorTimer = 4.0 + _random.nextDouble() * 6.5;
        } else {
          // Playful leap from altitude!
          final left = position.x < game.size.x / 2;
          _wanderState = FreeWanderingState.leap;
          _velocity.x = left
              ? (130.0 + _random.nextDouble() * 110.0)
              : (-130.0 - _random.nextDouble() * 110.0);
          _velocity.y = -85.0 - _random.nextDouble() * 75.0;
          changeState(CatAnimationState.excited);
          _behaviorTimer = 6.0;
        }
      } else {
        // Currently on the floor
        if (roll < 0.35) {
          // Ground horizontal stroll
          _wanderState = FreeWanderingState.groundWalk;
          _direction = _random.nextBool() ? 1.0 : -1.0;
          changeState(CatAnimationState.walk);
          _resetBehaviorTimer();
        } else if (roll < 0.55) {
          // Grooming/Licking paw behavior
          _wanderState = FreeWanderingState.idle;
          final possibleLicks = <CatAnimationState>[];
          if (animations?.containsKey(CatAnimationState.lick1) == true) {
            possibleLicks.add(CatAnimationState.lick1);
          }
          if (animations?.containsKey(CatAnimationState.lick2) == true) {
            possibleLicks.add(CatAnimationState.lick2);
          }
          possibleLicks.add(CatAnimationState.idle);
          changeState(possibleLicks[_random.nextInt(possibleLicks.length)]);
          _behaviorTimer = 3.5 + _random.nextDouble() * 4.0;
        } else if (roll < 0.75) {
          // Catnap sleep
          _wanderState = FreeWanderingState.sleep;
          changeState(CatAnimationState.sleep);
          _behaviorTimer = 11.0 + _random.nextDouble() * 14.0;
        } else if (roll < 0.90) {
          // Yawn & Stretch behavior
          _wanderState = FreeWanderingState.idle;
          changeState(animations?.containsKey(CatAnimationState.breakMode) == true
              ? CatAnimationState.breakMode
              : CatAnimationState.celebrate);
          _behaviorTimer = 2.8;
        } else {
          // Meow/Notification vocalization
          _wanderState = FreeWanderingState.idle;
          changeState(CatAnimationState.notification);
          _behaviorTimer = 1.8;
        }
      }
    }
  }

  @override
  void update(double dt) {
    // --- Stride Frequency scaling for walking/running animations ---
    // This makes the sprite animation speed match the physical stride rate.
    // Only scale walk and excited states – other states play at their natural speed.
    double scaledDt = dt;
    if (current == CatAnimationState.walk || current == CatAnimationState.excited) {
      scaledDt = dt * _strideFrequency;
    }
    super.update(scaledDt);

    _stateElapsed += dt;

    // --- Auto-revert non-looping animations ---
    // FIX: Use the Flame ticker's done() signal (which respects scaledDt) as the
    // single source of truth. Remove the old manual unscaled _stateElapsed check
    // that fought with the ticker and caused premature cutoffs.
    final currentAnim = animations?[current];
    if (currentAnim != null && !currentAnim.loop) {
      final ticker = animationTickers?[current];
      if (ticker != null && ticker.done()) {
        ticker.reset();
        if (_previousState != null) {
          changeState(_previousState!);
        } else {
          changeState(CatAnimationState.idle);
        }
        // Skip remaining update logic since state just changed
        return;
      }
    }

    final double spriteSize = game.currentTheme.spriteSize.toDouble();
    final double currentScale = scale.x.abs();
    final double scaledHalfH = (spriteSize * currentScale) / 2;
    final double scaledHalfW = (spriteSize * currentScale) / 2;
    final double groundY = game.size.y - scaledHalfH - 4.0;

    if (_isFollowingMouse && _targetMouse != null) {
      // ----------------------------------------------------
      // MOUSE CURSOR FOLLOW FSM
      // ----------------------------------------------------
      angle = 0.0;
      scale.y = scale.x.abs(); // Reset custom scale modifiers

      final Vector2 toMouse = _targetMouse! - position;
      final double distance = toMouse.length;

      switch (_mouseState) {
        case MouseFollowState.idle:
          if (distance > 40.0) {
            _mouseState = MouseFollowState.stalk;
            _stalkTimer = _isDog ? 0.10 : 0.75;

            _direction = toMouse.x > 0 ? 1.0 : -1.0;
            _updateFlip();

            changeState(_isDog ? CatAnimationState.excited : CatAnimationState.notification);
          }
          break;

        case MouseFollowState.stalk:
          _stalkTimer -= dt;

          _direction = toMouse.x > 0 ? 1.0 : -1.0;
          _updateFlip();

          // Cat butt-wiggle oscillation physics before pounce
          if (!_isDog) {
            angle = sin(_stalkTimer * 12.0) * 0.08;
          }

          if (_stalkTimer <= 0.0) {
            angle = 0.0;
            _mouseState = MouseFollowState.chase;
            changeState(CatAnimationState.excited);
            _velocity.setZero();
          }
          break;

        case MouseFollowState.chase:
          _direction = toMouse.x > 0 ? 1.0 : -1.0;
          _updateFlip();

          if (distance > 15.0) {
            final Vector2 toMouseNormalized = toMouse.normalized();
            final double targetSpeed = (distance * 3.5).clamp(120.0, _maxChaseSpeed);
            final Vector2 targetVelocity = toMouseNormalized * targetSpeed;
            // Smooth spring-damper acceleration
            _velocity.add((targetVelocity - _velocity) * (1.0 - exp(-8.0 * dt)));
            position += _velocity * dt;
          } else {
            // Caught cursor!
            _mouseState = MouseFollowState.caught;
            _caughtTimer = _isDog ? 4.0 : 2.5;
            _velocity.setZero();
            _playCaughtAnimation();
          }
          break;

        case MouseFollowState.caught:
          _caughtTimer -= dt;

          if (toMouse.length > 5.0) {
            _direction = toMouse.x > 0 ? 1.0 : -1.0;
            _updateFlip();
          }

          // Attentive tail-wag body stretch bounce for dogs
          if (_isDog) {
            final double bounce = sin(_stateElapsed * 4.5) * 0.02;
            scale.y = scale.x.abs() * (1.0 + bounce);
          }

          // Ride nicely centered on cursor tip
          position.lerp(_targetMouse!, 1.0 - exp(-15.0 * dt));

          // Lose grip if mouse is jerked away quickly
          if (distance > 100.0) {
            _mouseState = MouseFollowState.stalk;
            _stalkTimer = _isDog ? 0.10 : 0.75;
            changeState(_isDog ? CatAnimationState.excited : CatAnimationState.notification);
            _velocity.setZero();
          } else if (_caughtTimer <= 0.0) {
            if (_isDog) {
              // Eager loyal dogs skip satisfied ignore cool-down
              _mouseState = MouseFollowState.idle;
            } else {
              _mouseState = MouseFollowState.satisfied;
              _satisfiedTimer = 4.0;
              changeState(animations?.containsKey(CatAnimationState.typing) == true
                  ? CatAnimationState.typing
                  : CatAnimationState.idle);
            }
          }
          break;

        case MouseFollowState.satisfied:
          _satisfiedTimer -= dt;

          if (distance > 150.0) {
            _satisfiedTimer = 0.0;
          }

          if (_satisfiedTimer <= 0.0) {
            _mouseState = MouseFollowState.idle;
            changeState(CatAnimationState.idle);
          }
          break;
      }
    } else {
      // ----------------------------------------------------
      // FREE WANDERING MODE
      // ----------------------------------------------------

      // Dog-specific tail-wag body pant bounce during idle/celebrate
      if (_isDog) {
        if (current == CatAnimationState.idle || current == CatAnimationState.celebrate) {
          final double bounce = sin(_stateElapsed * 4.5) * 0.02;
          scale.y = scale.x.abs() * (1.0 + bounce);
        } else {
          scale.y = scale.x.abs();
        }
      }

      switch (_wanderState) {
        case FreeWanderingState.idle:
        case FreeWanderingState.sleep:
        case FreeWanderingState.groundSniff:
          angle = 0.0;
          if ((position.y - groundY).abs() > 0.5) {
            position.y += (groundY - position.y) * (1.0 - exp(-10.0 * dt));
          }
          break;

        case FreeWanderingState.groundWalk:
          angle = 0.0;
          if ((position.y - groundY).abs() > 0.5) {
            position.y += (groundY - position.y) * (1.0 - exp(-10.0 * dt));
          }

          if (_speed > 0) {
            final double dx = _direction * _speed * dt;
            position.x += dx;

            // Border rebounds and climb transitions
            if (position.x < scaledHalfW) {
              position.x = scaledHalfW;
              if (!_isDog && _random.nextDouble() < _climbProbability) {
                _wanderState = FreeWanderingState.wallClimb;
                _direction = -1.0; // Climb UP
                _speed = 22.0;
                changeState(CatAnimationState.walk);
                _behaviorTimer = 4.0 + _random.nextDouble() * 5.0;
              } else {
                _direction = 1.0;
                _updateFlip();
              }
            } else if (position.x > game.size.x - scaledHalfW) {
              position.x = game.size.x - scaledHalfW;
              if (!_isDog && _random.nextDouble() < _climbProbability) {
                _wanderState = FreeWanderingState.wallClimb;
                _direction = -1.0; // Climb UP
                _speed = 22.0;
                changeState(CatAnimationState.walk);
                _behaviorTimer = 4.0 + _random.nextDouble() * 5.0;
              } else {
                _direction = -1.0;
                _updateFlip();
              }
            }
          }
          break;

        case FreeWanderingState.wallClimb:
          final bool isLeft = position.x < game.size.x / 2;
          position.x = isLeft ? scaledHalfW : game.size.x - scaledHalfW;

          // Rotate sprite flat against vertical screen edge
          if (isLeft) {
            if (_direction == -1.0) {
              scale.x = scale.x.abs();
              angle = -pi / 2; // Up
            } else {
              scale.x = scale.x.abs();
              angle = pi / 2; // Down
            }
          } else {
            if (_direction == -1.0) {
              scale.x = -scale.x.abs();
              angle = pi / 2; // Up
            } else {
              scale.x = -scale.x.abs();
              angle = -pi / 2; // Down
            }
          }

          position.y += _direction * _speed * dt;

          final double topLimit = scaledHalfH + 24.0;
          if (position.y < topLimit) {
            position.y = topLimit;
            _direction = 1.0; // Climb down
          } else if (position.y > groundY) {
            position.y = groundY;
            _wanderState = FreeWanderingState.groundWalk;
            angle = 0.0;
            _direction = isLeft ? 1.0 : -1.0;
            _updateFlip();
            changeState(CatAnimationState.idle);
            _resetBehaviorTimer();
          }
          break;

        case FreeWanderingState.wallSit:
          final bool isLeftSit = position.x < game.size.x / 2;
          position.x = isLeftSit ? scaledHalfW : game.size.x - scaledHalfW;
          angle = isLeftSit ? -pi / 2 : pi / 2;
          if (isLeftSit) {
            scale.x = scale.x.abs();
          } else {
            scale.x = -scale.x.abs();
          }
          break;

        case FreeWanderingState.leap:
          position.x += _velocity.x * dt;
          position.y += _velocity.y * dt;
          _velocity.y += 420.0 * dt; // Gravity acceleration

          // Smoothly rotate sprite with jump trajectory vector
          angle = atan2(_velocity.y, _velocity.x);

          if (_velocity.x < 0) {
            scale.x = -scale.x.abs();
            angle = angle + pi;
          } else {
            scale.x = scale.x.abs();
          }

          if (position.y >= groundY) {
            position.y = groundY;
            _wanderState = FreeWanderingState.groundWalk;
            angle = 0.0;
            _velocity.setZero();
            changeState(CatAnimationState.idle);
            _resetBehaviorTimer();
          } else if (position.x <= scaledHalfW) {
            position.x = scaledHalfW;
            _wanderState = FreeWanderingState.wallSit;
            _velocity.setZero();
            changeState(CatAnimationState.idle);
            _resetBehaviorTimer();
          } else if (position.x >= game.size.x - scaledHalfW) {
            position.x = game.size.x - scaledHalfW;
            _wanderState = FreeWanderingState.wallSit;
            _velocity.setZero();
            changeState(CatAnimationState.idle);
            _resetBehaviorTimer();
          }
          break;
      }
    }

    // AI wandering check timer
    if (_isWanderingEnabled && !_isFollowingMouse && _wanderState != FreeWanderingState.leap) {
      _behaviorTimer -= dt;
      if (_behaviorTimer <= 0) {
        _performRandomBehavior();
      }
    }
  }

  void _playCaughtAnimation() {
    if (_isDog) {
      changeState(CatAnimationState.celebrate);
    } else {
      final possibleInteractions = <CatAnimationState>[];
      if (animations?.containsKey(CatAnimationState.lick1) == true) {
        possibleInteractions.add(CatAnimationState.lick1);
      }
      if (animations?.containsKey(CatAnimationState.lick2) == true) {
        possibleInteractions.add(CatAnimationState.lick2);
      }
      if (animations?.containsKey(CatAnimationState.celebrate) == true) {
        possibleInteractions.add(CatAnimationState.celebrate);
      }
      possibleInteractions.add(CatAnimationState.excited);

      final chosenState = possibleInteractions[_random.nextInt(possibleInteractions.length)];
      changeState(chosenState);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    paint.filterQuality = FilterQuality.medium;
    super.render(canvas);
    canvas.restore();
  }

  // --- TapCallbacks ---

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

  void updateMouseFollow(Map<dynamic, dynamic> data) {
    final bool enabled = data['enabled'] as bool? ?? false;

    if (enabled) {
      _isFollowingMouse = true;
      _isWanderingEnabled = false;
      _speed = 0.0;

      final double? mx = (data['mouseX'] as num?)?.toDouble();
      final double? my = (data['mouseY'] as num?)?.toDouble();
      if (mx != null && my != null) {
        _targetMouse = Vector2(mx, my);
      }
    } else {
      if (_isFollowingMouse) {
        _isFollowingMouse = false;
        _isWanderingEnabled = true;
        _mouseState = MouseFollowState.idle;
        _wanderState = FreeWanderingState.idle;
        angle = 0.0;
        scale.y = scale.x.abs();
        changeState(CatAnimationState.idle);
      }
    }
  }

  bool _isNonLoopingState(CatAnimationState state) {
    return state == CatAnimationState.celebrate ||
           state == CatAnimationState.excited ||
           state == CatAnimationState.notification;
  }
}
