import 'dart:math' as math;
import 'package:breakmate/features/companion/domain/pet_animation.dart';

class ProceduralAnimationState {
  final double scaleX;
  final double scaleY;
  final double offsetY;
  final double eyeScaleY;
  final double bounceAmount;

  const ProceduralAnimationState({
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetY = 0.0,
    this.eyeScaleY = 1.0,
    this.bounceAmount = 0.0,
  });
}

/// Procedural animator generating lifelike subtle breathing, blink timers, and natural reactions
class PetProceduralAnimator {
  double _elapsed = 0.0;
  PetAnimation _animation = PetAnimation.idle;
  double _blinkTimer = 0.0;
  bool _isBlinking = false;
  double _bounceTimer = 0.0;
  final math.Random _rng = math.Random();

  PetAnimation get animation => _animation;

  ProceduralAnimationState get currentState {
    // Breathing sinusoidal curve (2.6s cycle)
    final breathPhase = (_elapsed % 2.6) / 2.6;
    final sinVal = math.sin(breathPhase * math.pi * 2.0);

    double scaleX = 1.0 + sinVal * 0.02;
    double scaleY = 1.0 - sinVal * 0.015;
    double offsetY = sinVal * 6.0;

    double bounce = 0.0;
    if (_animation == PetAnimation.happy || _bounceTimer > 0.0) {
      final bounceVal = math.sin(_elapsed * math.pi * 4.0).abs();
      offsetY -= bounceVal * 14.0;
      scaleX += bounceVal * 0.08;
      scaleY -= bounceVal * 0.06;
      bounce = bounceVal;
    } else if (_animation == PetAnimation.sleep) {
      offsetY = math.sin(_elapsed * math.pi) * 2.0;
      scaleX = 1.0 + math.sin(_elapsed * math.pi) * 0.01;
      scaleY = 1.0;
    }

    final eyeScale = _isBlinking ? 0.1 : 1.0;

    return ProceduralAnimationState(
      scaleX: scaleX,
      scaleY: scaleY,
      offsetY: offsetY,
      eyeScaleY: eyeScale,
      bounceAmount: bounce,
    );
  }

  void triggerBlink() {
    _isBlinking = true;
    _blinkTimer = 0.15; // 150ms blink
  }

  void playAnimation(PetAnimation animation) {
    _animation = animation;
    if (animation == PetAnimation.happy || animation == PetAnimation.jump) {
      _bounceTimer = 0.8;
    }
  }

  void update(double dt) {
    _elapsed += dt;

    if (_blinkTimer > 0.0) {
      _blinkTimer -= dt;
      if (_blinkTimer <= 0.0) {
        _isBlinking = false;
      }
    } else {
      // Random blink chance every ~3.5 seconds
      if (_rng.nextDouble() < dt * 0.3) {
        triggerBlink();
      }
    }

    if (_bounceTimer > 0.0) {
      _bounceTimer -= dt;
      if (_bounceTimer <= 0.0 && _animation != PetAnimation.happy) {
        _animation = PetAnimation.idle;
      }
    }
  }
}
