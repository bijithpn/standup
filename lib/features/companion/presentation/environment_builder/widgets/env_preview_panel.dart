import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

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

  final List<_CloudState> _clouds = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )
      ..repeat()
      ..addListener(_onTick);
    _initClouds();
    _loadAssets(widget.theme);
  }

  void _initClouds() {
    _clouds.clear();
    for (int i = 0; i < 3; i++) {
      _clouds.add(_CloudState(
        x: _rng.nextDouble() * 320,
        y: 16 + _rng.nextDouble() * 40,
        speed: 8 + _rng.nextDouble() * 10,
        scale: 0.35 + _rng.nextDouble() * 0.4,
        opacity: 0.3 + _rng.nextDouble() * 0.4,
      ));
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
    if (t.skyPath != _loadedSky ||
        t.groundPath != _loadedGround ||
        t.cloudPath != _loadedCloud ||
        t.mountainLeftPath != _loadedMountain ||
        t.rockLeftPath != _loadedRock) {
      _loadAssets(t);
    }
  }

  Future<void> _loadAssets(CustomEnvironmentTheme t) async {
    _loadedSky = t.skyPath;
    _loadedGround = t.groundPath;
    _loadedCloud = t.cloudPath;
    _loadedMountain = t.mountainLeftPath;
    _loadedRock = t.rockLeftPath;

    final results = await Future.wait([
      _safeLoad(t.skyPath),
      _safeLoad(t.groundPath),
      _safeLoad(t.cloudPath),
      _safeLoad(t.mountainLeftPath),
      _safeLoad(t.rockLeftPath),
    ]);
    if (!mounted) return;
    setState(() {
      _skyImage = results[0];
      _groundImage = results[1];
      _cloudImage = results[2];
      _mountainImage = results[3];
      _rockImage = results[4];
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
          const Icon(Icons.landscape_rounded, size: 14, color: AppTheme.textSecondary),
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
            style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontFamily: 'Inter'),
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
        colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: skyOpacity), BlendMode.modulate),
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
          Rect.fromLTWH(0, 0, cloudImage!.width.toDouble(), cloudImage!.height.toDouble()),
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
        ..colorFilter = ColorFilter.mode(groundTint.withValues(alpha: groundOpacity), BlendMode.modulate)
        ..filterQuality = FilterQuality.none;
      if (isGroundTiled) {
        double x = 0;
        while (x < w + tileW) {
          canvas.drawImageRect(
            groundImage!,
            Rect.fromLTWH(0, 0, groundImage!.width.toDouble(), groundImage!.height.toDouble()),
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

    // Mountain background decoration (Tree)
    if (mountainImage != null) {
      final mh = (h * 0.45).clamp(40.0, 160.0);
      final mw = mh * (mountainImage!.width / mountainImage!.height);
      canvas.drawImageRect(
        mountainImage!,
        Rect.fromLTWH(0, 0, mountainImage!.width.toDouble(), mountainImage!.height.toDouble()),
        Rect.fromLTWH(w * 0.1, groundY - mh + 10, mw, mh),
        Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: mountainOpacity), BlendMode.modulate),
      );
    }

    // Rock decorations
    if (rockImage != null) {
      final rh = (h * 0.18).clamp(18.0, 52.0);
      final rw = rh * (rockImage!.width / rockImage!.height);
      final rockPaint = Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: rockOpacity), BlendMode.modulate);
      canvas.drawImageRect(
        rockImage!,
        Rect.fromLTWH(0, 0, rockImage!.width.toDouble(), rockImage!.height.toDouble()),
        Rect.fromLTWH(w * 0.72, groundY - rh + 12, rw, rh),
        rockPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EnvPainter old) {
    return old.skyImage != skyImage ||
        old.groundImage != groundImage ||
        old.cloudImage != cloudImage ||
        old.mountainImage != mountainImage ||
        old.rockImage != rockImage ||
        old.groundTint != groundTint ||
        old.cloudTint != cloudTint ||
        old.baseColor != baseColor ||
        old.isGroundTiled != isGroundTiled ||
        old.skyOpacity != skyOpacity ||
        old.cloudOpacity != cloudOpacity ||
        old.groundOpacity != groundOpacity ||
        old.mountainOpacity != mountainOpacity ||
        old.rockOpacity != rockOpacity ||
        true; // clouds animate
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
