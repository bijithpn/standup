import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/companion/domain/animation_row_config.dart';

class CompanionSpriteWidget extends StatefulWidget {
  final CatTheme catTheme;
  final CatAnimationState animationState;
  final double scale;
  final bool flipX;

  const CompanionSpriteWidget({
    super.key,
    required this.catTheme,
    required this.animationState,
    this.scale = 3.0,
    this.flipX = false,
  });

  @override
  State<CompanionSpriteWidget> createState() => _CompanionSpriteWidgetState();
}

class _CompanionSpriteWidgetState extends State<CompanionSpriteWidget>
    with SingleTickerProviderStateMixin {
  static final Map<String, ui.Image> _imageCache = {};

  late AnimationController _animationController;
  ui.Image? _loadedImage;
  bool _isLoading = false;
  String _currentLoadedPath = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _loadAndSetup();
  }

  @override
  void didUpdateWidget(covariant CompanionSpriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catTheme.id != widget.catTheme.id ||
        oldWidget.animationState != widget.animationState) {
      _loadAndSetup();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      final ui.Image img = await _loadImage(path);
      if (mounted) {
        setState(() {
          _loadedImage = img;
          _currentLoadedPath = path;
          _isLoading = false;
        });
        _setupTicker();
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

  String _getAssetPath() {
    final dynamic anim = widget.catTheme.animations[widget.animationState] ??
        widget.catTheme.animations[CatAnimationState.idle] ??
        widget.catTheme.animations.values.first;

    if (widget.catTheme.type == CatType.composite) {
      return widget.catTheme.basePath;
    } else {
      if (anim is SeparateAnimationConfig) {
        return '${widget.catTheme.basePath}${anim.fileName}';
      }
    }
    return '';
  }

  void _setupTicker() {
    final dynamic anim = widget.catTheme.animations[widget.animationState] ??
        widget.catTheme.animations[CatAnimationState.idle] ??
        widget.catTheme.animations.values.first;

    int frameCount = 1;
    double stepTime = 0.15;
    bool loop = true;

    if (widget.catTheme.type == CatType.composite) {
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
    _animationController.duration =
        Duration(milliseconds: (frameCount * stepTime * 1000).toInt());

    if (frameCount > 1) {
      if (loop) {
        _animationController.repeat();
      } else {
        _animationController.forward(from: 0.0);
      }
    } else {
      _animationController.value = 0.0;
    }
  }

  Future<ui.Image> _loadImage(String path) async {
    if (_imageCache.containsKey(path)) {
      return _imageCache[path]!;
    }
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _imageCache[path] = frame.image;
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _loadedImage == null) {
      return SizedBox(
        width: widget.catTheme.spriteSize * widget.scale,
        height: widget.catTheme.spriteSize * widget.scale,
      );
    }

    final dynamic anim = widget.catTheme.animations[widget.animationState] ??
        widget.catTheme.animations[CatAnimationState.idle] ??
        widget.catTheme.animations.values.first;

    int row = 0;
    int frameCount = 1;

    if (widget.catTheme.type == CatType.composite) {
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

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final int frameIndex = frameCount > 1
              ? (_animationController.value * frameCount).floor().clamp(0, frameCount - 1)
              : 0;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(widget.flipX ? -1.0 : 1.0, 1.0),
            child: CustomPaint(
              size: Size(
                widget.catTheme.spriteSize * widget.scale,
                widget.catTheme.spriteSize * widget.scale,
              ),
              painter: _SpritePainter(
                image: _loadedImage!,
                spriteSize: widget.catTheme.spriteSize,
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
