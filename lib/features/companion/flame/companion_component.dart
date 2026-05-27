import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
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

class CompanionComponent extends SpriteAnimationGroupComponent<PetAnimationState>
    with HasGameReference<CompanionGame>, TapCallbacks, HoverCallbacks {

  double _direction = 1.0;
  double _stateElapsed = 0.0;
  PetAnimationState? _previousState;
  final Random _rng = Random();

  // Snout offset for Dragon fire breathing particle origin
  Offset get _snoutOffset => Offset(_direction * (size.x * 0.35), -size.y * 0.12);

  // Active fire particles
  final List<_FireParticle> _particles = [];

  CompanionComponent({
    required Map<PetAnimationState, SpriteAnimation> animations,
    PetAnimationState initialState = PetAnimationState.idle,
  }) : super(
          animations: animations,
          current: initialState,
          anchor: Anchor.center,
        );

  double get _strideFrequency => game.currentTheme.species.defaultProfile.strideFrequency;

  @override
  void onMount() {
    super.onMount();
    paint.filterQuality = FilterQuality.none;
    _updateFlip();
  }

  /// Changes animation state safely.
  /// Handles fallback of missing directional animations to side-view walking seamlessly.
  void changeState(PetAnimationState newState, {bool force = false}) {
    var target = newState;

    // Directional walk fallback to side walk
    if (target == PetAnimationState.walkUp || target == PetAnimationState.walkDown) {
      if (animations?.containsKey(target) != true) {
        target = PetAnimationState.walkSide;
      }
    }

    // Safety fallback: if the requested state has no animation, use idle
    if (animations?.containsKey(target) != true) {
      target = PetAnimationState.idle;
    }

    if (current == target && !force) {
      // For a non-looping animation already playing, let it finish — don't restart
      final anim = animations?[target];
      if (anim != null && !anim.loop) {
        final ticker = animationTickers?[target];
        if (ticker != null && !ticker.done()) return;
      } else {
        return; // Same looping state — no-op
      }
    }

    final currentAnim = animations?[current];
    final newAnim = animations?[target];
    final isNewLooping = newAnim?.loop ?? true;

    // Save previous looping state to revert to after non-looping finishes
    if (currentAnim != null && currentAnim.loop && !isNewLooping) {
      _previousState = current;
    } else if (isNewLooping) {
      _previousState = null;
    }

    // Reset ticker only when actually changing state
    if (current != target) {
      animationTickers?[target]?.reset();
    }

    current = target;
    _stateElapsed = 0.0;
    _updateFlip();
  }

  void setWanderingEnabled(bool enabled) {
    game.petService.navigation.setWanderingEnabled(enabled);
  }

  void _updateFlip() {
    final absScale = scale.x.abs();
    scale.x = _direction < 0 ? -absScale : absScale;
  }

  // Speed thresholds (px/s) for animation selection
  static const double _runThreshold = 100.0;

  // FSM states that own their animation — velocity must NOT override these
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
    final nav = game.petService.navigation;
    final speed = nav.speed;
    final vel = nav.velocity;
    final baseSpeed = game.currentTheme.species.defaultProfile.movementSpeed;

    // --- Dynamic Step Time / Prevents Foot-sliding ---
    // Scaled dt based on velocity ratio, ensuring perfect physical pacing
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

    super.update(scaledDt);
    _stateElapsed += dt;

    // Auto-revert non-looping animations back to previous (or idle)
    final currentAnim = animations?[current];
    if (currentAnim != null && !currentAnim.loop) {
      final ticker = animationTickers?[current];
      if (ticker != null && ticker.done()) {
        ticker.reset();
        game.petService.handleEvent(PetEvent.animationComplete);
        final newAnim = animations?[current];
        if (newAnim != null && !newAnim.loop && current != (_previousState ?? PetAnimationState.idle)) {
          return; // FSM chained to another non-looping anim — let it play
        }
        changeState(_previousState ?? PetAnimationState.idle);
        return;
      }
    }

    // Sync position from navigation service
    final servicePos = nav.currentPosition;
    position = Vector2(servicePos.dx, servicePos.dy);

    // Sync horizontal flip from velocity direction
    if (vel.dx.abs() > 0.5) {
      _direction = vel.dx > 0 ? 1.0 : -1.0;
      _updateFlip();
    }

    // --- Directional Walk & Deceleration Transitions ---
    final cur = current ?? PetAnimationState.idle;
    final isNavMoving = nav.isMoving;
    final isFsmOwned = _fsmOwnedAnimations.contains(cur);
    final canOverride = !isFsmOwned || _isMovementState(cur);

    if (canOverride) {
      if (isNavMoving || speed > 0.5) {
        if (speed > _runThreshold) {
          changeState(PetAnimationState.run);
        } else {
          // Dominant vector direction logic for 4-way selection
          PetAnimationState walkState = PetAnimationState.walkSide;
          if (vel.dy.abs() > vel.dx.abs()) {
            if (vel.dy < 0) {
              walkState = PetAnimationState.walkUp;
            } else {
              walkState = PetAnimationState.walkDown;
            }
          } else {
            walkState = PetAnimationState.walkSide;
          }
          changeState(walkState);
        }
      } else {
        // Deceleration Stride-Sync: Let the current walking cycle reach index 0 before going to idle
        if (_isMovementState(cur)) {
          final ticker = animationTickers?[cur];
          if (ticker == null || ticker.currentIndex == 0) {
            changeState(_previousState ?? PetAnimationState.idle);
          }
        }
      }
    }

    // --- Dynamic Leaning & Squash-and-Stretch for Vertical Movement ---
    final bool isMovingVertically = vel.dy.abs() > 1.5 && speed > 5.0;
    final bool isUsingFallbackWalk = current == PetAnimationState.walkSide;
    final profile = game.currentTheme.species.defaultProfile;

    if (isMovingVertically && (isUsingFallbackWalk || current == PetAnimationState.run || current == PetAnimationState.excited || current == PetAnimationState.fly)) {
      // 3D Tilt: Rotate sprite based on vertical speed and orientation
      final double maxSpeed = profile.movementSpeed;
      final double maxTilt = profile.maxTilt; // species specific tilt limit
      final double tiltFactor = (vel.dy / maxSpeed).clamp(-1.0, 1.0);
      angle = _direction * tiltFactor * maxTilt;

      // Squash and stretch vertical scaling based on vertical speed
      final double stretch = (vel.dy / 220.0).clamp(-0.12, 0.12);
      scale.y = scale.x.abs() * (1.0 - stretch);
    } else {
      angle = 0.0;
      // Idle breathing / celebration micro-bob
      if (current == PetAnimationState.idle || current == PetAnimationState.celebrate) {
        scale.y = scale.x.abs() * (1.0 + sin(_stateElapsed * 4.5) * profile.bobIntensity * 0.5);
      } else if (isMovingVertically && _isMovementState(current)) {
        final double bob = sin(_stateElapsed * 10.0) * profile.bobIntensity;
        scale.y = scale.x.abs() * (1.0 + bob);
      } else {
        scale.y = scale.x.abs();
      }
    }

    // --- Procedural Fire Particle Emitter for Dragon Snout ---
    _updateFireParticles(dt);
  }

  void _updateFireParticles(double dt) {
    // 1. Update and decay active particles
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.age += dt;
    }
    _particles.removeWhere((p) => p.age >= p.maxAge);

    // 2. Spawn new particles during Dragon's fire-breath state
    if (current == PetAnimationState.breatheFire) {
      final origin = _snoutOffset;
      for (int i = 0; i < 2; i++) {
        final double vx = _direction * (60.0 + _rng.nextDouble() * 50.0);
        final double vy = -15.0 + _rng.nextDouble() * 30.0;
        final colors = [
          const Color(0xFFFF3D00), // Pure Red-Orange
          const Color(0xFFFF9100), // Deep Orange
          const Color(0xFFFFD600), // Fire Yellow
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

  bool _isMovementState(PetAnimationState? s) =>
      s == PetAnimationState.walkUp ||
      s == PetAnimationState.walkDown ||
      s == PetAnimationState.walkSide ||
      s == PetAnimationState.run ||
      s == PetAnimationState.fly;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Render "ON AIR" / Meeting Indicator
    if (game.petService.context.isMeetingDetected) {
      final double spriteSize = game.currentTheme.spriteSize.toDouble();
      final Offset badgePos = Offset(spriteSize * 0.3, -spriteSize * 0.4);
      
      final paint = Paint()
        ..color = const Color(0xFFFF3B30)
        ..style = PaintingStyle.fill;
      
      // Draw a small pulsating red dot
      final double pulse = 1.0 + sin(_stateElapsed * 4.0) * 0.2;
      canvas.drawCircle(badgePos, 3.0 * pulse, paint);
      
      // Draw "ON AIR" text badge if space permits
      const textStyle = TextStyle(
        color: Colors.white,
        fontSize: 5,
        fontWeight: FontWeight.bold,
        fontFamily: 'Satoshi',
      );
      final textPainter = TextPainter(
        text: const TextSpan(text: 'ON AIR', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, badgePos + const Offset(5, -3));
    }

    // Render Dragon Snout Fire Particles procedurally over the sprite
    if (_particles.isNotEmpty) {
      final paint = Paint()..style = PaintingStyle.fill;
      for (final p in _particles) {
        final double ratio = (p.age / p.maxAge).clamp(0.0, 1.0);
        paint.color = p.color.withValues(alpha: 1.0 - ratio);
        canvas.drawCircle(
          p.position,
          p.size * (1.0 - 0.5 * ratio),
          paint,
        );
      }
    }
  }

  // --- Tap / Hover ---

  DateTime? _lastTapTime;

  @override
  void onTapDown(TapDownEvent event) {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      _lastTapTime = null;
      game.onUserInteraction('doubleTap');
    } else {
      _lastTapTime = now;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_lastTapTime != null) game.onUserInteraction('tap');
  }

  @override
  void onHoverEnter() => game.onUserInteraction('hover');

  // --- Mouse follow ---

  void updateMouseFollow(Map<dynamic, dynamic> data) {
    final bool enabled = data['enabled'] as bool? ?? false;
    game.petService.setCursorFollowing(enabled);

    final double? mx = (data['mouseX'] as num?)?.toDouble();
    final double? my = (data['mouseY'] as num?)?.toDouble();
    if (mx != null && my != null) {
      game.petService.updateCursorPosition(Offset(mx, my), forceFollowing: enabled);
    }

    if (!enabled) {
      angle = 0.0;
      scale.y = scale.x.abs();
      changeState(PetAnimationState.idle);
    }
  }
}
