import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

import '../motion_kit.dart';
import '../wellness_models.dart';
import '../wellness_template.dart';

const _terracotta = Color(0xFFC2674A);
const _sage = Color(0xFF8FA58B);
const _charcoal = Color(0xFF33312E);
const _sand = Color(0xFFD9C7A3);

/// Floating geometry: a kinetic sculpture that comes to rest as the break ends.
class BalanceTemplate extends WellnessTemplate {
  const BalanceTemplate();

  @override
  String get id => 'balance';
  @override
  String get name => 'Balance';
  @override
  String get description =>
      'Floating geometry that settles into stillness as the break completes.';

  @override
  BreakPalette get palette => const BreakPalette(
    canvas: Color(0xFFF3EEE3),
    canvasRaised: Color(0xFFFAF6EC),
    surface: Color(0xFFFBF8F1),
    border: Color(0x1A2B2926),
    track: Color(0x1F2B2926),
    textPrimary: Color(0xFF2B2926),
    textSecondary: Color(0xFF57524A),
    textMuted: Color(0xFF70695E),
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
              child: CustomPaint(painter: _SculpturePainter(s, clock)),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(64, 0, 64, 56),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
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
                    const SizedBox(height: 16),
                    Text(
                      s.title,
                      style: TextStyle(
                        fontFamily: BreakOverlayTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.instruction,
                      style: TextStyle(
                        fontFamily: BreakOverlayTheme.fontFamily,
                        fontSize: 14,
                        height: 1.5,
                        color: p.textSecondary,
                      ),
                    ),
                    if (s.focus == BreakFocus.eyes) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Look away from the screen, at something far off.',
                        style: TextStyle(
                          fontFamily: BreakOverlayTheme.fontFamily,
                          fontSize: 13,
                          height: 1.4,
                          color: p.textMuted,
                        ),
                      ),
                    ],
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
          painter: _CompactPainter(s, clock),
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

Offset _hang(Offset from, double len, double angle) =>
    from + Offset(math.sin(angle), math.cos(angle)) * len;

Paint _stroke(double w, Color c) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..color = c;

Paint _fill(Color c) => Paint()..color = c;

/// Half sage, half sand; the split edge turns once per break.
void _splitDisc(Canvas c, Offset o, double r, double angle) {
  final rect = Rect.fromCircle(center: o, radius: r);
  c.drawCircle(o, r, _fill(_sand));
  c.drawArc(rect, angle, math.pi, true, _fill(_sage));
  c.drawCircle(
    o +
        Offset(math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)) *
            r *
            0.55,
    r * 0.12,
    _fill(_charcoal),
  );
}

double _progress(BreakSession s, MotionClock clock) =>
    s.progressAt(s.startedAtMs + (clock.value * 1000).round());

class _SculpturePainter extends CustomPainter {
  _SculpturePainter(this.s, this.clock) : super(repaint: clock);
  final BreakSession s;
  final MotionClock clock;

  @override
  void paint(Canvas c, Size z) {
    final w = z.width, h = z.height, u = math.min(w, h);
    final t = clock.value, p = _progress(s, clock);
    final moving = s.tier != MotionTier.still;
    final k = Motion.amp(s.tier, s.intensity) * (1 - easeInOut(p));
    final thin = _stroke(1, _charcoal.withValues(alpha: 0.55));

    final pivot = Offset(w * 0.66, h * 0.2);
    c.drawLine(Offset(pivot.dx, 0), pivot, thin);
    final beam = Motion.pendulum(t, 13, 0.14 * k);
    final dir = Offset(math.cos(beam), math.sin(beam)) * (w * 0.2);
    final e1 = pivot - dir, e2 = pivot + dir;
    c.drawLine(e1, e2, _stroke(1.5, _charcoal));
    c.drawCircle(pivot, 3, _fill(_charcoal));

    final b1 = _hang(
      e1,
      h * (0.26 + 0.05 * p),
      Motion.pendulum(t, 7.5, 0.09 * k, 0.2),
    );
    c.drawLine(e1, b1, thin);
    c.drawCircle(b1, u * 0.055, _fill(_terracotta));
    if (s.focus == BreakFocus.hydration && moving) {
      final r = (t / 6) % 1.0;
      c.drawCircle(
        b1,
        u * 0.055 * (1 + 0.9 * r),
        _stroke(1, _terracotta.withValues(alpha: 0.4 * (1 - r))),
      );
    }

    final b2 = _hang(e2, h * 0.36, Motion.pendulum(t, 9.5, 0.07 * k, 0.6));
    c.drawLine(e2, b2, thin);
    _splitDisc(c, b2, u * 0.1, p * 2 * math.pi);

    final a3 = Offset(w * 0.34, 0);
    final b3 = _hang(a3, h * 0.5, Motion.pendulum(t, 10, 0.2 * k, 0.3));
    c.drawLine(a3, b3, thin);
    c.drawCircle(b3, u * 0.028, _fill(_charcoal));
    c.drawCircle(b3, u * 0.06, _stroke(1, _charcoal.withValues(alpha: 0.4)));

    c.drawCircle(
      Offset(w * 0.22, h * 0.4) + Motion.float(t, 11, u * 0.015 * k),
      u * 0.04,
      _fill(_sand),
    );
    c.drawCircle(
      Offset(w * 0.78, h * 0.84) + Motion.float(t, 14, u * 0.012 * k, 0.5),
      u * 0.018,
      _stroke(1.5, _terracotta),
    );
  }

