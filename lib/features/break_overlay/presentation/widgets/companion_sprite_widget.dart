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
  bool _isLoading = false;
  String _currentLoadedPath = '';

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
        oldWidget.animationState != widget.animationState) {
      _loadAndSetup();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _frameIndexNotifier.dispose();
    _loadedImage?.dispose();
    super.dispose();
  }

  Future<void> _loadAndSetup() async {
    final path = _getAssetPath();
    if (path.isEmpty) return;

    if (path == _currentLoadedPath && _loadedImage != null) {
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
    } catch (e) {
      debugPrint('CompanionSpriteWidget: Error loading asset $path: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      // Dispose old image if it exists and is different
      if (_loadedImage != null && _loadedImage != img) {
        // We don't dispose here because PetAssetLoader might return the same image if it was cached locally (but it's not)
        // Actually, since we now instantiate every time in PetAssetLoader.loadImage, we SHOULD dispose.
        _loadedImage?.dispose();
      }
      setState(() {
        _loadedImage = img;
        _currentLoadedPath = path;
        _isLoading = false;
      });
      _setupTicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _loadedImage == null) {
      return SizedBox(
        width: widget.petTheme.spriteSize * widget.scale,
        height: widget.petTheme.spriteSize * widget.scale,
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
              size: Size(
                widget.petTheme.spriteSize * widget.scale,
                widget.petTheme.spriteSize * widget.scale,
              ),
              painter: _SpritePainter(
                image: _loadedImage!,
                spriteSize: widget.petTheme.spriteSize,
                row: row,
                frameIndex: frameIndex,
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
  final int row;
  final int frameIndex;

  _SpritePainter({
    required this.image,
    required this.spriteSize,
    required this.row,
    required this.frameIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcX = frameIndex * spriteSize;
    final srcY = row * spriteSize;

    final src = Rect.fromLTWH(
      srcX.toDouble(),
      srcY.toDouble(),
      spriteSize.toDouble(),
      spriteSize.toDouble(),
    );

    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    final paint = Paint()
      ..filterQuality = FilterQuality.none; // Pixel-perfect rendering style

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.spriteSize != spriteSize ||
        oldDelegate.row != row ||
        oldDelegate.frameIndex != frameIndex;
  }
}
