import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class DuskGlowTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const DuskGlowTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  /// Days into the lunar cycle at [when] (0 = new moon), using the synodic
  /// month of 29.53 days from the new moon of 2000-01-06 18:14 UTC.
  static double moonAge(DateTime when) {
    const synodic = 29.530588853;
    final ref = DateTime.utc(2000, 1, 6, 18, 14);
    final days = when.toUtc().difference(ref).inSeconds / 86400.0;
    final age = days % synodic;
    return age < 0 ? age + synodic : age;
  }

  static String moonPhaseName(double age) {
    const t = 29.530588853;
    final f = age / t;
    if (f < 0.034 || f >= 0.966) return 'New moon';
    if (f < 0.216) return 'Waxing crescent';
    if (f < 0.284) return 'First quarter';
    if (f < 0.466) return 'Waxing gibbous';
    if (f < 0.534) return 'Full moon';
    if (f < 0.716) return 'Waning gibbous';
    if (f < 0.784) return 'Last quarter';
    return 'Waning crescent';
  }

  @override
  State<DuskGlowTemplate> createState() => _DuskGlowTemplateState();
}

class _DuskGlowTemplateState extends State<DuskGlowTemplate>
    with SingleTickerProviderStateMixin {
  /// Aurora curtains drift sideways once every 30s.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);
  late final double _age = DuskGlowTemplate.moonAge(clock.now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_drift, context);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = breakAccent(
      widget.settings,
      'dusk_glow',
      BreakOverlayTheme.dusk,
      honorClockColor: false,
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final phase = DuskGlowTemplate.moonPhaseName(_age);

    return BreakScaffold(
      palette: BreakPalette.twilight,
      canvas: BreakPalette.twilight.canvas,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: CustomPaint(
        painter: _DuskPainter(drift: _drift, glow: accent),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreakEntrance(
              child: Semantics(
                label: phase,
                excludeSemantics: true,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(36, 36),
                    painter: _MoonPainter(age: _age, color: accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                color: breakClockColor(widget.settings, BreakPalette.twilight),
              ),
            ),
            const SizedBox(height: 12),
            BreakEntrance(
              delay: BreakEntrance.stagger(2),
              scale: false,
              // The break's own label; never the end-of-day "Wind down" copy.
              child: BreakLabel(
                '${_kind.label} · ${breakDurationLabel(widget.totalSeconds)}',
                color: BreakPalette.twilight.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            BreakEntrance(
              delay: BreakEntrance.stagger(3),
              scale: false,
              child: SizedBox(
                width: 240,
                height: 2,
                child: BreakSmoothProgress(
                  progress: progress,
                  builder: (context, anim) => CustomPaint(
                    painter: _LinePainter(
                      progress: anim,
                      color: accent,
                      track: BreakPalette.twilight.track,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;
  final Color track;

  _LinePainter({
    required this.progress,
    required this.color,
    required this.track,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    p.color = track;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    p.color = color;
    canvas.drawLine(Offset(0, y), Offset(size.width * progress.value, y), p);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.color != color || old.track != track;
}

/// Sky gradient, horizon glow and two slowly drifting aurora curtains.
class _DuskPainter extends CustomPainter {
  final Animation<double> drift;
  final Color glow;

  final Paint _sky = Paint();
  final Paint _horizon = Paint();
  final Paint _curtain = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);
  final Path _path = Path();

  _DuskPainter({required this.drift, required this.glow})
    : super(repaint: drift);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    _sky.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1B1530), Color(0xFF3B2D5C)],
    ).createShader(full);
    canvas.drawRect(full, _sky);

    _horizon.shader = RadialGradient(
      center: const Alignment(0, 1.0),
      radius: 0.9,
      colors: [glow.withValues(alpha: 0.15), glow.withValues(alpha: 0)],
    ).createShader(full);
    canvas.drawRect(full, _horizon);

    // Two curtains: (hue, alpha, wave count, speed, top as share of height).
    const curtains = [
      (Color(0xFF8B7CF6), 0.14, 1.4, 1.0, 0.20),
      (Color(0xFF5EC3C8), 0.09, 2.2, -1.0, 0.32),
    ];
    for (final c in curtains) {
      final shift = drift.value * 2 * math.pi * c.$4;
      final top = size.height * c.$5;
      _path
        ..reset()
        ..moveTo(0, top + size.height * 0.45);
      for (var i = 0; i <= 48; i++) {
        final t = i / 48;
        final y =
            top + math.sin(t * math.pi * 2 * c.$3 + shift) * size.height * 0.06;
        _path.lineTo(size.width * t, y);
      }
      _path
        ..lineTo(size.width, top + size.height * 0.45)
        ..close();
      _curtain.shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.$1.withValues(alpha: c.$2),
              c.$1.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              top - size.height * 0.08,
              size.width,
              size.height * 0.6,
            ),
          );
      canvas.drawPath(_path, _curtain);
    }
  }

  @override
  bool shouldRepaint(covariant _DuskPainter old) => old.glow != glow;
}

/// The moon at its real phase: a dim full disc, the lit part drawn from a
/// limb arc and a terminator arc, and a soft glow behind.
class _MoonPainter extends CustomPainter {
  final double age;
  final Color color;

  _MoonPainter({required this.age, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const synodic = 29.530588853;
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final theta = 2 * math.pi * age / synodic;
    final waxing = theta <= math.pi;
    // Mirror the waning half so one path serves both.
    final t = waxing ? theta : 2 * math.pi - theta;
    final lit = (1 - math.cos(theta)) / 2;

    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()
        ..color = color.withValues(alpha: 0.10 + 0.25 * lit)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.14));

    final rx = r * math.cos(t); // terminator x-extent, signed
    final path = Path()
      ..moveTo(0, -r)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: r),
        -math.pi / 2,
        math.pi,
        false,
      );
    if (rx.abs() < 0.5) {
      path.lineTo(0, -r);
    } else {
      path.arcTo(
        Rect.fromCenter(
          center: Offset.zero,
          width: 2 * rx.abs(),
          height: 2 * r,
        ),
        math.pi / 2,
        rx > 0 ? -math.pi : math.pi,
        false,
      );
    }
    path.close();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (!waxing) canvas.scale(-1, 1);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MoonPainter old) =>
      old.age != age || old.color != color;
}
