import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

import '../motion_kit.dart';
import '../wellness_models.dart';
import '../wellness_template.dart';

const _accent = Color(0xFF0E7C86);
const _muted = Color(0xFF6B7280);
final _seed = stableSeed('flowline');
const _samples = 240;

/// Purely decorative curve in normalized coordinates; carries no data.
double _wave(double u, double freq) {
  final p1 = (_seed % 100) / 100,
      p2 = (_seed % 37) / 37,
      p3 = (_seed % 53) / 53;
  final envelope = math.pow(math.sin(math.pi * u), 0.4);
  return envelope *
      (0.55 * math.sin(2 * math.pi * (1.15 * freq * u + p1)) +
          0.3 * math.sin(2 * math.pi * (2.4 * freq * u + p2)) +
          0.15 * math.sin(2 * math.pi * (0.6 * freq * u + p3)));
}

class _Geo {
  _Geo(Size z, bool compact) {
    const pad = 8.0;
    final cy = z.height / 2, amp = z.height * (compact ? 0.3 : 0.3);
    final freq = compact ? 0.7 : 1.0;
    final path = Path();
    for (var i = 0; i < _samples; i++) {
      final u = i / (_samples - 1);
      final y = cy + _wave(u, freq) * amp;
      ys.add(y);
      final x = pad + (z.width - 2 * pad) * u;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    this.path = path;
    metric = path.computeMetrics().first;
    left = pad;
    span = z.width - 2 * pad;
  }

  late final Path path;
  late final PathMetric metric;
  late final double left, span;
  final ys = <double>[];

  double yAt(double p) {
    final f = p * (_samples - 1);
    final i = f.floor().clamp(0, _samples - 2);
    return ys[i] + (ys[i + 1] - ys[i]) * (f - i);
  }
}

final _cache = <(Size, bool), _Geo>{};

_Geo _geo(Size z, bool compact) {
  if (_cache.length > 4) _cache.clear();
  return _cache.putIfAbsent((z, compact), () => _Geo(z, compact));
}

/// Time as a wave: one thin line, one marker travelling along it.
class FlowlineTemplate extends WellnessTemplate {
  const FlowlineTemplate();

  @override
  String get id => 'flowline';
  @override
  String get name => 'Flowline';
  @override
  String get description =>
      'A single line and a quiet marker that carries you to the end.';

  @override
  BreakPalette get palette => const BreakPalette(
    canvas: Color(0xFFF6F7F9),
    canvasRaised: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    border: Color(0x1A111827),
    track: Color(0x1F111827),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textMuted: _muted,
    isDark: false,
  );

  @override
  Widget immersive(BuildContext context, BreakSession s, MotionClock clock) {
    final p = palette;
    return ColoredBox(
      color: p.canvas,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: WellnessType.label(p)),
            const SizedBox(height: 8),
            Semantics(
              label: spokenRemaining(s.remainingSeconds),
              child: ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatRemaining(s.remainingSeconds),
                    style: TextStyle(
                      fontFamily: BreakOverlayTheme.monoFamily,
                      fontSize: 112,
                      height: 1.1,
                      color: p.textPrimary,
                      fontFeatures: BreakOverlayTheme.tabular,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(s.instruction, style: WellnessType.instruction(p)),
            Expanded(
              child: RepaintBoundary(
                child: ExcludeSemantics(
                  child: SizedBox.expand(
                    child: CustomPaint(
                      painter: _FlowPainter(s, clock, compact: false),
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

  @override
  Widget compactArt(BuildContext context, BreakSession s, MotionClock clock) =>
      RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _FlowPainter(s, clock, compact: true),
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

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.s, this.clock, {required this.compact})
    : super(repaint: clock);
  final BreakSession s;
  final MotionClock clock;
  final bool compact;

  @override
  void paint(Canvas c, Size z) {
    final g = _geo(z, compact);
    final t = clock.value;
    final p = s.progressAt(s.startedAtMs + (t * 1000).round());
    final a = Motion.amp(s.tier, s.intensity);
    final cy = z.height / 2;

    c.save();
    c.translate(0, cy + Motion.noise(t, _seed, 14) * z.height * 0.012 * a);
    c.scale(1, 1 + 0.05 * Motion.noise(t, _seed + 1, 19) * a);
    c.translate(0, -cy);

    c.drawPath(
      g.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1 : 1.25
        ..color = _muted.withValues(alpha: 0.4),
    );
    if (p > 0) {
      c.drawPath(
        g.metric.extractPath(0, g.metric.length * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = compact ? 1.75 : 2.5
          ..color = _accent,
      );
    }

    final pos = Offset(g.left + g.span * p, g.yAt(p));
    final r = compact ? 3.5 : 6.0;
    final live = !s.complete && !s.paused && p < 1;
    final halo =
        (compact ? 6.0 : 11.0) + (live ? 3 * a * Motion.breathe(t, 3) : 0);
    c.drawCircle(pos, halo, Paint()..color = _accent.withValues(alpha: 0.2));
    c.drawCircle(pos, r, Paint()..color = _accent);
    c.restore();
  }

  @override
  bool shouldRepaint(_FlowPainter old) => old.s != s || old.compact != compact;
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.kind, this.clock) : super(repaint: clock);
  final ReminderKind kind;
  final MotionClock clock;

  @override
  void paint(Canvas c, Size z) {
    final freq = switch (kind) {
      ReminderKind.hydration => 1.0,
      ReminderKind.stretch => 1.5,
      ReminderKind.eyes => 0.75,
      ReminderKind.posture => 0.5,
      ReminderKind.standup => 1.25,
      ReminderKind.mindful => 0.9,
    };
    Offset at(double u) => Offset(4 + 32 * u, 20 + 9 * _wave(u, freq));
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i <= 32; i++) {
      final o = at(i / 32);
      path.lineTo(o.dx, o.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5
        ..color = _muted.withValues(alpha: 0.55),
    );
    final a = Motion.amp(clock.tier, 0.6);
    final o = at(
      0.7 + 0.2 * math.sin(Motion.rotation(clock.value, 8)) * (a > 0 ? 1 : 0),
    );
    final paint = Paint()..color = _accent;
    if (kind == ReminderKind.hydration) {
      c.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - 5)
          ..cubicTo(o.dx + 4, o.dy, o.dx + 4, o.dy + 4, o.dx, o.dy + 4)
          ..cubicTo(o.dx - 4, o.dy + 4, o.dx - 4, o.dy, o.dx, o.dy - 5),
        paint,
      );
    } else {
      c.drawCircle(o, 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.kind != kind;
}
