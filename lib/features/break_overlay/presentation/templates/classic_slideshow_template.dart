import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/wellness_notes_panel.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class ClassicSlideshowTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;
  final PageController? pageController;
  final AnimationController kenBurnsController;
  final String? singleImage;
  final String? exerciseTitle;
  final String? exerciseInstructions;

  const ClassicSlideshowTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
    this.pageController,
    required this.kenBurnsController,
    this.singleImage,
    this.exerciseTitle,
    this.exerciseInstructions,
  });

  @override
  State<ClassicSlideshowTemplate> createState() =>
      _ClassicSlideshowTemplateState();
}

class _ClassicSlideshowTemplateState extends State<ClassicSlideshowTemplate> {
  static const List<Color> _fallback = [Color(0xFF1E2A3A), Color(0xFF3A4F63)];

  ImageProvider? _image;

  /// The bundled photo on screen, or null for a custom photo / none.
  String? _assetKey;
  Timer? _rotator;

  /// How long each bundled photo stays before the next dissolves in.
  static const Duration _slideEvery = Duration(seconds: 20);
  static const Duration _dissolve = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _image = _resolveImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final img = _image;
    if (img != null) BreakImageBackground.precache(context, img);
    _syncRotation();
  }

  /// Cycles the bundled photos with a cross-dissolve. Not for a custom photo,
  /// a PageView-driven slideshow, or frozen (preview / reduced motion) frames.
  void _syncRotation() {
    _rotator?.cancel();
    _rotator = null;
    final photos = AppConstants.wellnessSlideshow;
    if (_assetKey == null ||
        photos.length < 2 ||
        widget.pageController != null ||
        breakShouldFreeze(context)) {
      return;
    }
    _rotator = Timer.periodic(_slideEvery, (_) {
      if (!mounted) return;
      final next = photos[(photos.indexOf(_assetKey!) + 1) % photos.length];
      final image = ResizeImage(AssetImage(next), width: 2560);
      BreakImageBackground.precache(context, image).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _assetKey = next;
          _image = image;
        });
      });
    });
  }

  @override
  void didUpdateWidget(covariant ClassicSlideshowTemplate old) {
    super.didUpdateWidget(old);
    if (old.settings.customImagePath != widget.settings.customImagePath ||
        old.singleImage != widget.singleImage) {
      _image = _resolveImage();
      final img = _image;
      if (img != null) BreakImageBackground.precache(context, img);
      _syncRotation();
    }
  }

  @override
  void dispose() {
    _rotator?.cancel();
    super.dispose();
  }

  /// The user's custom photo when enabled and present, else the single
  /// slideshow asset. Null leaves the gradient fallback on screen.
  ImageProvider? _resolveImage() {
    _assetKey = null;
    final path = widget.settings.customImagePath;
    final isCustomEnabled = path != null && !path.startsWith('disabled:');
    final actualPath = path != null && path.startsWith('disabled:')
        ? path.substring(9)
        : path;
    if (isCustomEnabled &&
        actualPath != null &&
        actualPath != 'default_path' &&
        File(actualPath).existsSync()) {
      return ResizeImage(FileImage(File(actualPath)), width: 2560);
    }
    if (widget.pageController != null &&
        AppConstants.wellnessSlideshow.isNotEmpty) {
      return null; // the PageView below supplies the photos
    }
    final s = widget.singleImage;
    final img = (s != null && s.isNotEmpty)
        ? s
        : (AppConstants.wellnessSlideshow.isNotEmpty
              ? AppConstants.wellnessSlideshow.first
              : null);
    if (img == null || img.isEmpty) return null;
    _assetKey = img;
    return ResizeImage(AssetImage(img), width: 2560);
  }

  /// Slow zoom and 2% pan across the photo's lifetime, from the overlay's
  /// shared Ken Burns controller. Static in thumbnails and reduced motion.
  Widget _kenBurns(Widget photo) {
    if (breakShouldFreeze(context)) return photo;
    return AnimatedBuilder(
      animation: widget.kenBurnsController,
      child: photo,
      builder: (context, child) {
        final v = widget.kenBurnsController.value;
        return LayoutBuilder(
          builder: (context, c) => Transform.translate(
            offset: Offset(-0.02 * c.maxWidth * v, 0),
            child: Transform.scale(scale: 1.0 + 0.08 * v, child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = BreakKind.of(widget.breakInfo);
    final accent = kind.accent;
    final hasExercise =
        widget.exerciseTitle != null && widget.exerciseInstructions != null;

    // Each photo is keyed by its asset, so a change cross-dissolves.
    Widget photo = AnimatedSwitcher(
      duration: breakShouldFreeze(context) ? Duration.zero : _dissolve,
      child: KeyedSubtree(
        key: ValueKey(_assetKey ?? ''),
        child: BreakImageBackground(
          image: _image,
          fallback: _fallback,
          imageBuilder: _kenBurns,
        ),
      ),
    );
    // No photo and no bundled slideshow: paint misty ridges instead of a flat
    // gradient, so the tile still reads as a landscape.
    if (_image == null) {
      photo = Stack(
        fit: StackFit.expand,
        children: [
          photo,
          _kenBurns(const CustomPaint(painter: _RidgesPainter())),
        ],
      );
    }
    final pages = widget.pageController;
    if (_image == null &&
        pages != null &&
        AppConstants.wellnessSlideshow.isNotEmpty) {
      photo = Stack(
        fit: StackFit.expand,
        children: [
          photo,
          _kenBurns(
            PageView.builder(
              controller: pages,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: AppConstants.wellnessSlideshow.length,
              itemBuilder: (_, i) => Image(
                image: ResizeImage(
                  AssetImage(AppConstants.wellnessSlideshow[i]),
                  width: 2560,
                ),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      );
    }

    return BreakScaffold(
      palette: BreakPalette.onPhoto,
      canvas: _fallback.first,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(child: photo),
          const Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.22,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.62,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.55, 1],
                    colors: [
                      Colors.transparent,
                      Color(0x8C05080D),
                      Color(0xE605080D),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 72,
            bottom: 72,
            width: 640,
            child: BreakEntrance(
              scale: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.breakInfo.tip,
                    style: BreakOverlayTheme.serif.copyWith(
                      fontSize: 30,
                      height: 1.3,
                      color: BreakPalette.onPhoto.textPrimary,
                    ),
                  ),
                  if (hasExercise)
                    WellnessNotesPanel(
                      title: widget.exerciseTitle!,
                      instructions: widget.exerciseInstructions!,
                    ),
                  const SizedBox(height: 28),
                  Container(width: 56, height: 2, color: accent),
                  const SizedBox(height: 8),
                  BreakCountdown(
                    seconds: widget.remainingSeconds,
                    textAlign: TextAlign.left,
                    style: BreakOverlayTheme.hero.copyWith(
                      fontSize: 168,
                      fontWeight: FontWeight.w200,
                      height: 0.95,
                      letterSpacing: -7,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    color: breakClockColor(
                      widget.settings,
                      BreakPalette.onPhoto,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: breakProgress(
                  widget.remainingSeconds,
                  widget.totalSeconds,
                ),
                child: ColoredBox(
                  color: accent,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four layered ridge lines fading into haze, with a low sun glow.
class _RidgesPainter extends CustomPainter {
  const _RidgesPainter();

  static const List<Color> _layers = [
    Color(0xFF4C6279),
    Color(0xFF3E5368),
    Color(0xFF2F4357),
    Color(0xFF22313F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final glowCenter = Offset(size.width * 0.72, size.height * 0.46);
    canvas.drawCircle(
      glowCenter,
      size.shortestSide * 0.7,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0x33FFD9A8), Color(0x00FFD9A8)],
            ).createShader(
              Rect.fromCircle(
                center: glowCenter,
                radius: size.shortestSide * 0.7,
              ),
            ),
    );
    for (var i = 0; i < _layers.length; i++) {
      final base = size.height * (0.50 + 0.1 * i);
      final amp = size.height * (0.07 - 0.008 * i);
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 8) {
        final t = x / size.width;
        final y =
            base +
            amp * math.sin(t * math.pi * (1.6 + 0.5 * i) + i * 1.7) +
            amp * 0.4 * math.sin(t * math.pi * (4.1 + i) + i);
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = _layers[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _RidgesPainter old) => false;
}
