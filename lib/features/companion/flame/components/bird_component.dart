import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/flame/components/environment_component.dart';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';
import 'package:breakmate/core/errors/error_handler.dart';

class BirdComponent extends SpriteAnimationComponent
    with HasGameReference<CompanionGame> {
  static final _rng = Random();

  double _speed = 0.0;
  double _direction = 1.0; // 1.0 = right, -1.0 = left
  double _respawnTimer = 0.0;
  bool _active = false;

  BirdComponent() : super(anchor: Anchor.center, priority: -4);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final config = EnvironmentThemeConfig.getByPath(game.backgroundImagePath);
    final birdAsset = config.birdAsset;

    if (birdAsset.path.isEmpty || birdAsset.path == 'none') {
      removeFromParent();
      return;
    }

    try {
      final image = await PetAssetLoader.loadImage(birdAsset.path);
      final List<Sprite> sprites = [];

      if (birdAsset.isSpriteSheet) {
        for (int i = 0; i < birdAsset.frameCount; i++) {
          sprites.add(
            Sprite(
              image,
              srcPosition: Vector2(
                birdAsset.srcX + i * birdAsset.spriteWidth,
                birdAsset.srcY,
              ),
              srcSize: Vector2(birdAsset.spriteWidth, birdAsset.spriteHeight),
            ),
          );
        }
      } else {
        sprites.add(Sprite(image));
      }

      animation = SpriteAnimation.spriteList(
        sprites,
        stepTime: 0.08 + _rng.nextDouble() * 0.04,
      );

      size = Vector2(birdAsset.spriteWidth, birdAsset.spriteHeight);
      _resetBird();
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
      removeFromParent();
    }
  }

  void _resetBird() {
    _active = false;
    _respawnTimer = 5.0 + _rng.nextDouble() * 10.0; // 5 to 15 seconds delay
    position = Vector2(-100.0, -100.0);
  }

  void _spawnBird() {
    _active = true;
    _speed = 80.0 + _rng.nextDouble() * 70.0; // 80 to 150 px/s
    _direction = _rng.nextBool() ? 1.0 : -1.0;

    final worldWidth = game.isPiP ? game.size.x * 1.3 : game.size.x;
    final startX = _direction > 0 ? -40.0 : worldWidth + 40.0;
    // Spawns lower in the sky to remain visible below header/title bar
    final startY = 55.0 + _rng.nextDouble() * 45.0;

    position = Vector2(startX, startY);
    scale = Vector2(
      _direction * 0.75 * config.birdScale,
      0.75 * config.birdScale,
    ); // Flip horizontally if flying left and scale
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_active) {
      _respawnTimer -= dt;
      if (_respawnTimer <= 0.0) {
        _spawnBird();
      }
      return;
    }

    // Move bird
    position.x += _direction * _speed * dt;

    // Check if offscreen
    final worldWidth = game.isPiP ? game.size.x * 1.3 : game.size.x;
    if ((_direction > 0 && position.x > worldWidth + 60.0) ||
        (_direction < 0 && position.x < -60.0)) {
      _resetBird();
    }

    // Apply lighting modulation matching EnvironmentComponent
    EnvironmentComponent? env;
    if (game.world.children.whereType<EnvironmentComponent>().isNotEmpty) {
      env = game.world.children.whereType<EnvironmentComponent>().first;
    } else {
      for (final child in game.children) {
        if (child is PositionComponent &&
            child.children.whereType<EnvironmentComponent>().isNotEmpty) {
          env = child.children.whereType<EnvironmentComponent>().first;
          break;
        }
      }
    }

    if (env != null) {
      paint.colorFilter = ColorFilter.mode(env.ambientTint, BlendMode.modulate);
    }
  }
}
