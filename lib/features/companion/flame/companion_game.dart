import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/companion/data/cat_asset_loader.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/flame/companion_cat_component.dart';

class CompanionGame extends FlameGame {
  CatTheme currentTheme;

  /// User-facing scale multiplier override (1.0 = auto). When set to a value
  /// other than the sentinel 0.0, it overrides the auto-scale logic.
  double scaleOverride;

  CatAnimationState initialAnimationState;

  CompanionCatComponent? catComponent;

  CompanionGame({
    required this.currentTheme,
    this.scaleOverride = 0.0, // 0.0 = auto-scale
    this.initialAnimationState = CatAnimationState.idle,
  });

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadAndAttachCat();
  }

  /// Auto-scales so the cat occupies ~45% of the window height.
  /// Clamped to [3.0 – 10.0] so it is always comfortably visible.
  double _effectiveScale(double spriteSize) {
    if (scaleOverride > 0.0) return scaleOverride;
    final double target = size.y * 0.45;
    return (target / spriteSize).clamp(3.0, 10.0);
  }

  /// Loads assets for the current theme, creates the CatComponent, and adds it to the game.
  Future<void> _loadAndAttachCat() async {
    // 1. Remove existing component if present
    if (catComponent != null) {
      catComponent!.removeFromParent();
      catComponent = null;
    }

    // Wait one frame so remove() has been processed before we add a new component
    await Future<void>.delayed(Duration.zero);

    // 2. Load animations for the current theme
    final animations = await CatAssetLoader.loadAnimations(currentTheme);
    if (animations.isEmpty) return;

    // 3. Create the cat component with the sprite's native pixel size
    final double spriteSize = currentTheme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);

    catComponent = CompanionCatComponent(
      animations: animations,
      initialState: initialAnimationState,
    );

    // Size = native sprite pixels; scale makes it large on screen
    catComponent!.size = Vector2(spriteSize, spriteSize);
    catComponent!.scale = Vector2.all(scale);

    // Anchor is Anchor.center (set in constructor).
    // Position the cat: horizontally centred, bottom-aligned with a small gap.
    final double scaledHalfH = (spriteSize * scale) / 2;
    catComponent!.position = Vector2(
      size.x / 2,
      size.y - scaledHalfH - 4.0,
    );

    // 4. Add component to the scene
    add(catComponent!);
  }

  /// Dynamic runtime updater for changing cat themes (e.g. Grey -> Orange)
  Future<void> updateTheme(CatTheme newTheme) async {
    if (currentTheme.id == newTheme.id && catComponent != null) return;
    currentTheme = newTheme;
    await _loadAndAttachCat();
  }

  /// Dynamic runtime scale-override modifier (0 = revert to auto)
  void updateScale(double newScale) {
    if (scaleOverride == newScale) return;
    scaleOverride = newScale;
    _applyScale();
  }

  void _applyScale() {
    if (catComponent == null) return;
    final double spriteSize = currentTheme.spriteSize.toDouble();
    final double scale = _effectiveScale(spriteSize);
    catComponent!.scale = Vector2.all(scale);

    final double scaledHalfH = (spriteSize * scale) / 2;
    catComponent!.position = Vector2(
      catComponent!.position.x,
      size.y - scaledHalfH - 4.0,
    );
  }

  /// Triggers a dynamic behavioral animation state
  void triggerState(CatAnimationState state) {
    catComponent?.changeState(state);
  }

  /// Activates or silences wandering behaviour
  void setWanderingEnabled(bool enabled) {
    catComponent?.setWanderingEnabled(enabled);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (catComponent != null) {
      final double spriteSize = currentTheme.spriteSize.toDouble();
      final double scale = _effectiveScale(spriteSize);
      catComponent!.scale = Vector2.all(scale);

      // Keep the cat within the new bounds
      double newX = catComponent!.position.x.clamp(
        (spriteSize * scale) / 2,
        size.x - (spriteSize * scale) / 2,
      );

      final double scaledHalfH = (spriteSize * scale) / 2;
      catComponent!.position = Vector2(newX, size.y - scaledHalfH - 4.0);
    }
  }
}
