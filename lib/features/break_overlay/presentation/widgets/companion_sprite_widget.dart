import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/animation_row_config.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/features/companion/domain/environment_theme_config.dart';

class CompanionSpriteWidget extends StatefulWidget {
  final PetTheme petTheme;
  final PetAnimationState animationState;
  final double scale;
  final bool flipX;
  final bool isStatic;
  final String? backgroundImagePath;
  final Size? size;
  final double petYOffset;
  final double petXOffset;

  static void clearCache() {}

  static Future<void> precacheSpriteSheet(String path) async {
    try {
      await PetAssetLoader.loadImage(path);
    } catch (e) {
      debugPrint('CompanionSpriteWidget: Precache error for $path: $e');
    }
  }

  const CompanionSpriteWidget({
    super.key,
    required this.petTheme,
    required this.animationState,
    this.scale = 3.0,
    this.flipX = false,
    this.isStatic = false,
    this.backgroundImagePath,
    this.size,
    this.petYOffset = 0.0,
    this.petXOffset = 0.0,
  });

  @override
  State<CompanionSpriteWidget> createState() => _CompanionSpriteWidgetState();
}

class _CompanionSpriteWidgetState extends State<CompanionSpriteWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final ValueNotifier<int> _frameIndexNotifier = ValueNotifier<int>(0);
  int _lastFrameCount = 1;
  ui.Image? _loadedImage;
  ui.Image? _backgroundImage;
  ui.Image? _groundImage;
  ui.Image? _cloudImage;
  bool _isLoading = false;
  String _currentLoadedPath = '';
  String? _currentBackgroundPath;
  double _calculatedBottomPadding = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _animationController.addListener(() {
      final int frameIndex = _lastFrameCount > 1
          ? (_animationController.value * _lastFrameCount).floor().clamp(
               0,
               _lastFrameCount - 1,
             )
          : 0;
      if (_frameIndexNotifier.value != frameIndex) {
        _frameIndexNotifier.value = frameIndex;
      }
    });
    _loadAndSetup();
  }

  @override
  void didUpdateWidget(covariant CompanionSpriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petTheme.id != widget.petTheme.id ||
        oldWidget.animationState != widget.animationState ||
        oldWidget.backgroundImagePath != widget.backgroundImagePath) {
      _loadAndSetup();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _frameIndexNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadAndSetup() async {
    final path = _getAssetPath();
    if (path.isEmpty) return;

    if (path == _currentLoadedPath &&
        widget.backgroundImagePath == _currentBackgroundPath &&
        _loadedImage != null &&
        _groundImage != null &&
        _cloudImage != null) {
      _setupTicker();
      return;
    }

    final String bgPath = widget.backgroundImagePath ?? 'assets/environments/sky/sky_back.png';
    final config = EnvironmentThemeConfig.getByPath(bgPath);

    final cachedSprite = PetAssetLoader.getImageSync(path);
    final cachedBg = widget.backgroundImagePath != null
        ? PetAssetLoader.getImageSync(widget.backgroundImagePath!)
        : null;
    final cachedGround = PetAssetLoader.getImageSync(config.groundPath);
    final cachedCloud = PetAssetLoader.getImageSync(config.cloudPath);

    if (cachedSprite != null &&
        (widget.backgroundImagePath == null || cachedBg != null) &&
        cachedGround != null &&
        cachedCloud != null) {
      final double computedPadding = await _calculateImagePadding(cachedSprite);
      if (mounted) {
        setState(() {
          _loadedImage = cachedSprite;
          _currentLoadedPath = path;
          _backgroundImage = cachedBg;
          _currentBackgroundPath = widget.backgroundImagePath;
          _groundImage = cachedGround;
          _cloudImage = cachedCloud;
          _calculatedBottomPadding = computedPadding;
          _isLoading = false;
        });
        _setupTicker();
      }
      return;
    }

    if (_loadedImage == null && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        PetAssetLoader.loadImage(path),
        if (widget.backgroundImagePath != null)
          PetAssetLoader.loadImage(widget.backgroundImagePath!)
        else
          Future.value(null),
        PetAssetLoader.loadImage(config.groundPath),
        PetAssetLoader.loadImage(config.cloudPath),
      ]);

      final loadedSprite = results[0] as ui.Image;
      final double computedPadding = await _calculateImagePadding(loadedSprite);

      if (mounted) {
        setState(() {
          _loadedImage = loadedSprite;
          _currentLoadedPath = path;
          _backgroundImage = results[1];
          _currentBackgroundPath = widget.backgroundImagePath;
          _groundImage = results[2] as ui.Image;
          _cloudImage = results[3] as ui.Image;
          _calculatedBottomPadding = computedPadding;
          _isLoading = false;
        });
        _setupTicker();
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<double> _calculateImagePadding(ui.Image image) async {
    final dynamic anim =
        widget.petTheme.animations[widget.animationState] ??
        widget.petTheme.animations[PetAnimationState.idle] ??
        widget.petTheme.animations.values.first;

    int row = 0;
    int frameCount = 1;

    if (widget.petTheme.type == PetType.composite) {
      if (anim is AnimationRowConfig) {
        row = anim.row;
        frameCount = anim.frameCount;
      }
    } else {
      if (anim is SeparateAnimationConfig) {
        row = 0;
        frameCount = anim.frameCount;
      }
    }

    double frameWidth = widget.petTheme.spriteSize.toDouble();
    double frameHeight = widget.petTheme.spriteSize.toDouble();
    if (widget.petTheme.type != PetType.composite) {
      if (frameCount > 0) {
        frameWidth = image.width / frameCount;
      }
      frameHeight = image.height.toDouble();
    }

    double paddingSum = 0.0;
    int count = 0;
    for (int i = 0; i < frameCount; i++) {
      final rect = Rect.fromLTWH(
        i * frameWidth,
        row * frameHeight,
        frameWidth,
        frameHeight,
      );
      final p = await PetAssetLoader.computeImageRectBottomPadding(image, rect);
      paddingSum += p;
      count++;
    }
    return count > 0 ? (paddingSum / count) : 0.0;
  }

  String _getAssetPath() {
    final dynamic anim =
        widget.petTheme.animations[widget.animationState] ??
        widget.petTheme.animations[PetAnimationState.idle] ??
        widget.petTheme.animations.values.first;

    if (widget.petTheme.type == PetType.composite) {
      return widget.petTheme.basePath;
    } else {
      if (anim is SeparateAnimationConfig) {
        return '${widget.petTheme.basePath}${anim.fileName}';
      }
    }
    return '';
  }

  void _setupTicker() {
    final dynamic anim =
        widget.petTheme.animations[widget.animationState] ??
        widget.petTheme.animations[PetAnimationState.idle] ??
        widget.petTheme.animations.values.first;

    int frameCount = 1;
    double stepTime = 0.15;
    bool loop = true;

    if (widget.petTheme.type == PetType.composite) {
      if (anim is AnimationRowConfig) {
        frameCount = anim.frameCount;
        stepTime = anim.stepTime;
        loop = anim.loop;
      }
    } else {
      if (anim is SeparateAnimationConfig) {
        frameCount = anim.frameCount;
        stepTime = anim.stepTime;
        loop = anim.loop;
      }
    }

    _animationController.stop();
    _animationController.duration = Duration(
      milliseconds: (frameCount * stepTime * 1000).toInt(),
    );
    _lastFrameCount = frameCount;

    if (widget.isStatic) {
      _animationController.value = 0.0;
      _frameIndexNotifier.value = 0;
    } else if (frameCount > 1) {
      if (loop) {
        _animationController.repeat();
      } else {
        _animationController.forward(from: 0.0);
      }
    } else {
      _animationController.value = 0.0;
      _frameIndexNotifier.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double effectiveScale =
        widget.scale * (32.0 / widget.petTheme.spriteSize);

    final bool loading = _isLoading;
    if (_loadedImage == null || (loading && _backgroundImage == null)) {
      return SizedBox(
        width:
            (widget.size?.width) ??
            (widget.petTheme.spriteSize * effectiveScale),
        height:
            (widget.size?.height) ??
            (widget.petTheme.spriteSize * effectiveScale),
      );
    }

    final dynamic anim =
        widget.petTheme.animations[widget.animationState] ??
        widget.petTheme.animations[PetAnimationState.idle] ??
        widget.petTheme.animations.values.first;

    int row = 0;
    int frameCount = 1;

    if (widget.petTheme.type == PetType.composite) {
      if (anim is AnimationRowConfig) {
        row = anim.row;
        frameCount = anim.frameCount;
      }
    } else {
      if (anim is SeparateAnimationConfig) {
        row = 0;
        frameCount = anim.frameCount;
      }
    }

    _lastFrameCount = frameCount;

    // animations (e.g. jumps) are never squished.
    double frameWidth = widget.petTheme.spriteSize.toDouble();
    double frameHeight = widget.petTheme.spriteSize.toDouble();
    if (widget.petTheme.type != PetType.composite && _loadedImage != null) {
      if (frameCount > 0) {
        frameWidth = _loadedImage!.width / frameCount;
      }
      frameHeight = _loadedImage!.height.toDouble();
    }

    double finalPetYOffset = widget.petYOffset;
    if (finalPetYOffset == 0.0) {
      finalPetYOffset = _calculatedBottomPadding * effectiveScale;
    }

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _frameIndexNotifier,
        builder: (context, frameIndex, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              widget.flipX ? -1.0 : 1.0,
              1.0,
              1.0,
            ),
            child: CustomPaint(
              size:
                  widget.size ??
                  Size(
                    frameWidth * effectiveScale,
                    frameHeight * effectiveScale,
                  ),
              painter: _SpritePainter(
                image: _loadedImage!,
                spriteSize: widget.petTheme.spriteSize,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                row: row,
                frameIndex: frameIndex,
                backgroundImage: _backgroundImage,
                groundImage: _groundImage,
                cloudImage: _cloudImage,
                backgroundImagePath: widget.backgroundImagePath,
                scale: effectiveScale,
                petYOffset: finalPetYOffset,
                petXOffset: widget.petXOffset,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final int spriteSize;
  final double frameWidth;
  final double frameHeight;
  final int row;
  final int frameIndex;
  final ui.Image? backgroundImage;
  final ui.Image? groundImage;
  final ui.Image? cloudImage;
  final String? backgroundImagePath;
  final double scale;
  final double petYOffset;
  final double petXOffset;

  _SpritePainter({
    required this.image,
    required this.spriteSize,
    required this.frameWidth,
    required this.frameHeight,
    required this.row,
    required this.frameIndex,
    this.backgroundImage,
    this.groundImage,
    this.cloudImage,
    this.backgroundImagePath,
    required this.scale,
    this.petYOffset = 0.0,
    this.petXOffset = 0.0,
  });

  EnvironmentThemeConfig get config => EnvironmentThemeConfig.getByPath(backgroundImagePath ?? '');

  Color _getAmbientTint() {
    final now = DateTime.now();
    final double hour = now.hour + now.minute / 60.0;

    if (hour < 4.0) {
      return const Color(0xFF16182C);
    } else if (hour < 6.0) {
      final double t = (hour - 4.0) / 2.0;
      return Color.lerp(const Color(0xFF16182C), const Color(0xFFFF8A65), t)!;
    } else if (hour < 8.0) {
      final double t = (hour - 6.0) / 2.0;
      return Color.lerp(const Color(0xFFFF8A65), const Color(0xFFFFECB3), t)!;
    } else if (hour < 16.0) {
      return const Color(0xFFFFFFFF);
    } else if (hour < 18.0) {
      final double t = (hour - 16.0) / 2.0;
      return Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFE57373), t)!;
    } else if (hour < 20.0) {
      final double t = (hour - 18.0) / 2.0;
      return Color.lerp(const Color(0xFFE57373), const Color(0xFF3F3D56), t)!;
    } else {
      final double t = (hour - 20.0) / 4.0;
      return Color.lerp(const Color(0xFF3F3D56), const Color(0xFF16182C), t)!;
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
  void paint(Canvas canvas, Size size) {
    final tint = _getAmbientTint();

    final String path = backgroundImagePath ?? '';

    if (backgroundImage != null) {
      final isSkyOnly = path.toLowerCase().contains('sky');
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: backgroundImage!,
        fit: BoxFit.cover,
        alignment: isSkyOnly ? Alignment.topCenter : Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
        colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
      );
    }

    // Draw cloud if available
    if (cloudImage != null) {
      final cloudBaseTint = config.cloudTint;
      final finalCloudTint = _combineTints(
        cloudBaseTint.withValues(alpha: 0.45),
        tint,
      );
      final cloudPaint = Paint()
        ..colorFilter = ColorFilter.mode(finalCloudTint, BlendMode.modulate)
        ..filterQuality = FilterQuality.medium;

      final double cloudScale = 0.45;
      final double cw = cloudImage!.width * cloudScale;
      final double ch = cloudImage!.height * cloudScale;
      canvas.drawImageRect(
        cloudImage!,
        Rect.fromLTWH(0, 0, cloudImage!.width.toDouble(), cloudImage!.height.toDouble()),
        Rect.fromLTWH(size.width * 0.15, size.height * 0.12, cw, ch),
        cloudPaint,
      );
    }

    // Draw ground if available
    final double groundY = size.height - 20.0;
    if (groundImage != null) {
      final groundBaseTint = config.groundTint;
      final finalGroundTint = _combineTints(groundBaseTint, tint);

      final groundPaint = Paint()
        ..colorFilter = ColorFilter.mode(finalGroundTint, BlendMode.modulate)
        ..filterQuality = FilterQuality.none;

      final double groundTileWidth = 32.0;
      final double groundTileHeight = 22.0;

      // Draw the dirt base at the very bottom
      final basePaint = Paint()
        ..color = config.baseColor.withValues(alpha: 0.95)
        ..colorFilter = ColorFilter.mode(finalGroundTint, BlendMode.modulate);
      canvas.drawRect(
        Rect.fromLTWH(0, groundY + 8.0, size.width, size.height - groundY - 8.0),
        basePaint,
      );

      // Tiled ground
      double x = 0;
      while (x < size.width + groundTileWidth) {
        canvas.drawImageRect(
          groundImage!,
          Rect.fromLTWH(0, 0, groundImage!.width.toDouble(), groundImage!.height.toDouble()),
          Rect.fromLTWH(x, groundY, groundTileWidth, groundTileHeight),
          groundPaint,
        );
        x += groundTileWidth;
      }
    }

    // Draw pet
    final double srcX = frameIndex * frameWidth;
    final double srcY = row * frameHeight;

    final src = Rect.fromLTWH(srcX, srcY, frameWidth, frameHeight);

    double drawWidth = frameWidth * scale;
    double drawHeight = frameHeight * scale;

    // If drawing dimensions exceed the widget's canvas size, scale down to fit.
    if (drawWidth > size.width || drawHeight > size.height) {
      final double fitScale = (size.width / drawWidth) < (size.height / drawHeight)
          ? (size.width / drawWidth)
          : (size.height / drawHeight);
      const double paddingFactor = 0.9;
      drawWidth *= fitScale * paddingFactor;
      drawHeight *= fitScale * paddingFactor;
    }

    // Align pet's feet to groundY
    final dst = Rect.fromLTWH(
      (size.width - drawWidth) / 2 + petXOffset,
      groundY - drawHeight + petYOffset,
      drawWidth,
      drawHeight,
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.none; // Pixel-perfect rendering style

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.spriteSize != spriteSize ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.row != row ||
        oldDelegate.frameIndex != frameIndex ||
        oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.groundImage != groundImage ||
        oldDelegate.cloudImage != cloudImage ||
        oldDelegate.backgroundImagePath != backgroundImagePath ||
        oldDelegate.scale != scale ||
        oldDelegate.petYOffset != petYOffset ||
        oldDelegate.petXOffset != petXOffset;
  }
}
