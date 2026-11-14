import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _graphite = BreakPalette(
  canvas: Color(0xFF14161A),
  canvasRaised: Color(0xFF23272D),
  surface: Color(0xFF1B1E23),
  border: Color(0x24FFFFFF),
  track: Color(0x33FFFFFF),
  textPrimary: Color(0xFFF1ECE2),
  textSecondary: Color(0xFFB9B4AA),
  textMuted: Color(0xFF8A8A8A),
  isDark: true,
);

const _amber = Color(0xFFE8A33D);

/// Break template: camera-aperture iris that opens and closes slowly as a focus point for resting the eyes.
class IrisRestTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const IrisRestTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<IrisRestTemplate> createState() => _IrisRestTemplateState();
}

class _IrisRestTemplateState extends State<IrisRestTemplate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iris = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Fixed apertures for preview and reduced motion; otherwise the iris loops back and forth.
    if (BreakPreviewScope.isPreview(context)) {
      _iris.value = 0.546;
    } else if (BreakMotion.reduced(context)) {
      _iris.value = 0.6415;
    } else {
      _iris.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _iris.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const palette = _graphite;
    final accent = BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'iris_rest',
      _amber,
    );
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final reduced = BreakMotion.reduced(context);
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      palette: palette,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.38, 0),
            radius: 0.85,
            colors: [Color(0xFF2B3037), Color(0xFF14161A)],
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 400 - _lens / 2,
            top: 400 - _lens / 2,
            child: BreakEntrance(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: complete ? 1.0 : 0.0),
                duration: BreakMotion.slow,
                curve: BreakMotion.enter,
                builder: (context, finish, _) => RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(_lens, _lens),
                    painter: _AperturePainter(
                      open: _iris,
                      fixed: reduced || BreakPreviewScope.isPreview(context),
                      accent: accent,
                      bladeA: const Color(0xFF565C66),
                      bladeB: const Color(0xFF2E3238),
                      edge: Colors.white.withValues(alpha: 0.16),
                      finish: finish,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 760,
            top: 270,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Text(
                'Eye rest',
                style: BreakOverlayTheme.body.copyWith(
                  color: breakReadableColor(accent, palette.surface),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Positioned(
            left: 752,
            top: 300,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                textAlign: TextAlign.left,
                style: BreakOverlayTheme.hero.copyWith(
                  fontSize: 132,
                  letterSpacing: -6,
                ),
                color: breakClockColor(widget.settings, palette),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 760,
              top: 460,
              width: 400,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(2),
                scale: false,
                child: Text(
                  widget.breakInfo.tip,
                  style: BreakOverlayTheme.serif.copyWith(
                    fontSize: 22,
                    height: 1.5,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const double _lens = 512;
}

class _AperturePainter extends CustomPainter {
  final Animation<double> open;
  final bool fixed;
  final Color accent;
  final Color bladeA;
  final Color bladeB;
  final Color edge;
  final double finish;

  static const int _blades = 8;
  static const double _outer = 130;
  static const double _units = 330;
  static const double _bezelR = 145;

  static final Path _knurl = () {
    final p = Path();
    for (var i = 0; i < 90; i++) {
      final a = i * 2 * math.pi / 90;
      p
        ..moveTo(math.cos(a) * 138, math.sin(a) * 138)
        ..lineTo(math.cos(a) * 152, math.sin(a) * 152);
    }
    return p;
  }();

  final List<Path> _paths = List.generate(_blades, (_) => Path());
  final Paint _fill = Paint();
  final Paint _flat = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _bezel = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 26
    ..shader = const SweepGradient(
      colors: [
        Color(0xFF5B6068),
        Color(0xFFE3E6EA),
        Color(0xFF454A52),
        Color(0xFFCDD1D7),
        Color(0xFF5B6068),
      ],
      stops: [0, 0.25, 0.5, 0.78, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 160));
  final Paint _lip = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..color = const Color(0xFF0A0B0D);
  final Paint _knurlPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..color = const Color(0x59000000);
  final Paint _glass = Paint()
    ..shader = const RadialGradient(
      center: Alignment(-0.35, -0.35),
      colors: [Color(0xFF1E3446), Color(0xFF07090B)],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: _outer));
  final Paint _amberRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _dot = Paint();

  _AperturePainter({
    required this.open,
    required this.fixed,
    required this.accent,
    required this.bladeA,
    required this.bladeB,
    required this.edge,
    required this.finish,
  }) : super(repaint: open) {
    _fill.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [bladeA, bladeB],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: _outer));
    _flat.color = Color.lerp(bladeA, bladeB, 0.5)!;
    _stroke.color = edge;
  }

  static Offset _p(double r, double a) =>
      Offset(math.cos(a) * r, math.sin(a) * r);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = fixed ? 0.5 : Curves.easeInOutSine.transform(open.value);

    final base = fixed ? 85.0 : 104 * eased;
    final r = base + (125 - base) * finish;
    final dotR = fixed ? 4.0 : 5 - 3 * eased;
    final twist = -(1 - (r / 125).clamp(0.0, 1.0)) * 0.45;
    final step = 2 * math.pi / _blades;
    final vertexR = r / math.cos(step / 2);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / _units);
    canvas.drawCircle(Offset.zero, _outer, _glass);
    canvas.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: _outer + 4),
      Paint()..color = Color.fromRGBO(255, 255, 255, 1 - 0.85 * finish),
    );
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: _outer)),
    );

    const reach = _outer * 2.2;
    for (var i = 0; i < _blades; i++) {
      final a = i * step + twist;

      final v0 = _p(vertexR, a - step / 2);
      final v1 = _p(vertexR, a + step / 2);
      final along = _p(reach, a + math.pi / 2);
      final out = _p(reach, a);
      _paths[i]
        ..reset()
        ..moveTo(v0.dx, v0.dy)
        ..lineTo(v0.dx + along.dx, v0.dy + along.dy)
        ..lineTo(v0.dx + along.dx + out.dx, v0.dy + along.dy + out.dy)
        ..lineTo(v0.dx + out.dx, v0.dy + out.dy)
        ..close();
      canvas.drawPath(_paths[i], i.isEven ? _fill : _flat);
      canvas.drawLine(v0, v1, _stroke);
    }
    canvas.restore();
    canvas.drawCircle(Offset.zero, _bezelR, _bezel);
    canvas.drawPath(_knurl, _knurlPaint);
    canvas.drawCircle(Offset.zero, _outer + 3, _lip);
    canvas.drawCircle(
      Offset.zero,
      _outer - 6,
      _amberRing..color = accent.withValues(alpha: 0.55 * (1 - finish)),
    );

    _dot.color = accent.withValues(alpha: 1 - 0.85 * finish);
    canvas.drawCircle(Offset.zero, dotR.clamp(1.5, 5.0), _dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AperturePainter old) =>
      old.fixed != fixed ||
      old.accent != accent ||
      old.bladeA != bladeA ||
      old.bladeB != bladeB ||
      old.edge != edge ||
      old.finish != finish;
}
