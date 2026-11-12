import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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
  /// Dilate over 2.5s, constrict over 2.5s: a 5s cycle.
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
    if (BreakPreviewScope.isPreview(context)) {
      _iris.value = 0.546; // opening ~80px
    } else if (BreakMotion.reduced(context)) {
      _iris.value = 0.6415; // opening ~90px, held
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
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      BreakOverlayTheme.resolveAccent(
        widget.settings.templateAccentOverrides,
        'iris_rest',
        BreakOverlayTheme.nature,
      ),
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
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: 640 - 130,
            top: 330 - 130,
            child: BreakEntrance(
              child: TweenAnimationBuilder<double>(
                // Completion: the aperture opens fully and fades.
                tween: Tween(end: complete ? 1.0 : 0.0),
                duration: BreakMotion.slow,
                curve: BreakMotion.enter,
                builder: (context, finish, _) => RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(260, 260),
                    painter: _AperturePainter(
                      open: _iris,
                      fixed: reduced || BreakPreviewScope.isPreview(context),
                      accent: accent,
                      bladeA: Color.lerp(
                        palette.surface,
                        palette.isDark ? Colors.white : Colors.black,
                        0.08,
                      )!,
                      bladeB: palette.canvasRaised,
                      edge: palette.isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : const Color(0xFF1C1F24).withValues(alpha: 0.14),
                      housing: palette.border,
                      finish: finish,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 330 + 130 + 40,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                color: breakClockColor(widget.settings, palette),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              top: 330 + 130 + 40 + 72,
              left: 0,
              right: 0,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(2),
                scale: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      widget.breakInfo.tip,
                      textAlign: TextAlign.center,
                      style: BreakOverlayTheme.serif.copyWith(
                        fontSize: 20,
                        height: 1.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  final Animation<double> open;
  final bool fixed;
  final Color accent;
  final Color bladeA;
  final Color bladeB;
  final Color edge;
  final Color housing;
  final double finish;

  static const int _blades = 8;
  static const double _outer = 130;

  final List<Path> _paths = List.generate(_blades, (_) => Path());
  final Paint _fill = Paint();
  final Paint _flat = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _dot = Paint();

  _AperturePainter({
    required this.open,
    required this.fixed,
    required this.accent,
    required this.bladeA,
    required this.bladeB,
    required this.edge,
    required this.housing,
    required this.finish,
  }) : super(repaint: open) {
    _fill.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [bladeA, bladeB],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: _outer));
    _flat.color = Color.lerp(bladeA, bladeB, 0.5)!;
    _stroke.color = edge;
    _ring.color = housing;
  }

  static Offset _p(double r, double a) =>
      Offset(math.cos(a) * r, math.sin(a) * r);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = fixed ? 0.5 : Curves.easeInOutSine.transform(open.value);
    // Opening radius 0 (fully shut) -> 104px; completion opens it fully.
    final base = fixed ? 85.0 : 104 * eased;
    final r = base + (125 - base) * finish;
    final dotR = fixed ? 4.0 : 5 - 3 * eased;
    final twist = -(1 - (r / 125).clamp(0.0, 1.0)) * 0.45;
    final step = 2 * math.pi / _blades;
    final vertexR = r / math.cos(step / 2);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
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
      // Each leaf is the half-plane beyond one tangent edge of the opening,
      // so leaves tile the annulus and fully overlap when the iris shuts.
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
    canvas.drawCircle(Offset.zero, _outer, _ring);

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
      old.housing != housing ||
      old.finish != finish;
}
