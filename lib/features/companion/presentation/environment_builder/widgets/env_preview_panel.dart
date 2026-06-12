import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

import 'package:breakmate/features/companion/domain/custom_environment_layer.dart';

// Displays a live miniature environment preview from the current draft.
// Renders sky, animated clouds, tiled ground, base fill and decorative
// foreground in a 16:9-ish panel at reduced scale.
class EnvPreviewPanel extends StatefulWidget {
  final CustomEnvironmentTheme theme;

  const EnvPreviewPanel({super.key, required this.theme});

  @override
  State<EnvPreviewPanel> createState() => _EnvPreviewPanelState();
}

class _EnvPreviewPanelState extends State<EnvPreviewPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;

  ui.Image? _skyImage;
  ui.Image? _groundImage;
  ui.Image? _cloudImage;
  ui.Image? _mountainImage;
  ui.Image? _rockImage;

  String? _loadedSky;
  String? _loadedGround;
  String? _loadedCloud;
  String? _loadedMountain;
  String? _loadedRock;
  List<String> _loadedLayerPaths = [];

  final Map<String, ui.Image> _layerImages = {};
  final List<_CloudState> _clouds = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat()
          ..addListener(_onTick);
    _initClouds();
    _loadAssets(widget.theme);
  }

  void _initClouds() {
    _clouds.clear();
    for (int i = 0; i < 3; i++) {
      _clouds.add(
        _CloudState(
          x: _rng.nextDouble() * 320,
          y: 16 + _rng.nextDouble() * 40,
          speed: 8 + _rng.nextDouble() * 10,
          scale: 0.35 + _rng.nextDouble() * 0.4,
          opacity: 0.3 + _rng.nextDouble() * 0.4,
        ),
      );
    }
  }

  double _lastTime = 0;

  void _onTick() {
    final now = _ticker.value * 10;
    final dt = now - _lastTime;
    _lastTime = now;
    for (final c in _clouds) {
      c.x -= c.speed * dt;
      if (c.x < -80) {
        c.x = 360;
        c.y = 16 + _rng.nextDouble() * 40;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant EnvPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final t = widget.theme;
    final layerPathsChanged =
        t.layers.length != oldWidget.theme.layers.length ||
        !t.layers.every(
          (l) => oldWidget.theme.layers.any(
            (ol) => ol.id == l.id && ol.assetPath == l.assetPath,
          ),
        );

    if (t.skyPath != _loadedSky ||
        t.groundPath != _loadedGround ||
        t.cloudPath != _loadedCloud ||
        t.mountainLeftPath != _loadedMountain ||
        t.rockLeftPath != _loadedRock ||
        layerPathsChanged) {
      _loadAssets(t);
    }
  }

  Future<void> _loadAssets(CustomEnvironmentTheme t) async {
    _loadedSky = t.skyPath;
    _loadedGround = t.groundPath;
    _loadedCloud = t.cloudPath;
    _loadedMountain = t.mountainLeftPath;
    _loadedRock = t.rockLeftPath;
    _loadedLayerPaths = t.layers.map((l) => l.assetPath).toList();

    final pathsToLoad = <String>{
      if (t.skyPath != 'none') t.skyPath,
      if (t.groundPath != 'none') t.groundPath,
      if (t.cloudPath != 'none') t.cloudPath,
      if (t.mountainLeftPath != 'none') t.mountainLeftPath,
      if (t.rockLeftPath != 'none') t.rockLeftPath,
      ..._loadedLayerPaths,
    };

    final futures = pathsToLoad.map((p) async {
      final img = await _safeLoad(p);
      return MapEntry(p, img);
    });

    final results = await Future.wait(futures);
    if (!mounted) return;

    setState(() {
      _layerImages.clear();
      for (final entry in results) {
        if (entry.value != null) {
          _layerImages[entry.key] = entry.value!;
        }
      }
      _skyImage = _layerImages[t.skyPath];
      _groundImage = _layerImages[t.groundPath];
      _cloudImage = _layerImages[t.cloudPath];
      _mountainImage = _layerImages[t.mountainLeftPath];
      _rockImage = _layerImages[t.rockLeftPath];
    });
  }

  Future<ui.Image?> _safeLoad(String path) async {
    if (path == 'none' || path.isEmpty) return null;
    try {
      return await PetAssetLoader.loadImage(path);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewHeader(),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.radiusMd),
              ),
              child: CustomPaint(
                painter: _EnvPainter(
                  skyImage: _skyImage,
                  groundImage: _groundImage,
                  cloudImage: _cloudImage,
                  mountainImage: _mountainImage,
                  rockImage: _rockImage,
                  clouds: _clouds,
                  layers: widget.theme.layers,
                  layerImages: _layerImages,
                  groundTint: Color(widget.theme.groundTintArgb),
                  cloudTint: Color(widget.theme.cloudTintArgb),
                  baseColor: Color(widget.theme.baseColorArgb),
                  isGroundTiled: widget.theme.isGroundTiled,
                  skyOpacity: widget.theme.skyOpacity,
                  cloudOpacity: widget.theme.cloudOpacity,
                  groundOpacity: widget.theme.groundOpacity,
                  mountainOpacity: widget.theme.mountainOpacity,
                  rockOpacity: widget.theme.rockOpacity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.landscape_rounded,
            size: 14,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          const Text(
            'Live Preview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: -0.1,
              fontFamily: 'Inter',
            ),
          ),
          const Spacer(),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Live',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF10B981),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvPainter extends CustomPainter {
  final ui.Image? skyImage;
  final ui.Image? groundImage;
  final ui.Image? cloudImage;
  final ui.Image? mountainImage;
  final ui.Image? rockImage;
  final List<_CloudState> clouds;
  final List<CustomEnvironmentLayer> layers;
  final Map<String, ui.Image> layerImages;
  final Color groundTint;
  final Color cloudTint;
  final Color baseColor;
  final bool isGroundTiled;
  final double skyOpacity;
  final double cloudOpacity;
  final double groundOpacity;
  final double mountainOpacity;
  final double rockOpacity;

  const _EnvPainter({
    required this.skyImage,
    required this.groundImage,
    required this.cloudImage,
    required this.mountainImage,
    required this.rockImage,
    required this.clouds,
    required this.layers,
    required this.layerImages,
    required this.groundTint,
    required this.cloudTint,
    required this.baseColor,
    required this.isGroundTiled,
    required this.skyOpacity,
    required this.cloudOpacity,
    required this.groundOpacity,
    required this.mountainOpacity,
    required this.rockOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h - 36;

    // Sky
    if (skyImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, w, h),
        image: skyImage!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: skyOpacity),
          BlendMode.modulate,
        ),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF87CEEB).withValues(alpha: skyOpacity),
      );
    }

    // Clouds
    if (cloudImage != null) {
      for (final c in clouds) {
        final paint = Paint()
          ..colorFilter = ColorFilter.mode(
            cloudTint.withValues(alpha: c.opacity * cloudOpacity),
            BlendMode.modulate,
          )
          ..filterQuality = FilterQuality.medium;
        final cw = cloudImage!.width * c.scale;
        final ch = cloudImage!.height * c.scale;
        canvas.drawImageRect(
          cloudImage!,
          Rect.fromLTWH(
            0,
            0,
            cloudImage!.width.toDouble(),
            cloudImage!.height.toDouble(),
          ),
          Rect.fromLTWH(c.x, c.y, cw, ch),
          paint,
        );
      }
    }

    // Base fill below ground
    canvas.drawRect(
      Rect.fromLTWH(0, groundY + 12, w, h - groundY - 12),
      Paint()..color = baseColor.withValues(alpha: 0.95 * groundOpacity),
    );

    // Tiled ground
    if (groundImage != null) {
      const tileW = 36.0;
      const tileH = 24.0;
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(
          groundTint.withValues(alpha: groundOpacity),
          BlendMode.modulate,
        )
        ..filterQuality = FilterQuality.none;
      if (isGroundTiled) {
        double x = 0;
        while (x < w + tileW) {
          canvas.drawImageRect(
            groundImage!,
            Rect.fromLTWH(
              0,
              0,
              groundImage!.width.toDouble(),
              groundImage!.height.toDouble(),
            ),
            Rect.fromLTWH(x, groundY, tileW, tileH),
            paint,
          );
          x += tileW;
        }
      } else {
        // Draw the ground as a single stretched image covering the width, anchored at the floorY
        final double floorY = h - 24.0;
        final double imgW = groundImage!.width.toDouble();
        final double imgH = groundImage!.height.toDouble();

        final double drawWidth = w;
        final double drawHeight = drawWidth * (imgH / imgW);
        final double scaledGrassFromBottom = drawHeight * (20.0 / 272.0);

        final double imageBottomY = floorY + scaledGrassFromBottom;
        final double imageTopY = imageBottomY - drawHeight;

        canvas.drawImageRect(
          groundImage!,
          Rect.fromLTWH(0, 0, imgW, imgH),
          Rect.fromLTWH(0, imageTopY, drawWidth, drawHeight),
          paint,
        );
      }
    }

    if (layers.isNotEmpty) {
      // Paint dynamic layers in sequence
      for (final layer in layers) {
        final img = layerImages[layer.assetPath];
        if (img != null) {
          final imgW = img.width.toDouble();
          final imgH = img.height.toDouble();

          final double scaleFactor = h / 160.0;
          final double drawW = imgW * layer.scale * scaleFactor;
          final double drawH = imgH * layer.scale * scaleFactor;

          final double posX = w * layer.xRatio;
          final double posY = groundY - (layer.yRatio * groundY);

          final paint = Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(
              Colors.white.withValues(alpha: layer.opacity),
              BlendMode.modulate,
            );

          canvas.save();
          if (layer.flipX) {
            canvas.translate(posX, posY);
            canvas.scale(-1, 1);
            canvas.translate(-posX, -posY);
          }

          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, imgW, imgH),
            Rect.fromLTWH(posX - drawW / 2, posY - drawH, drawW, drawH),
            paint,
          );
          canvas.restore();
        }
      }
    } else {
      // Legacy mountain background decoration (Tree)
      if (mountainImage != null) {
        final mh = (h * 0.45).clamp(40.0, 160.0);
        final mw = mh * (mountainImage!.width / mountainImage!.height);
        canvas.drawImageRect(
          mountainImage!,
          Rect.fromLTWH(
            0,
            0,
            mountainImage!.width.toDouble(),
            mountainImage!.height.toDouble(),
          ),
          Rect.fromLTWH(w * 0.1, groundY - mh + 10, mw, mh),
          Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(
              Colors.white.withValues(alpha: mountainOpacity),
              BlendMode.modulate,
            ),
        );
      }

      // Legacy rock decorations
      if (rockImage != null) {
        final rh = (h * 0.18).clamp(18.0, 52.0);
        final rw = rh * (rockImage!.width / rockImage!.height);
        final rockPaint = Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ColorFilter.mode(
            Colors.white.withValues(alpha: rockOpacity),
            BlendMode.modulate,
          );
        canvas.drawImageRect(
          rockImage!,
          Rect.fromLTWH(
            0,
            0,
            rockImage!.width.toDouble(),
            rockImage!.height.toDouble(),
          ),
          Rect.fromLTWH(w * 0.72, groundY - rh + 12, rw, rh),
          rockPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EnvPainter old) {
    return true; // clouds animate and layers can be modified in real-time
  }
}

class _CloudState {
  double x;
  double y;
  final double speed;
  final double scale;
  final double opacity;

  _CloudState({
    required this.x,
    required this.y,
    required this.speed,
    required this.scale,
    required this.opacity,
  });
}
