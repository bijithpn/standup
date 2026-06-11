import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';

import 'environment_component.dart';

enum DecorationType { rock, mountain }

class DecorationComponent extends SpriteComponent with HasGameReference<CompanionGame> {
  static final _rng = Random();

  final DecorationType type;
  final ThemeAssetConfig assetConfig;
  final double xRatio; // Horizontal position ratio (0.0 to 1.0) of the screen width

  DecorationComponent({
    required this.type,
    required this.assetConfig,
    required this.xRatio,
  }) : super(
          anchor: Anchor.bottomCenter,
          priority: type == DecorationType.rock ? 1 : -5,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final image = await PetAssetLoader.loadImage(assetConfig.path);
    if (assetConfig.isSpriteSheet) {
      sprite = Sprite(
        image,
        srcPosition: Vector2(assetConfig.srcX, assetConfig.srcY),
        srcSize: Vector2(assetConfig.spriteWidth, assetConfig.spriteHeight),
      );
    } else {
      sprite = Sprite(image);
    }

    // Dynamic sizes and scaling based on type
    if (type == DecorationType.rock) {
      final double targetScale = 0.9 + _rng.nextDouble() * 0.4;
      size = Vector2(
        assetConfig.spriteWidth * targetScale,
        assetConfig.spriteHeight * targetScale,
      );
    } else {
      final double targetScale = 0.8 + _rng.nextDouble() * 0.4;
      size = Vector2(
        assetConfig.spriteWidth * targetScale,
        assetConfig.spriteHeight * targetScale,
      );
    }

    _updatePosition();
  }

  void _updatePosition() {
    final double groundY = game.isPiP ? (game.size.y - 52.0) : (game.size.y - 4.0);
    final double worldWidth = game.isPiP ? game.size.x * 1.3 : game.size.x;
    final double posX = worldWidth * xRatio;

    // Place background mountains slightly lower so they look integrated behind the tiles
    final double posY = type == DecorationType.mountain ? groundY + 8.0 : groundY + 2.0;

    position = Vector2(posX, posY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updatePosition();

    // Apply lighting modulation matching EnvironmentComponent
    EnvironmentComponent? env;
    if (game.world.children.whereType<EnvironmentComponent>().isNotEmpty) {
      env = game.world.children.whereType<EnvironmentComponent>().first;
    } else {
      for (final child in game.children) {
        if (child is PositionComponent && child.children.whereType<EnvironmentComponent>().isNotEmpty) {
          env = child.children.whereType<EnvironmentComponent>().first;
          break;
        }
      }
    }

    if (env != null) {
      // Tint objects to match the environment color scheme
      final tint = env.ambientTint;
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
  }
}
