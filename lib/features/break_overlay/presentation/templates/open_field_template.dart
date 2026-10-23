import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class OpenFieldTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const OpenFieldTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<OpenFieldTemplate> createState() => _OpenFieldTemplateState();
}

class _OpenFieldTemplateState extends State<OpenFieldTemplate>
    with TickerProviderStateMixin {
  static const List<Color> _sky = [Color(0xFF20324A), Color(0xFF5E7F8F)];

  /// Mist: 30px drift over 20s. Grass: +-3 degree sway over 4s.
  late final AnimationController _mist = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  late final AnimationController _grass = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  ImageProvider? _image;
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void initState() {
    super.initState();
    _image = _resolveImage();
  }

  @override
  void didUpdateWidget(covariant OpenFieldTemplate old) {
    super.didUpdateWidget(old);
    if (old.settings.customImagePath != widget.settings.customImagePath) {
      setState(() => _image = _resolveImage());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_mist, context, reverse: true);
    breakSyncLoop(_grass, context, park: 0.0);
    final img = _image;
    if (img != null) BreakImageBackground.precache(context, img);
  }

  @override
  void dispose() {
    _mist.dispose();
    _grass.dispose();
    super.dispose();
  }

  ImageProvider? _resolveImage() {
    final path = widget.settings.customImagePath;
    final isCustomEnabled = path != null && !path.startsWith('disabled:');
    final actualPath = (path != null && path.startsWith('disabled:'))
        ? path.substring(9)
        : path;
    if (isCustomEnabled &&
        actualPath != null &&
        actualPath != 'default_path' &&
        File(actualPath).existsSync()) {
      return ResizeImage(FileImage(File(actualPath)), width: 2560);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _kind.accent;
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      palette: BreakPalette.field,
      canvas: BreakPalette.field.canvas,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: Stack(
        fit: StackFit.expand,
        children: [
          BreakImageBackground(image: _image, fallback: _sky),
          // The procedural landscape stands in until (or instead of) a photo.
          if (_image == null) ...[
            const CustomPaint(painter: _HillsPainter()),
            TweenAnimationBuilder<double>(
              tween: Tween(end: complete ? 1.0 : 0.0),
              duration: BreakMotion.slow,
              builder: (context, fade, _) => CustomPaint(
                painter: _MistPainter(drift: _mist, fade: fade),
              ),
            ),
            CustomPaint(painter: _GrassPainter(sway: _grass)),
          ],
          // Bottom scrim keeps the text readable on any image.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xBF000000)],
                stops: [0.4, 1.0],
              ),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Focal point on the horizon: look at this, far away.
          Positioned(
            left: 900 - 40,
            top: 440 - 34,
            width: 80,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(2),
              scale: false,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LOOK HERE',
                      maxLines: 1,
                      softWrap: false,
                      style: BreakOverlayTheme.micro.copyWith(
                        color: BreakPalette.field.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 64,
            bottom: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BreakEntrance(
                  scale: false,
                  child: BreakLabel(_kind.label, textAlign: TextAlign.left),
                ),
                const SizedBox(height: 8),
                BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    textAlign: TextAlign.left,
                    color: breakClockColor(widget.settings, BreakPalette.field),
                  ),
                ),
                if (showTip) ...[
                  const SizedBox(height: 12),
                  BreakEntrance(
                    delay: BreakEntrance.stagger(2),
                    scale: false,
                    child: BreakTip(
                      widget.breakInfo.tip,
                      textAlign: TextAlign.left,
                      maxWidth: 380,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three rolling hills in front of the sky: far, middle, near.
class _HillsPainter extends CustomPainter {
  const _HillsPainter();

  static const _hills = [
    (base: 0.55, amp: 0.05, f: 1.3, p: 0.4, color: Color(0xFF2F5D4A)),
    (base: 0.63, amp: 0.06, f: 1.0, p: 2.1, color: Color(0xFF3E7A5E)),
    (base: 0.74, amp: 0.05, f: 0.8, p: 4.0, color: Color(0x9974C69D)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final h in _hills) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i <= 40; i++) {
        final t = i / 40;
        final y =
            size.height * (h.base - h.amp * math.sin(t * math.pi * h.f + h.p));
        path.lineTo(size.width * t, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      paint.color = h.color;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HillsPainter old) => false;
}

class _MistPainter extends CustomPainter {
  final Animation<double> drift;
  final double fade;

  final Paint _p = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

  _MistPainter({required this.drift, required this.fade})
    : super(repaint: drift);

  @override
  void paint(Canvas canvas, Size size) {
    final dx = 30 * Curves.easeInOutSine.transform(drift.value);
    _p.color = Colors.white.withValues(alpha: 0.08 * (1 - fade));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -60 + dx,
          size.height * 0.60,
          size.width + 120,
          size.height * 0.07,
        ),
        const Radius.circular(40),
      ),
      _p,
    );
  }

  @override
  bool shouldRepaint(covariant _MistPainter old) => old.fade != fade;
}

/// 40 blades of grass along the bottom edge, each swaying on its own phase.
class _GrassPainter extends CustomPainter {
  final Animation<double> sway;

  static const int _count = 40;
  late final List<({double x, double h, double phase})> _blades = () {
    final r = math.Random(5);
    return [
      for (var i = 0; i < _count; i++)
        (
          x: (i + 0.5 + (r.nextDouble() - 0.5) * 0.6) / _count,
          h: 20 + r.nextDouble() * 20,
          phase: r.nextDouble(),
        ),
    ];
  }();

  final Paint _p = Paint()
    ..color = const Color(0xFF74C69D)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  _GrassPainter({required this.sway}) : super(repaint: sway);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / 800;
    for (final b in _blades) {
      final angle =
          3 * math.pi / 180 * math.sin((sway.value + b.phase) * 2 * math.pi);
      final base = Offset(size.width * b.x, size.height + 2);
      final len = b.h * k;
      canvas.drawLine(
        base,
        base + Offset(math.sin(angle) * len, -math.cos(angle) * len),
        _p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrassPainter old) => false;
}
