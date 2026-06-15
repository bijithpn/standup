import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';

class ThrowableToyComponent extends PositionComponent
    with HasGameReference<CompanionGame> {
  final PhysicsEntityId physicsId;
  final String kind;
  final String type;
  final Offset spawnOrigin;

  ThrowableToyComponent({
    required this.physicsId,
    required this.kind,
    required this.type,
    required this.spawnOrigin,
  }) : super(anchor: Anchor.center);

  final Paint _paint = Paint();
  ThemeAssetConfig? _assetConfig;
  ui.Image? _image;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final double baseSize = game.isPiP ? 10.0 : 20.0;
    size = Vector2(baseSize, baseSize);

    final config = EnvironmentThemeConfig.getByPath(game.backgroundImagePath);
    if (kind == 'treat') {
      _assetConfig = config.foodAssets[type];
    } else {
      _assetConfig = config.toyAssets[type] ?? config.foodAssets[type];
    }

    if (_assetConfig != null) {
      try {
        _image = await PetAssetLoader.loadImage(_assetConfig!.path);
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    final snapshots = game.throwableManager.snapshots();
    final toyState = snapshots.firstWhere(
      (t) => t.id == physicsId,
      orElse: () => ThrowableObjectState(
        id: physicsId,
        spawnPriority: 0,
        spawnOrigin: spawnOrigin,
        physicsId: physicsId,
        lifecycle: ThrowableLifecycle.flying,
        stationaryTickCount: 0,
        kind: kind,
        position: position.toOffset(),
      ),
    );

    final isBeingFetched =
        toyState.lifecycle == ThrowableLifecycle.beingFetched;

    if (isBeingFetched) {
      final pet = game.petComponent;
      if (pet != null) {
        final snout =
            pet.position +
            Vector2(
              pet.scale.x * (pet.size.x * 0.35),
              pet.scale.y.abs() * (-pet.size.y * 0.12),
            );
        position = snout;
      }
      angle = 0.0;
    } else {
      PhysicsEntityState? state;
      try {
        state = game.physicsSimulator.getState(physicsId);
        position = Vector2(state.x, state.y);
        size = Vector2(state.width, state.height);
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }

      if (state != null) {
        if (state.isAirborne) {
          final double speed = sqrt(state.vx * state.vx + state.vy * state.vy);
          angle += speed * 0.015 * dt;
        } else {
          angle = 0.0;
        }
      }
    }

    final tint = game.environmentTint;
    _paint.colorFilter = ColorFilter.mode(
      Color.lerp(Colors.white, tint, 0.45)!,
      BlendMode.modulate,
    );
  }

  @override
  void render(ui.Canvas canvas) {
    final snapshots = game.throwableManager.snapshots();
    final toyState = snapshots.firstWhere(
      (t) => t.id == physicsId,
      orElse: () => ThrowableObjectState(
        id: physicsId,
        spawnPriority: 0,
        spawnOrigin: spawnOrigin,
        physicsId: physicsId,
        lifecycle: ThrowableLifecycle.flying,
        stationaryTickCount: 0,
        kind: kind,
        position: position.toOffset(),
      ),
    );

    final isBeingFetched =
        toyState.lifecycle == ThrowableLifecycle.beingFetched;

    if (!isBeingFetched) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0.0, size.y * 0.45),
          width: size.x * 0.7,
          height: size.y * 0.2,
        ),
        shadowPaint,
      );
    }

    final destRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    final paintImage = Paint()
      ..color = Colors.white
      ..filterQuality = FilterQuality.medium
      ..colorFilter = _paint.colorFilter;

    if (kind == 'treat') {
      _drawTreat(canvas, destRect, paintImage);
    } else {
      _drawToy(canvas, destRect, paintImage);
    }
  }

  void _drawToy(ui.Canvas canvas, Rect destRect, Paint paint) {
    if (_image != null && _assetConfig != null) {
      if (_assetConfig!.isSpriteSheet) {
        canvas.drawImageRect(
          _image!,
          Rect.fromLTWH(
            _assetConfig!.srcX,
            _assetConfig!.srcY,
            _assetConfig!.spriteWidth,
            _assetConfig!.spriteHeight,
          ),
          destRect,
          paint,
        );
      } else {
        canvas.drawImageRect(
          _image!,
          Rect.fromLTWH(
            0,
            0,
            _image!.width.toDouble(),
            _image!.height.toDouble(),
          ),
          destRect,
          paint,
        );
      }
    } else if (type == 'toy_mouse' && game.mouseImage != null) {
      canvas.drawImageRect(
        game.mouseImage!,
        const Rect.fromLTWH(0, 0, 32, 32),
        destRect,
        paint,
      );
    } else if (type == 'pink_yarn' && game.pinkBallImage != null) {
      canvas.drawImageRect(
        game.pinkBallImage!,
        const Rect.fromLTWH(0, 0, 15, 16),
        destRect,
        paint,
      );
    } else if (type == 'orange_yarn' && game.orangeBallImage != null) {
      canvas.drawImageRect(
        game.orangeBallImage!,
        const Rect.fromLTWH(0, 0, 15, 16),
        destRect,
        paint,
      );
    } else if (type == 'tennis_ball' && game.blueBallImage != null) {
      canvas.drawImageRect(
        game.blueBallImage!,
        Rect.fromLTWH(
          0,
          0,
          game.blueBallImage!.width.toDouble(),
          game.blueBallImage!.height.toDouble(),
        ),
        destRect,
        paint,
      );
    } else if (type == 'base_ball' && game.baseballImage != null) {
      canvas.drawImageRect(
        game.baseballImage!,
        Rect.fromLTWH(
          0,
          0,
          game.baseballImage!.width.toDouble(),
          game.baseballImage!.height.toDouble(),
        ),
        destRect,
        paint,
      );
    } else if (type == 'basket_ball' && game.basketballImage != null) {
      canvas.drawImageRect(
        game.basketballImage!,
        Rect.fromLTWH(
          0,
          0,
          game.basketballImage!.width.toDouble(),
          game.basketballImage!.height.toDouble(),
        ),
        destRect,
        paint,
      );
    } else if (type == 'sushi') {
      _drawSushiVector(canvas);
    } else if (type == 'carrot' && game.bunnyFoodsImage != null) {
      canvas.drawImageRect(
        game.bunnyFoodsImage!,
        const Rect.fromLTWH(0, 0, 16, 16),
        destRect,
        paint,
      );
    } else if (type == 'bone' && game.dogItemsImage != null) {
      canvas.drawImageRect(
        game.dogItemsImage!,
        const Rect.fromLTWH(0, 0, 32, 32),
        destRect,
        paint,
      );
    } else {
      _drawTennisBallVector(canvas);
    }
  }

  void _drawTreat(ui.Canvas canvas, Rect destRect, Paint paint) {
    if (_image != null && _assetConfig != null) {
      if (_assetConfig!.isSpriteSheet) {
        canvas.drawImageRect(
          _image!,
          Rect.fromLTWH(
            _assetConfig!.srcX,
            _assetConfig!.srcY,
            _assetConfig!.spriteWidth,
            _assetConfig!.spriteHeight,
          ),
          destRect,
          paint,
        );
      } else {
        canvas.drawImageRect(
          _image!,
          Rect.fromLTWH(
            0,
            0,
            _image!.width.toDouble(),
            _image!.height.toDouble(),
          ),
          destRect,
          paint,
        );
      }
    } else if (type == 'carrot' && game.bunnyFoodsImage != null) {
      canvas.drawImageRect(
        game.bunnyFoodsImage!,
        const Rect.fromLTWH(0, 0, 16, 16),
        destRect,
        paint,
      );
    } else if (type == 'bone' && game.dogItemsImage != null) {
      canvas.drawImageRect(
        game.dogItemsImage!,
        const Rect.fromLTWH(0, 0, 32, 32),
        destRect,
        paint,
      );
    } else {
      _drawSushiVector(canvas);
    }
  }

  void _drawTennisBallVector(ui.Canvas canvas) {
    final double radius = size.x / 2;
    final ballPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-radius * 0.3, -radius * 0.3),
        radius,
        [
          const Color(0xFFE6FF55),
          const Color(0xFF9EBF00),
          const Color(0xFF5D7300),
        ],
        [0.0, 0.7, 1.0],
      )
      ..style = PaintingStyle.fill
      ..colorFilter = _paint.colorFilter;
    canvas.drawCircle(Offset.zero, radius, ballPaint);

    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.5, radius * 0.1)
      ..isAntiAlias = true
      ..colorFilter = _paint.colorFilter;

    final path1 = Path();
    path1.addArc(
      Rect.fromCircle(center: Offset(-radius, 0), radius: radius),
      -pi / 3,
      2 * pi / 3,
    );
    canvas.drawPath(path1, seamPaint);

    final path2 = Path();
    path2.addArc(
      Rect.fromCircle(center: Offset(radius, 0), radius: radius),
      2 * pi / 3,
      2 * pi / 3,
    );
    canvas.drawPath(path2, seamPaint);
  }

  void _drawSushiVector(ui.Canvas canvas) {
    final double radius = size.x / 2;
    final noriPaint = Paint()
      ..color = const Color(0xFF1B2421)
      ..style = PaintingStyle.fill
      ..colorFilter = _paint.colorFilter;
    canvas.drawCircle(Offset.zero, radius, noriPaint);

    final ricePaint = Paint()
      ..color = const Color(0xFFF5F5F0)
      ..style = PaintingStyle.fill
      ..colorFilter = _paint.colorFilter;
    canvas.drawCircle(Offset.zero, radius * 0.75, ricePaint);

    final salmonPaint = Paint()
      ..color = const Color(0xFFFF5C5C)
      ..style = PaintingStyle.fill
      ..colorFilter = _paint.colorFilter;
    canvas.drawCircle(
      Offset(-radius * 0.15, -radius * 0.05),
      radius * 0.35,
      salmonPaint,
    );

    final avocadoPaint = Paint()
      ..color = const Color(0xFF7CB342)
      ..style = PaintingStyle.fill
      ..colorFilter = _paint.colorFilter;
    canvas.drawCircle(
      Offset(radius * 0.2, radius * 0.15),
      radius * 0.2,
      avocadoPaint,
    );
  }
}
