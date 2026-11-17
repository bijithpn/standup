import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

import '../motion_kit.dart';
import '../wellness_models.dart';
import '../wellness_template.dart';

const _ink = Color(0xFF1D1B19);
const _vermilion = Color(0xFFB8412E);

final _seed = stableSeed('zen_ink');
final _phase1 = (_seed % 628) / 100;
final _phase2 = (_seed % 311) / 50;

const _startAngle = math.pi * 0.75;
const _sweep = math.pi * 2 * 1.03;

double _angle(double s) => _startAngle + s * _sweep;

double _radius(double s) {
  final a = _angle(s);
  return 1 +
      0.028 * math.sin(2 * a + _phase1) +
      0.018 * math.sin(3 * a + _phase2) +
      0.045 * s;
}

// Brush loads thick at the start and thins out; the lifted tip is pointed.
double _halfWidth(double s, double tipAt) {
  final body = 1 - 0.62 * math.pow(s, 1.4);
  final tip = math.sqrt(((tipAt - s) / 0.04).clamp(0.0, 1.0));
  final heel = (0.35 + s / 0.015).clamp(0.0, 1.0);
  return 0.09 * body * tip * heel;
}

// off/wf are relative to the main stroke's half width; s0..s1 is the dry-brush span.
typedef _Layer = (double off, double wf, double alpha, double s0, double s1);

const _layers = <_Layer>[
  (0, 1, 0.82, 0, 1),
  (-0.18, 0.55, 0.3, 0.02, 0.9),
  (0.22, 0.35, 0.26, 0.05, 0.75),
  (0.34, 0.12, 0.35, 0, 0.6),
  (-0.4, 0.08, 0.3, 0.1, 0.95),
  (1.12, 0.05, 0.28, 0.08, 0.7),
];

