import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/domain/custom_environment_layer.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'environment_component.dart';

class CustomLayerComponent extends SpriteComponent
    with HasGameReference<CompanionGame> {
  final CustomEnvironmentLayer layer;

  CustomLayerComponent({required this.layer, required int priorityIndex})
    : super(anchor: Anchor.bottomCenter, priority: -8 + priorityIndex);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final image = await PetAssetLoader.loadImage(layer.assetPath);
      sprite = Sprite(image);

      size = Vector2(image.width.toDouble(), image.height.toDouble());
      scale = Vector2(layer.scale * (layer.flipX ? -1 : 1), layer.scale);

      _updatePosition();
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
      removeFromParent();
    }
  }

  void _updatePosition() {
    final double groundY = game.isPiP
        ? (game.size.y - 32.0)
        : (game.size.y - 4.0);
    final double worldWidth = game.isPiP ? game.size.x * 1.3 : game.size.x;

    final double posX = worldWidth * layer.xRatio;
    final double posY = groundY - (layer.yRatio * groundY);

    position = Vector2(posX, posY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updatePosition();

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
      final tint = env.ambientTint;
      paint.colorFilter = ColorFilter.mode(
        tint.withValues(alpha: layer.opacity),
        BlendMode.modulate,
      );
    }
  }
}
