import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/flame/companion_game.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';

/// Generic companion component that works for any pet type (cat, dog, etc.).
/// The active [CatTheme] determines breed-specific physics and behavior.
class CompanionComponent extends SpriteAnimationGroupComponent<CatAnimationState>
    with HasGameReference<CompanionGame>, TapCallbacks, HoverCallbacks {
  // Movement velocities
  double _direction = 1.0; // 1.0 = Right, -1.0 = Left

  // State machine & timing
  double _stateElapsed = 0.0;
  CatAnimationState? _previousState;

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

  @override
  void onMount() {
    super.onMount();
    _updateFlip();
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
    _updateFlip();
  }

  /// Sets whether the companion is allowed to wander randomly.
  void setWanderingEnabled(bool enabled) {
    game.petService.navigation.setWanderingEnabled(enabled);
  }

  /// Flips the sprite horizontally based on movement direction.
  void _updateFlip() {
    if (_direction < 0) {
      if (scale.x > 0) scale.x = -scale.x.abs();
    } else {
      if (scale.x < 0) scale.x = scale.x.abs();
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
        return;
      }
    }

    // Synchronize position from PetCompanionService
    final servicePos = game.petService.position;
    position = Vector2(servicePos.dx, servicePos.dy);

    // Synchronize flip based on navigation velocity
    final navVelocity = game.petService.navigation.velocity;
    if (navVelocity.dx != 0) {
      _direction = navVelocity.dx > 0 ? 1.0 : -1.0;
      _updateFlip();
    }

    // Dog-specific tail-wag body pant bounce during idle/celebrate
    if (_isDog) {
      if (current == CatAnimationState.idle || current == CatAnimationState.celebrate) {
        final double bounce = sin(_stateElapsed * 4.5) * 0.02;
        scale.y = scale.x.abs() * (1.0 + bounce);
      } else {
        scale.y = scale.x.abs();
      }
    } else {
      scale.y = scale.x.abs();
    }

    angle = 0.0;
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
    game.onUserInteraction('tap');
  }

  @override
  void onTapUp(TapUpEvent event) {
    game.onUserInteraction('doubleTap');
  }

  @override
  void onHoverEnter() {
    game.onUserInteraction('hover');
  }

  @override
  void onHoverExit() {
    // Optional: we can add an interaction or just let the state machine revert naturally
  }

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
      changeState(CatAnimationState.idle);
    }
  }
}