Path _ribbon(
  Offset c,
  double r,
  double rot,
  _Layer l,
  double reveal,
  double wobble,
  int index,
) {
  final s1 = math.min(l.$5, reveal);
  if (s1 <= l.$4 + 0.005) return Path();
  final m = math.max(4, ((s1 - l.$4) * 220).ceil());
  final shift = l.$1 + wobble * math.sin(index * 2.1 + 1);
  final outer = <Offset>[], inner = <Offset>[];
  for (var i = 0; i <= m; i++) {
    final s = l.$4 + (s1 - l.$4) * i / m;
    final hw = _halfWidth(s, reveal);
    final centre = _radius(s) + shift * 0.09;
    final a = _angle(s) + rot;
    final d = Offset(math.cos(a), math.sin(a));
    outer.add(c + d * r * (centre + hw * l.$2));
    inner.add(c + d * r * (centre - hw * l.$2));
  }
  final path = Path()..moveTo(outer.first.dx, outer.first.dy);
  for (final p in outer.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in inner.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

ui.Picture? _grainPicture;
Size? _grainSize;

// Painted once per size from a fixed seed; never regenerated per frame.
ui.Picture _grain(Size z) {
  if (_grainSize == z && _grainPicture != null) return _grainPicture!;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  var x = _seed;
  double next() {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    return x / 0x7fffffff;
  }

  final n = (z.width * z.height / 700).clamp(400, 6000).toInt();
  for (final (color, alpha) in [(_ink, 0.05), (Colors.white, 0.35)]) {
    final pts = Float32List(n * 2);
    for (var i = 0; i < pts.length; i += 2) {
      pts[i] = next() * z.width;
      pts[i + 1] = next() * z.height;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      pts,
      Paint()
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: alpha),
    );
  }
  _grainSize = z;
  return _grainPicture = rec.endRecording();
}

/// Japanese-inspired enso brushed in ink; the stroke is the progress.
class ZenInkTemplate extends WellnessTemplate {
  const ZenInkTemplate();

  @override
  String get id => 'zen_ink';
  @override
  String get name => 'Zen ink';
  @override
  String get description =>
      'An enso drawn in ink that closes as the break completes.';

  @override
  BreakPalette get palette => const BreakPalette(
    canvas: Color(0xFFF0E9DA),
    canvasRaised: Color(0xFFF6F0E3),
    surface: Color(0xFFFBF7EC),
    border: Color(0x1A1D1B19),
    track: Color(0x1F1D1B19),
    textPrimary: Color(0xFF1D1B19),
    textSecondary: Color(0xFF4F4A42),
    textMuted: Color(0xFF6E675C),
    isDark: false,
  );

  @override
  Widget immersive(BuildContext context, BreakSession s, MotionClock clock) {
    final p = palette;
    return ColoredBox(
      color: p.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _EnsoPainter(s, clock, compact: false),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.08),
            child: Semantics(
              label: spokenRemaining(s.remainingSeconds),
              child: ExcludeSemantics(
                child: Text(
                  formatRemaining(s.remainingSeconds),
                  style: TextStyle(
                    fontFamily: BreakOverlayTheme.monoFamily,
                    fontSize: 28,
                    color: p.textPrimary,
                    fontFeatures: BreakOverlayTheme.tabular,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: BreakOverlayTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.focus == BreakFocus.eyes
                          ? 'Look away from the screen, at something far off.'
                          : s.instruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: BreakOverlayTheme.fontFamily,
                        fontSize: 14,
                        height: 1.5,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget compactArt(BuildContext context, BreakSession s, MotionClock clock) =>
      RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _EnsoPainter(s, clock, compact: true),
        ),
      );

  @override
  Widget reminderArt(
    BuildContext context,
    ReminderKind kind,
    MotionClock clock,
  ) => RepaintBoundary(
    child: CustomPaint(
      size: const Size(40, 40),
      painter: _MarkPainter(kind, clock),
    ),
  );
}

class _EnsoPainter extends CustomPainter {
  _EnsoPainter(this.s, this.clock, {required this.compact})
    : super(repaint: clock);
  final BreakSession s;
  final MotionClock clock;
  final bool compact;

  @override
  void paint(Canvas c, Size z) {
    final t = clock.value;
    final p = s.progressAt(s.startedAtMs + (t * 1000).round());
    final a = Motion.amp(s.tier, s.intensity);
    final settle = 1 - easeInOut(((p - 0.9) / 0.1).clamp(0.0, 1.0));
    final u = math.min(z.width, z.height);
    final centre = compact
        ? z.center(Offset.zero)
        : Offset(z.width / 2, z.height * 0.46);
    final r =
        u *
        (compact ? 0.34 : 0.27) *
        (1 + 0.012 * a * settle * Motion.breathe(t, 8));
    final rot = Motion.pendulum(t, 48, 0.1 * a * settle);
    final wobble = 0.08 * a * settle * Motion.noise(t, _seed, 18);
    final fade = 1 + 0.05 * a * settle * Motion.noise(t, _seed + 1, 23);

    if (!compact) c.drawPicture(_grain(z));

    final ghost = Paint()..color = _ink.withValues(alpha: 0.08);
    c.drawPath(_ribbon(centre, r, rot, _layers[0], 1, 0, 0), ghost);

    if (p > 0.005) {
      for (var i = 0; i < _layers.length; i++) {
        c.drawPath(
          _ribbon(centre, r, rot, _layers[i], p, wobble, i),
          Paint()
            ..color = _ink.withValues(
              alpha: (_layers[i].$3 * fade).clamp(0.0, 1.0),
            ),
        );
      }
    }

    if (!compact) {
      final seal = centre + Offset(r * 1.2, r * 0.95);
      final side = u * 0.034;
      c.save();
      c.translate(seal.dx, seal.dy);
      c.rotate(-0.05);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
          Radius.circular(side * 0.12),
        ),
        Paint()..color = _vermilion,
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_EnsoPainter old) => old.s != s || old.compact != compact;
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.kind, this.clock) : super(repaint: clock);
  final ReminderKind kind;
  final MotionClock clock;

  @override
  void paint(Canvas c, Size z) {
    final a = Motion.amp(clock.tier, 0.6);
    final centre = z.center(Offset.zero);
    final reveal = switch (kind) {
      ReminderKind.hydration => 0.86,
      ReminderKind.stretch => 0.78,
      ReminderKind.eyes => 0.9,
      ReminderKind.posture => 0.82,
      ReminderKind.standup => 0.75,
      ReminderKind.mindful => 0.96,
    };
    final rot = Motion.pendulum(clock.value, 12, 0.3 * a);
    c.drawPath(
      _ribbon(centre, 14, rot, _layers[0], reveal, 0, 0),
      Paint()..color = _ink.withValues(alpha: 0.85),
    );
    final inner = Paint()..color = _ink.withValues(alpha: 0.8);
    switch (kind) {
      case ReminderKind.hydration:
        c.drawPath(
          Path()
            ..moveTo(centre.dx, centre.dy - 4)
            ..cubicTo(
              centre.dx + 4,
              centre.dy,
              centre.dx + 4,
              centre.dy + 4,
              centre.dx,
              centre.dy + 4,
            )
            ..cubicTo(
              centre.dx - 4,
              centre.dy + 4,
              centre.dx - 4,
              centre.dy,
              centre.dx,
              centre.dy - 4,
            ),
          inner,
        );
      case ReminderKind.eyes:
        c.drawCircle(centre, 2.5, inner);
      default:
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.kind != kind;
}
