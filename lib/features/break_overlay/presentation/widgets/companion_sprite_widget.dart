import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/animation_row_config.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';

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

  static void clearCache() {
    // PetAssetLoader handles the byte cache now
  }

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
  bool _isLoading = false;
  String _currentLoadedPath = '';
  String? _currentBackgroundPath;

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
        _loadedImage != null &&
        widget.backgroundImagePath == _currentBackgroundPath) {
      _setupTicker();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _loadImage(path);
      if (widget.backgroundImagePath != null &&
          widget.backgroundImagePath != _currentBackgroundPath) {
        await _loadBackground(widget.backgroundImagePath!);
      } else if (widget.backgroundImagePath == null &&
          _backgroundImage != null) {
        _backgroundImage = null;
        _currentBackgroundPath = null;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('CompanionSpriteWidget: Error loading asset $path: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBackground(String path) async {
    try {
      final ui.Image bg = await PetAssetLoader.loadImage(path);
      if (mounted) {
        setState(() {
          _backgroundImage = bg;
          _currentBackgroundPath = path;
        });
      }
    } catch (e) {
      debugPrint('CompanionSpriteWidget: Error loading background $path: $e');
    }
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

  Future<void> _loadImage(String path) async {
    final ui.Image img = await PetAssetLoader.loadImage(path);
    if (mounted) {
      // Do not dispose the old image as it is cached in PetAssetLoader._imageCache
      setState(() {
        _loadedImage = img;
        _currentLoadedPath = path;
      });
      _setupTicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Normalize all sprite sizes to the 32x32 baseline visual size to ensure consistency with game rendering
    final double effectiveScale =
        widget.scale * (32.0 / widget.petTheme.spriteSize);

    if (_isLoading || _loadedImage == null) {
      return SizedBox(
        width: (widget.size?.width) ?? (widget.petTheme.spriteSize * effectiveScale),
        height: (widget.size?.height) ?? (widget.petTheme.spriteSize * effectiveScale),
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

    // ── Aspect-ratio-correct frame dimensions ────────────────────────────────
    // For separate-image pets (one PNG per animation) the image is a horizontal
    // strip: width = frameCount * frameWidth, height = frameHeight.  Use the
    // actual pixel dimensions rather than the square spriteSize so tall or wide
    // animations (e.g. jumps) are never squished.
    double frameWidth = widget.petTheme.spriteSize.toDouble();
    double frameHeight = widget.petTheme.spriteSize.toDouble();
    if (widget.petTheme.type != PetType.composite && _loadedImage != null) {
      if (frameCount > 0) {
        frameWidth = _loadedImage!.width / frameCount;
      }
      frameHeight = _loadedImage!.height.toDouble();
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
              size: widget.size ??
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
                scale: effectiveScale,
                petYOffset: widget.petYOffset,
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
    required this.scale,
    this.petYOffset = 0.0,
    this.petXOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: backgroundImage!,
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter, // Keep floor visible
        filterQuality: FilterQuality.none,
      );
    }

    final double srcX = frameIndex * frameWidth;
    final double srcY = row * frameHeight;

    final src = Rect.fromLTWH(srcX, srcY, frameWidth, frameHeight);

    // Calculate actual pixel size based on scale
    final double drawWidth = frameWidth * scale;
    final double drawHeight = frameHeight * scale;

    // Position the pet at the bottom of the available space, centered horizontally, with offsets
    final dst = Rect.fromLTWH(
      (size.width - drawWidth) / 2 + petXOffset,
      size.height - drawHeight + petYOffset,
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
        oldDelegate.scale != scale ||
        oldDelegate.petYOffset != petYOffset ||
        oldDelegate.petXOffset != petXOffset;
  }
}
