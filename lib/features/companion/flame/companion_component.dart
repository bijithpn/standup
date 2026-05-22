import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/flame/companion_game.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';

class CompanionComponent extends SpriteAnimationGroupComponent<CatAnimationState>
    with HasGameReference<CompanionGame>, TapCallbacks, HoverCallbacks {

  double _direction = 1.0;
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

  bool get _isDog => game.currentTheme.isDog;

  double get _strideFrequency {
    final id = game.currentTheme.id;
    if (id == CatTheme.keyCorgi) return 1.95;
    if (id == CatTheme.keyHusky || id == CatTheme.keyCollie) return 1.0;
    if (_isDog) return 1.25;
    if (id == CatTheme.keyLargeCat) return 0.72;
    return 1.15;
  }

  @override
  void onMount() {
    super.onMount();
    // Set filter quality once — no need to set it every render call
    paint.filterQuality = FilterQuality.medium;
    _updateFlip();
  }

  /// Changes animation state safely.
  /// - Non-looping animations already in progress are NOT restarted.
  /// - Missing animations fall back to idle.
  void changeState(CatAnimationState newState, {bool force = false}) {
    // Fallback: if the requested state has no animation, use idle
    final target = (animations?.containsKey(newState) == true)
        ? newState
        : CatAnimationState.idle;

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

  @override
  void update(double dt) {
    // Scale animation speed for walk/excited to match stride rate
    final scaledDt = (current == CatAnimationState.walk || current == CatAnimationState.excited)
        ? dt * _strideFrequency
        : dt;
    super.update(scaledDt);

    _stateElapsed += dt;

    // Auto-revert non-looping animations back to previous (or idle)
    final currentAnim = animations?[current];
    if (currentAnim != null && !currentAnim.loop) {
      final ticker = animationTickers?[current];
      if (ticker != null && ticker.done()) {
        ticker.reset();
        changeState(_previousState ?? CatAnimationState.idle);
        return;
      }
    }

    // Sync position from navigation service
    final servicePos = game.petService.position;
    position = Vector2(servicePos.dx, servicePos.dy);

    // Sync horizontal flip from velocity direction
    final navVel = game.petService.navigation.velocity;
    if (navVel.dx.abs() > 0.5) {
      _direction = navVel.dx > 0 ? 1.0 : -1.0;
      _updateFlip();
    }

    // Dog idle bounce — cheap sin, only when idle/celebrate
    if (_isDog && (current == CatAnimationState.idle || current == CatAnimationState.celebrate)) {
      scale.y = scale.x.abs() * (1.0 + sin(_stateElapsed * 4.5) * 0.02);
    } else {
      scale.y = scale.x.abs();
    }

    angle = 0.0;
  }

  @override
  void render(Canvas canvas) {
    // No canvas.save/restore — they are no-ops here and add overhead.
    // FilterQuality is set once in onMount.
    super.render(canvas);
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

  /// Called with raw window-space mouse coordinates.
  /// The FlameGame canvas fills the window 1:1 in logical pixels, so no
  /// coordinate transform is needed — Flame's coordinate system already
  /// matches Flutter logical pixels. The sprite's visual scale does NOT
  /// affect the coordinate system; only position matters.
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
