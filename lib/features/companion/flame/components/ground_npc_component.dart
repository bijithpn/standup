import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/flame/components/environment_component.dart';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';
import 'package:breakmate/core/errors/error_handler.dart';

enum RabbitAnimState { idle, run }

class GroundNpcComponent extends SpriteAnimationComponent
    with HasGameReference<CompanionGame> {
  static final _rng = Random();

  late SpriteAnimation _idleAnimation;
  late SpriteAnimation _runAnimation;

  double _bottomPadding = 0.0;
  double _scaleFactor = 1.0;

  double _targetX = 0.0;
  double _speed = 0.0;
  double _waitTimer = 0.0;
  bool _isMoving = false;
  double _hopTime = 0.0;

  GroundNpcComponent() : super(anchor: Anchor.bottomCenter, priority: 2);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final config = EnvironmentThemeConfig.getByPath(game.backgroundImagePath);
    final idleAsset = config.rabbitIdleAsset;
    final runAsset = config.rabbitRunAsset;

    if (idleAsset.path.isEmpty ||
        idleAsset.path == 'none' ||
        runAsset.path.isEmpty ||
        runAsset.path == 'none') {
      removeFromParent();
      return;
    }

    try {
      final idleImage = await PetAssetLoader.loadImage(idleAsset.path);
      final runImage = await PetAssetLoader.loadImage(runAsset.path);

      // Build idle animation
      final List<Sprite> idleSprites = [];
      if (idleAsset.isSpriteSheet) {
        for (int i = 0; i < idleAsset.frameCount; i++) {
          idleSprites.add(
            Sprite(
              idleImage,
              srcPosition: Vector2(
                idleAsset.srcX + i * idleAsset.spriteWidth,
                idleAsset.srcY,
              ),
              srcSize: Vector2(idleAsset.spriteWidth, idleAsset.spriteHeight),
            ),
          );
        }
      } else {
        idleSprites.add(Sprite(idleImage));
      }
      _idleAnimation = SpriteAnimation.spriteList(idleSprites, stepTime: 0.1);

      // Build run animation
      final List<Sprite> runSprites = [];
      if (runAsset.isSpriteSheet) {
        for (int i = 0; i < runAsset.frameCount; i++) {
          runSprites.add(
            Sprite(
              runImage,
              srcPosition: Vector2(
                runAsset.srcX + i * runAsset.spriteWidth,
                runAsset.srcY,
              ),
              srcSize: Vector2(runAsset.spriteWidth, runAsset.spriteHeight),
            ),
          );
        }
      } else {
        runSprites.add(Sprite(runImage));
      }
      _runAnimation = SpriteAnimation.spriteList(runSprites, stepTime: 0.08);

      // Scan transparent bottom padding of the first frame
      final rect = Rect.fromLTWH(
        0,
        0,
        idleAsset.spriteWidth,
        idleAsset.spriteHeight,
      );
      _bottomPadding = await PetAssetLoader.computeImageRectBottomPadding(
        idleImage,
        rect,
      );

      // Determine scale: since ground npcs are smaller than cats/dogs, scale down to ~1.0
      _scaleFactor = (0.95 + _rng.nextDouble() * 0.15) * config.rabbitScale;
      scale = Vector2.all(_scaleFactor);
      size = Vector2(idleAsset.spriteWidth, idleAsset.spriteHeight);
      anchor = Anchor.bottomCenter;

      animation = _idleAnimation;

      final double worldWidth = game.isPiP ? game.size.x * 1.3 : game.size.x;
      final double startX = 30.0 + _rng.nextDouble() * (worldWidth - 60.0);

      final double targetGroundY = game.isPiP
          ? game.size.y - 20.0
          : game.size.y - 2.0;
      position = Vector2(
        startX,
        targetGroundY + (_bottomPadding * _scaleFactor),
      );
      _targetX = startX;

      _waitTimer = 1.0 + _rng.nextDouble() * 4.0;
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
      removeFromParent();
    }
  }

  void _changeState(RabbitAnimState newState) {
    if (newState == RabbitAnimState.idle) {
      animation = _idleAnimation;
      _isMoving = false;
      _hopTime = 0.0;
      _waitTimer = 2.0 + _rng.nextDouble() * 5.0; // Wait 2 to 7 seconds
    } else {
      animation = _runAnimation;
      _isMoving = true;
      _hopTime = 0.0;
      _speed = 40.0 + _rng.nextDouble() * 30.0; // 40 to 70 px/s
    }
  }

  void _selectNewWanderTarget() {
    final double worldWidth = game.isPiP ? game.size.x * 1.3 : game.size.x;
    _targetX = 20.0 + _rng.nextDouble() * (worldWidth - 40.0);
    _changeState(RabbitAnimState.run);
  }

  @override
  void update(double dt) {
    final double targetGroundY = game.isPiP
        ? game.size.y - 20.0
        : game.size.y - 2.0;

    double activeDt = dt;

    if (!_isMoving) {
      position.y = targetGroundY + (_bottomPadding * _scaleFactor);
      _waitTimer -= dt;
      if (_waitTimer <= 0.0) {
        _selectNewWanderTarget();
      }
    } else {
      _hopTime += dt * 8.0;
      final double sinVal = sin(_hopTime);
      final double hopHeight = 12.0;

      if (sinVal > 0) {
        final double hopOffset = sinVal * hopHeight;
        position.y = targetGroundY + (_bottomPadding * _scaleFactor) - hopOffset;

        final double direction = _targetX > position.x ? 1.0 : -1.0;
        position.x += direction * _speed * sinVal * 1.5 * dt;
      } else {
        position.y = targetGroundY + (_bottomPadding * _scaleFactor);
      }

      final double direction = _targetX > position.x ? 1.0 : -1.0;
      scale = Vector2(direction * _scaleFactor, _scaleFactor);

      if ((direction > 0 && position.x >= _targetX) ||
          (direction < 0 && position.x <= _targetX)) {
        position.x = _targetX;
        _changeState(RabbitAnimState.idle);
      }

      // Sync run animation speed to the hopping phase (faster in air, pauses on landing)
      activeDt = dt * (sinVal > 0 ? 1.2 : 0.2);
    }

    super.update(activeDt);

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
      final groundBaseTint = env.ambientTint;
      paint.colorFilter = ColorFilter.mode(groundBaseTint, BlendMode.modulate);
    }
  }
}