  @override
  bool shouldRepaint(_SculpturePainter old) => old.s != s;
}

class _CompactPainter extends CustomPainter {
  _CompactPainter(this.s, this.clock) : super(repaint: clock);
  final BreakSession s;
  final MotionClock clock;

  @override
  void paint(Canvas c, Size z) {
    final w = z.width, h = z.height;
    final t = clock.value, p = _progress(s, clock);
    final k = Motion.amp(s.tier, s.intensity) * (1 - easeInOut(p));
    final thin = _stroke(1, _charcoal.withValues(alpha: 0.55));

    final a1 = Offset(w * 0.2, 0);
    final b1 = _hang(a1, h * 0.62, Motion.pendulum(t, 6, 0.2 * k));
    c.drawLine(a1, b1, thin);
    c.drawCircle(b1, h * 0.09, _fill(_terracotta));

    final a2 = Offset(w * 0.5, 0);
    final b2 = _hang(a2, h * 0.52, Motion.pendulum(t, 8, 0.05 * k, 0.4));
    c.drawLine(a2, b2, thin);
    _splitDisc(c, b2, h * 0.28, p * 2 * math.pi);

    final ring = Offset(w * 0.8, h * 0.5) + Motion.float(t, 9, h * 0.06 * k);
    c.drawArc(
      Rect.fromCircle(center: ring, radius: h * 0.2),
      s.tier == MotionTier.still ? 0 : Motion.rotation(t, 60),
      math.pi * 1.25,
      false,
      _stroke(1.5, _sage),
    );
  }

  @override
  bool shouldRepaint(_CompactPainter old) => old.s != s;
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.kind, this.clock) : super(repaint: clock);
  final ReminderKind kind;
  final MotionClock clock;

  @override
  void paint(Canvas c, Size z) {
    final k = Motion.amp(clock.tier, 0.6);
    final a = Offset(z.width / 2, 0);
    final o = _hang(a, 14, Motion.pendulum(clock.value, 5, 0.25 * k));
    c.drawLine(a, o, _stroke(1, _charcoal.withValues(alpha: 0.55)));
    const r = 8.0;
    switch (kind) {
      case ReminderKind.hydration:
        final drop = Path()
          ..moveTo(o.dx, o.dy - r)
          ..cubicTo(o.dx + r, o.dy, o.dx + r, o.dy + r, o.dx, o.dy + r)
          ..cubicTo(o.dx - r, o.dy + r, o.dx - r, o.dy, o.dx, o.dy - r);
        c.drawPath(drop, _fill(_terracotta));
      case ReminderKind.stretch:
        c.drawArc(
          Rect.fromCircle(center: o, radius: r),
          math.pi * 0.9,
          math.pi * 1.2,
          false,
          _stroke(2, _sage),
        );
      case ReminderKind.eyes:
        c.drawOval(
          Rect.fromCenter(center: o, width: r * 2.4, height: r * 1.3),
          _fill(_sand),
        );
        c.drawCircle(o, r * 0.35, _fill(_charcoal));
      case ReminderKind.posture:
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: o, width: r * 0.9, height: r * 2),
            const Radius.circular(2),
          ),
          _fill(_sage),
        );
      case ReminderKind.standup:
        c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy - r)
            ..lineTo(o.dx + r, o.dy + r * 0.8)
            ..lineTo(o.dx - r, o.dy + r * 0.8)
            ..close(),
          _fill(_terracotta),
        );
      case ReminderKind.mindful:
        _splitDisc(c, o, r, Motion.rotation(clock.value, 30));
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.kind != kind;
}
