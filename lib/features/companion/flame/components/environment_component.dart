import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';

class EnvironmentComponent extends PositionComponent with HasGameReference<CompanionGame> {
  String backgroundImagePath;

  EnvironmentComponent({
    this.backgroundImagePath = 'assets/environments/sky/sky_back.png',
  });

  ui.Image? _skyImage;
  ui.Image? _groundImage;
  ui.Image? _cloudImage;

  final List<_Cloud> _clouds = [];
  final Random _rng = Random();

  Color ambientTint = Colors.white;

  EnvironmentThemeConfig get config => EnvironmentThemeConfig.getByPath(backgroundImagePath);

  Future<void> updateTheme(String newPath) async {
    backgroundImagePath = newPath;
    final cfg = EnvironmentThemeConfig.getByPath(newPath);
    try {
      _skyImage = await PetAssetLoader.loadImage(cfg.skyPath);
      _groundImage = await PetAssetLoader.loadImage(cfg.groundPath);
      _cloudImage = await PetAssetLoader.loadImage(cfg.cloudPath);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> updateSkyImage(String newPath) async {
    await updateTheme(newPath);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await updateTheme(backgroundImagePath);

    if (_cloudImage != null) {
      for (int i = 0; i < 4; i++) {
        _clouds.add(_Cloud(
          x: _rng.nextDouble() * 400.0,
          y: 20.0 + _rng.nextDouble() * 50.0,
          speed: 6.0 + _rng.nextDouble() * 12.0,
          scale: 0.4 + _rng.nextDouble() * 0.5,
          opacity: 0.25 + _rng.nextDouble() * 0.45,
        ));
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateDayNightCycle();

    final double worldWidth = game.isPiP ? game.size.x * 1.3 : game.size.x;
    for (final cloud in _clouds) {
      cloud.x -= cloud.speed * dt;
      if (cloud.x < -80.0) {
        cloud.x = worldWidth + 20.0;
        cloud.y = 20.0 + _rng.nextDouble() * 50.0;
        cloud.speed = 6.0 + _rng.nextDouble() * 12.0;
        cloud.scale = 0.4 + _rng.nextDouble() * 0.5;
        cloud.opacity = 0.25 + _rng.nextDouble() * 0.45;
      }
    }
  }

  void _updateDayNightCycle() {
    final now = DateTime.now();
    final double hour = now.hour + now.minute / 60.0;

    if (hour < 4.0) {
      ambientTint = const Color(0xFF16182C); 
    } else if (hour < 6.0) {
      final double t = (hour - 4.0) / 2.0;
      ambientTint = Color.lerp(const Color(0xFF16182C), const Color(0xFFFF8A65), t)!; 
    } else if (hour < 8.0) {
      final double t = (hour - 6.0) / 2.0;
      ambientTint = Color.lerp(const Color(0xFFFF8A65), const Color(0xFFFFECB3), t)!; 
    } else if (hour < 16.0) {
      ambientTint = const Color(0xFFFFFFFF); 
    } else if (hour < 18.0) {
      final double t = (hour - 16.0) / 2.0;
      ambientTint = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFE57373), t)!; 
    } else if (hour < 20.0) {
      final double t = (hour - 18.0) / 2.0;
      ambientTint = Color.lerp(const Color(0xFFE57373), const Color(0xFF3F3D56), t)!; 
    } else {
      final double t = (hour - 20.0) / 4.0;
      ambientTint = Color.lerp(const Color(0xFF3F3D56), const Color(0xFF16182C), t)!; 
    }
  }

  Color _combineTints(Color baseTint, Color ambient) {
    final double r = baseTint.r * ambient.r;
    final double g = baseTint.g * ambient.g;
    final double b = baseTint.b * ambient.b;
    final double a = baseTint.a * ambient.a;
    return Color.fromARGB(
      (a * 255.0).round().clamp(0, 255),
      (r * 255.0).round().clamp(0, 255),
      (g * 255.0).round().clamp(0, 255),
      (b * 255.0).round().clamp(0, 255),
    );
  }

  @override
  void render(ui.Canvas canvas) {
    final size = game.size;
    final double worldWidth = game.isPiP ? size.x * 1.3 : size.x;

    if (_skyImage != null) {
      final isSkyOnly = backgroundImagePath.toLowerCase().contains('sky');
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, worldWidth, size.y),
        image: _skyImage!,
        fit: BoxFit.cover,
        alignment: isSkyOnly ? Alignment.topCenter : Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
        colorFilter: ColorFilter.mode(ambientTint, BlendMode.modulate),
      );
    } else {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.y),
          [ambientTint.withValues(alpha: 0.85), ambientTint],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, worldWidth, size.y), paint);
    }

    if (_cloudImage != null) {
      final cloudBaseTint = config.cloudTint;
      for (final cloud in _clouds) {
        final finalCloudTint = _combineTints(
          cloudBaseTint.withValues(alpha: cloud.opacity),
          ambientTint,
        );
        final paint = Paint()
          ..colorFilter = ColorFilter.mode(
            finalCloudTint,
            BlendMode.modulate,
          )
          ..filterQuality = FilterQuality.medium;

        final double cw = _cloudImage!.width * cloud.scale;
        final double ch = _cloudImage!.height * cloud.scale;

        canvas.drawImageRect(
          _cloudImage!,
          Rect.fromLTWH(0, 0, _cloudImage!.width.toDouble(), _cloudImage!.height.toDouble()),
          Rect.fromLTWH(cloud.x, cloud.y, cw, ch),
          paint,
        );
      }
    }

    if (_groundImage != null) {
      final groundBaseTint = config.groundTint;
      final finalGroundTint = _combineTints(groundBaseTint, ambientTint);

      final paint = Paint()
        ..colorFilter = ColorFilter.mode(finalGroundTint, BlendMode.modulate)
        ..filterQuality = FilterQuality.none; 

      final double groundTileWidth = 48.0;
      final double groundTileHeight = 32.0;
      final double groundY = size.y - 52.0;

      final basePaint = Paint()
        ..color = config.baseColor.withValues(alpha: 0.95)
        ..colorFilter = ColorFilter.mode(finalGroundTint, BlendMode.modulate);
      canvas.drawRect(Rect.fromLTWH(0, groundY + 12.0, worldWidth, size.y - groundY - 12.0), basePaint);

      double x = 0;
      while (x < worldWidth + groundTileWidth) {
        canvas.drawImageRect(
          _groundImage!,
          Rect.fromLTWH(0, 0, _groundImage!.width.toDouble(), _groundImage!.height.toDouble()),
          Rect.fromLTWH(x, groundY, groundTileWidth, groundTileHeight),
          paint,
        );
        x += groundTileWidth;
      }
    }
  }
}

class _Cloud {
  double x;
  double y;
  double speed;
  double scale;
  double opacity;

  _Cloud({
    required this.x,
    required this.y,
    required this.speed,
    required this.scale,
    required this.opacity,
  });
}
