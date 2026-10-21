import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';

class _FireParticle {
  Offset position;
  Offset velocity;
  double age;
  final double maxAge;
  final double size;
  final Color color;

  _FireParticle({
    required this.position,
    required this.velocity,
    required this.maxAge,
    required this.size,
    required this.color,
  }) : age = 0.0;
}

class _CrossFadeState {
  _CrossFadeState({required this.from, required this.to}) : elapsed = 0.0;

  static const double duration = 0.1;

  final PetAnimationState from;
  final PetAnimationState to;
  double elapsed;
}

class CompanionComponent
    extends SpriteAnimationGroupComponent<PetAnimationState>
    with HasGameReference<CompanionGame>, TapCallbacks, HoverCallbacks {
  double _direction = 1.0;
  double _stateElapsed = 0.0;
  PetAnimationState? _previousState;
  final Random _rng = Random();

  double _currentYaw = 0.0;
  double get currentYaw => _currentYaw;
  double get direction => _direction;

  bool get isFlipped => scale.x < 0;

  _CrossFadeState? _crossFadeState;

  // Stable per-state average bottom padding in source pixels.
  // Computed once when the active state changes to avoid per-frame jitter
  // that would occur if we used the raw current-frame value.
  double _currentStatePadding = 0.0;

  static const Set<(PetAnimationState, PetAnimationState)>
  _crossFadeTransitions = {
    (PetAnimationState.idle, PetAnimationState.walkSide),
    (PetAnimationState.walkSide, PetAnimationState.idle),
    (PetAnimationState.walkSide, PetAnimationState.run),
    (PetAnimationState.run, PetAnimationState.walkSide),
    (PetAnimationState.run, PetAnimationState.idle),
    (PetAnimationState.idle, PetAnimationState.run),
  };

  Offset get _snoutOffset =>
      Offset(_direction * (size.x * 0.35), -size.y * 0.12);

  final List<_FireParticle> _particles = [];

  CompanionComponent({
    Map<PetAnimationState, SpriteAnimation>? animations,
    PetAnimationState initialState = PetAnimationState.idle,
  }) : super(
         animations: animations ?? const {},
         current: initialState,
         anchor: Anchor.bottomCenter,
       );

  double get _strideFrequency =>
      isMounted ? game.currentTheme.species.defaultProfile.strideFrequency : 1.0;

  @override
  void onMount() {
    super.onMount();
    paint.filterQuality = FilterQuality.none;
    _updateFlip();
    // Compute initial ground padding now that animations are available.
    if (current != null) {
      _currentStatePadding = _computeStatePadding(current!);
    }
  }

  void updateMovementHeading(Offset vel, {double dt = 0.016}) {
    if (vel.dx.abs() > 0.5 || vel.dy.abs() > 0.5) {
      _direction = vel.dx >= 0 ? 1.0 : -1.0;
      _updateFlip();

      final double targetYaw = atan2(vel.dx, vel.dy);
      final double diff = (targetYaw - _currentYaw + pi) % (2 * pi) - pi;
      _currentYaw += diff * (12.0 * dt).clamp(0.0, 1.0);
    }
  }

  void changeState(PetAnimationState newState, {bool force = false}) {
    var target = newState;

    if (animations != null && animations!.isNotEmpty) {
      if (target == PetAnimationState.walkUp ||
          target == PetAnimationState.walkDown) {
        if (animations?.containsKey(target) != true) {
          target = PetAnimationState.walkSide;
        }
      }

      if (target == PetAnimationState.chasing &&
          animations?.containsKey(target) != true) {
        target = PetAnimationState.run;
      }
      if (target == PetAnimationState.fetching &&
          animations?.containsKey(target) != true) {
        target = PetAnimationState.walkSide;
      }
      if (target == PetAnimationState.falling &&
          animations?.containsKey(target) != true) {
        target = PetAnimationState.run;
      }
      if (target == PetAnimationState.reacting &&
          animations?.containsKey(target) != true) {
        target = PetAnimationState.notification;
      }

      if (animations?.containsKey(target) != true) {
        target = PetAnimationState.idle;
      }
    }

    final bool isSameAnimation =
        animations != null && animations?[current] == animations?[target];

    if (current == target && !force) {
      final anim = animations?[target];
      if (anim != null && !anim.loop) {
        final ticker = animationTickers?[target];
        if (ticker != null && !ticker.done()) return;
      } else {
        return;
      }
    }

    final currentAnim = animations?[current];
    final newAnim = animations?[target];
    final isNewLooping = newAnim?.loop ?? true;

    if (currentAnim != null && currentAnim.loop && !isNewLooping) {
      _previousState = current;
    } else if (isNewLooping) {
      _previousState = null;
    }

    if (current != target && !isSameAnimation) {
      animationTickers?[target]?.reset();
    }

    final PetAnimationState? fromState = current;
    if (fromState != null &&
        _crossFadeTransitions.contains((fromState, target)) &&
        !isSameAnimation) {
      _crossFadeState = _CrossFadeState(from: fromState, to: target);
    } else {
      _crossFadeState = null;
    }

    current = target;
    _updateFlip();
    // Recompute the ground padding for the new state so the Y-offset
    // is stable for the entire duration of the state.
    _currentStatePadding = _computeStatePadding(target);
  }

  void setWanderingEnabled(bool enabled) {
    if (isMounted) {
      game.petService.navigation.setWanderingEnabled(enabled);
    }
  }

  void _updateFlip() {
    final absScale = scale.x.abs();
    scale.x = _direction < 0 ? -absScale : absScale;
  }

  // Hysteresis for run-entry/exit only. Walk is entered freely whenever the
  // navigation service reports movement, so the pet never stays in idle
  // while its position is changing.
  static const double _runStartThreshold = 110.0;
  static const double _runStopThreshold = 80.0;

  static const _fsmOwnedAnimations = {
    PetAnimationState.sleep,
    PetAnimationState.stretch,
    PetAnimationState.breakMode,
    PetAnimationState.focusMode,
    PetAnimationState.sad,
    PetAnimationState.celebrate,
    PetAnimationState.notification,
    PetAnimationState.angry,
    PetAnimationState.lick1,
    PetAnimationState.lick2,
    PetAnimationState.typing,
    PetAnimationState.breatheFire,
  };

  @override
  void update(double dt) {
    if (!isMounted) return;

    final nav = game.petService.navigation;
    final speed = nav.speed;
    final vel = nav.velocity;
    final baseSpeed = game.currentTheme.species.defaultProfile.movementSpeed;

    final servicePos = nav.currentPosition;
    position.setValues(servicePos.dx, servicePos.dy);

    updateMovementHeading(vel, dt: dt);

    double scaledDt = dt;
    if (current == PetAnimationState.walkSide ||
        current == PetAnimationState.walkUp ||
        current == PetAnimationState.walkDown) {
      final activeSpeed = speed > 0.5 ? speed : (baseSpeed * 0.4);
      final speedRatio = (activeSpeed / baseSpeed).clamp(0.2, 2.5);
      scaledDt = dt * speedRatio * _strideFrequency;
    } else if (current == PetAnimationState.run) {
      final activeSpeed = speed > 0.5 ? speed : (baseSpeed * 0.8);
      final speedRatio = (activeSpeed / (baseSpeed * 1.8)).clamp(0.4, 2.5);
      scaledDt = dt * speedRatio;
    } else if (current == PetAnimationState.excited) {
      scaledDt = dt * _strideFrequency;
    }

    if (game.isQuietMode) {
      scaledDt *= 0.6;
    }

    super.update(scaledDt);
    _stateElapsed += dt;

    if (_crossFadeState != null) {
      _crossFadeState!.elapsed += dt;
      // Manually update the 'from' ticker since SpriteAnimationGroupComponent
      // only updates the 'current' ticker.
      animationTickers?[_crossFadeState!.from]?.update(dt);

      if (_crossFadeState!.elapsed >= _CrossFadeState.duration) {
        _crossFadeState = null;
      }
    }

    final currentAnim = animations?[current];
    if (currentAnim != null && !currentAnim.loop) {
      final ticker = animationTickers?[current];
      if (ticker != null && ticker.done()) {
        ticker.reset();
        game.petService.handleEvent(PetEvent.animationComplete);
        final newAnim = animations?[current];
        if (newAnim != null &&
            !newAnim.loop &&
            current != (_previousState ?? PetAnimationState.idle)) {
          return;
        }
        changeState(_previousState ?? PetAnimationState.idle);
        return;
      }
    }

    if (currentAnim != null && currentAnim.loop) {
      final ticker = animationTickers?[current];
      if (ticker != null && ticker.done()) {
        game.petService.handleEvent(PetEvent.loopBlocked);
        return;
      }
    }

    final cur = current ?? PetAnimationState.idle;
    final isNavMoving = nav.isMoving;
    final isFsmOwned = _fsmOwnedAnimations.contains(cur);
    final canOverride = !isFsmOwned || _isMovementState(cur);

    if (canOverride) {
      final bool isRunning = cur == PetAnimationState.run;

      if (speed > 1.5 && isNavMoving) {
        // Run hysteresis: need higher speed to START running, lower to STAY.
        final bool shouldRun = isRunning
            ? speed > _runStopThreshold
            : speed > _runStartThreshold;

        if (shouldRun) {
          changeState(PetAnimationState.run);
        } else {
          // Walk: choose direction from velocity with hysteresis to prevent flicker.
          PetAnimationState walkState =
              (current == PetAnimationState.walkUp ||
                  current == PetAnimationState.walkDown)
              ? current!
              : PetAnimationState.walkSide;

          final double dx = vel.dx.abs();
          final double dy = vel.dy.abs();
          final double diff = dy - dx;

          if (diff > 5.0) {
            // Bias towards vertical
            walkState = vel.dy < 0
                ? PetAnimationState.walkUp
                : PetAnimationState.walkDown;
          } else if (diff < -5.0) {
            // Bias towards horizontal
            walkState = PetAnimationState.walkSide;
          }
          // If within [-5, 5], retain previous state to prevent animation resets.

          changeState(walkState);
        }
      } else {
        if (_isMovementState(cur)) {
          changeState(_previousState ?? PetAnimationState.idle);
        }
      }
    }

    final bool isUsingFallbackWalk = current == PetAnimationState.walkSide;
    final bool isWalkOnly =
        game.currentTheme.species.movementType == MovementType.walk;
    final profile = game.currentTheme.species.defaultProfile;

    if (isWalkOnly) {
      angle = 0.0;
      if (current == PetAnimationState.idle ||
          current == PetAnimationState.celebrate) {
        scale.y =
            scale.x.abs() *
            (1.0 + sin(_stateElapsed * 4.5) * profile.bobIntensity * 0.5);
      } else if (_isMovementState(current)) {
        final double bob = sin(_stateElapsed * 10.0) * profile.bobIntensity;
        scale.y = scale.x.abs() * (1.0 + bob);
      } else {
        scale.y = scale.x.abs();
      }
    } else {
      final bool isMovingVertically = vel.dy.abs() > 1.5 && speed > 5.0;
      if (isMovingVertically &&
          (isUsingFallbackWalk ||
              current == PetAnimationState.run ||
              current == PetAnimationState.excited ||
              current == PetAnimationState.fly)) {
        final double maxSpeed = profile.movementSpeed;
        final double maxTilt = profile.maxTilt;
        final double tiltFactor = (vel.dy / maxSpeed).clamp(-1.0, 1.0);
        angle = _direction * tiltFactor * maxTilt;

        final double stretch = (vel.dy.abs() / 220.0).clamp(0.0, 0.12);
        scale.y = scale.x.abs() * (1.0 + stretch);
      } else {
        angle = 0.0;
        if (current == PetAnimationState.idle ||
            current == PetAnimationState.celebrate) {
          scale.y =
              scale.x.abs() *
              (1.0 + sin(_stateElapsed * 4.5) * profile.bobIntensity * 0.5);
        } else if (_isMovementState(current)) {
          final double bob = sin(_stateElapsed * 10.0) * profile.bobIntensity;
          scale.y = scale.x.abs() * (1.0 + bob);
        } else {
          scale.y = scale.x.abs();
        }
      }
    }

    _updateFireParticles(dt);
  }

  void _updateFireParticles(double dt) {
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.age += dt;
    }
    _particles.removeWhere((p) => p.age >= p.maxAge);

    if (current == PetAnimationState.breatheFire) {
      final origin = _snoutOffset;
      for (int i = 0; i < 2; i++) {
        final double vx = _direction * (60.0 + _rng.nextDouble() * 50.0);
        final double vy = -15.0 + _rng.nextDouble() * 30.0;
        final colors = [
          const Color(0xFFFF3D00),
          const Color(0xFFFF9100),
          const Color(0xFFFFD600),
        ];
        _particles.add(
          _FireParticle(
            position: origin,
            velocity: Offset(vx, vy),
            maxAge: 0.4 + _rng.nextDouble() * 0.3,
            size: 3.0 + _rng.nextDouble() * 5.0,
            color: colors[_rng.nextInt(colors.length)],
          ),
        );
      }
    }
  }

  /// Returns the average bottom transparent padding (in source px) across
  /// all frames of [state]. Called once per state change rather than per
  /// frame, so the resulting Y-offset is stable across the animation cycle.
  double _computeStatePadding(PetAnimationState state) {
    final anim = animations?[state];
    if (anim == null || anim.frames.isEmpty) return 0.0;
    double total = 0.0;
    for (final frame in anim.frames) {
      total += PetAssetLoader.getSpriteBottomPadding(frame.sprite);
    }
    return total / anim.frames.length;
  }

  bool _isMovementState(PetAnimationState? s) =>
      s == PetAnimationState.walkUp ||
      s == PetAnimationState.walkDown ||
      s == PetAnimationState.walkSide ||
      s == PetAnimationState.run ||
      s == PetAnimationState.fly;

  @override
  void render(Canvas canvas) {
    canvas.save();

    // Align the pet's feet to the component's position (ground) by translating
    // the canvas down by the calculated source-pixel padding.
    canvas.translate(0, _currentStatePadding);

    final cf = _crossFadeState;
    if (cf != null) {
      final double t = (cf.elapsed / _CrossFadeState.duration).clamp(0.0, 1.0);

      final fromAnim = animations?[cf.from];
      if (fromAnim != null) {
        final fromTicker = animationTickers?[cf.from];
        if (fromTicker != null) {
          final ui.Image? fromFrame =
              fromTicker.currentIndex < fromAnim.frames.length
              ? fromAnim.frames[fromTicker.currentIndex].sprite.image
              : null;
          if (fromFrame != null) {
            final alphaPaint = Paint()
              ..color = Color.fromRGBO(255, 255, 255, 1.0 - t)
              ..filterQuality = FilterQuality.none;
            final src = fromAnim.frames[fromTicker.currentIndex].sprite.src;
            // Align with Flame's transformed coordinate system (0,0 is top-left).
            canvas.drawImageRect(
              fromFrame,
              src,
              Rect.fromLTWH(0, 0, size.x, size.y),
              alphaPaint,
            );
          }
        }
      }

      final toAnim = animations?[cf.to];
      if (toAnim != null) {
        final toTicker = animationTickers?[cf.to];
        if (toTicker != null && toTicker.currentIndex < toAnim.frames.length) {
          final ui.Image toFrame =
              toAnim.frames[toTicker.currentIndex].sprite.image;
          final alphaPaint = Paint()
            ..color = Color.fromRGBO(255, 255, 255, t)
            ..filterQuality = FilterQuality.none;
          final src = toAnim.frames[toTicker.currentIndex].sprite.src;
          canvas.drawImageRect(
            toFrame,
            src,
            Rect.fromLTWH(0, 0, size.x, size.y),
            alphaPaint,
          );
        }
      }

      _renderOverlays(canvas);
      canvas.restore();
      return;
    }

    if (animationTicker != null && animations != null && animations!.isNotEmpty) {
      super.render(canvas);
    }
    _renderOverlays(canvas);
    canvas.restore();
  }

  void _renderOverlays(Canvas canvas) {
    if (isMounted && game.petService.context.isMeetingDetected) {
      final double spriteSize = game.currentTheme.spriteSize.toDouble();
      final Offset badgePos = Offset(spriteSize * 0.3, -spriteSize * 0.4);

      final paint = Paint()
        ..color = const Color(0xFFFF3B30)
        ..style = PaintingStyle.fill;

      final double pulse = 1.0 + sin(_stateElapsed * 4.0) * 0.2;
      canvas.drawCircle(badgePos, 3.0 * pulse, paint);

      const textStyle = TextStyle(
        color: Colors.white,
        fontSize: 5,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      );
      final textPainter = TextPainter(
        text: const TextSpan(text: 'ON AIR', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, badgePos + const Offset(5, -3));
    }

    if (_particles.isNotEmpty) {
      final paint = Paint()..style = PaintingStyle.fill;
      for (final p in _particles) {
        final double ratio = (p.age / p.maxAge).clamp(0.0, 1.0);
        paint.color = p.color.withValues(alpha: 1.0 - ratio);
        canvas.drawCircle(p.position, p.size * (1.0 - 0.5 * ratio), paint);
      }
    }
  }

  DateTime? _lastTapTime;

  @override
  void onTapDown(TapDownEvent event) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      _lastTapTime = null;
      if (isMounted) game.onUserInteraction('doubleTap');
    } else {
      _lastTapTime = now;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_lastTapTime != null && isMounted) game.onUserInteraction('tap');
  }

  @override
  void onHoverEnter() {
    if (isMounted) game.onUserInteraction('hover');
  }

  void updateMouseFollow(Map<dynamic, dynamic> data) {
    if (!isMounted) return;
    final bool enabled = data['enabled'] as bool? ?? false;
    game.petService.setCursorFollowing(enabled);

    final double? mx = (data['mouseX'] as num?)?.toDouble();
    double? my = (data['mouseY'] as num?)?.toDouble();
    if (mx != null && my != null) {
      if (game.isPiP) {
        my = position.y;
      }
      game.petService.updateCursorPosition(
        Offset(mx, my),
        forceFollowing: enabled,
      );
    }

    if (!enabled) {
      angle = 0.0;
      scale.y = scale.x.abs();
      changeState(PetAnimationState.idle);
    }
  }
}
