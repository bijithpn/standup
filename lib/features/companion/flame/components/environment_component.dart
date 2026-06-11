import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';

class EnvironmentComponent extends PositionComponent with HasGameReference<CompanionGame> {
  String backgroundImagePath;

  EnvironmentComponent({
    this.backgroundImagePath = 'assets/background/sky/background.png',
  });

  ui.Image? _skyImage;
  ui.Image? _groundImage;
  ui.Image? _cloudImage;

  final List<_Cloud> _clouds = [];
  final Random _rng = Random();

  Color ambientTint = Colors.white;

  Future<void> updateSkyImage(String newPath) async {
    backgroundImagePath = newPath;
    final cached = PetAssetLoader.getImageSync(newPath);
    if (cached != null) {
      _skyImage = cached;
      return;
    }
    try {
      final img = await PetAssetLoader.loadImage(newPath);
      _skyImage = img;
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _skyImage = await PetAssetLoader.loadImage(backgroundImagePath);
      _groundImage = await PetAssetLoader.loadImage('assets/tilesets/ground_2.png');
      _cloudImage = await PetAssetLoader.loadImage('assets/tilesets/cloud_2.png');
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    
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

  Color _getGroundTint() {
    final path = backgroundImagePath.toLowerCase();
    if (path.contains('autumn')) {
      return const Color(0xFFD47A3B); // Warm orange-brown for Autumn
    } else if (path.contains('winter')) {
      return const Color(0xFFE0F7FA); // Snow white/light-blue for Winter
    } else if (path.contains('beach')) {
      return const Color(0xFFFFE082); // Sandy yellow/beige for Beach
    } else if (path.contains('desert')) {
      return const Color(0xFFFFCC80); // Deep sand orange/yellow for Desert
    } else if (path.contains('cave')) {
      return const Color(0xFF424242); // Dark grey rock for Cave
    } else if (path.contains('urban')) {
      return const Color(0xFF757575); // Asphalt grey for Urban
    } else if (path.contains('night_town')) {
      return const Color(0xFF263238); // Dark blue-grey for Night Town
    } else if (path.contains('mist_forest')) {
      return const Color(0xFF90A4AE); // Misty grey-green for Mist Forest
    }
    return const Color(0xFFFFFFFF); // Default white (no custom tint)
  }

  Color _getCloudTint() {
    final path = backgroundImagePath.toLowerCase();
    if (path.contains('autumn')) {
      return const Color(0xFFFFECB3); // Warm cream for Autumn clouds
    } else if (path.contains('winter')) {
      return const Color(0xFFE0F2F1); // Ice blue/white for Winter clouds
    } else if (path.contains('beach')) {
      return const Color(0xFFFFFFFF); // Pure white for Beach clouds
    } else if (path.contains('desert')) {
      return const Color(0xFFFFF9C4); // Light warm yellow for Desert clouds
    } else if (path.contains('cave')) {
      return const Color(0xFF37474F).withValues(alpha: 0.3); // Faint dark smoke for Cave clouds
    } else if (path.contains('urban')) {
      return const Color(0xFFCFD8DC); // Greyish city smog/clouds
    } else if (path.contains('night_town')) {
      return const Color(0xFF37474F); // Dark purple-blue clouds
    } else if (path.contains('mist_forest')) {
      return const Color(0xFFB0BEC5); // Thick mist grey clouds
    }
    return const Color(0xFFFFFFFF); // Default white
  }

  @override
  void render(ui.Canvas canvas) {
    final size = game.size;
    final double worldWidth = game.isPiP ? size.x * 1.3 : size.x;

    
    if (_skyImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, worldWidth, size.y),
        image: _skyImage!,
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
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
      final cloudBaseTint = _getCloudTint();
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
      final groundBaseTint = _getGroundTint();
      final finalGroundTint = _combineTints(groundBaseTint, ambientTint);

      final paint = Paint()
        ..colorFilter = ColorFilter.mode(finalGroundTint, BlendMode.modulate)
        ..filterQuality = FilterQuality.none; 

      final double groundTileWidth = 48.0;
      final double groundTileHeight = 32.0;
      final double groundY = size.y - 52.0;

      
      final basePaint = Paint()
        ..color = const Color(0xFF2E2625).withValues(alpha: 0.95)
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
