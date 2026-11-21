import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';

class LiquidTemplate extends WellnessTemplate {
  const LiquidTemplate();

  static const _palette = BreakPalette(
    canvas: Color(0xFFF6EFEA),
    canvasRaised: Color(0xFFFBF6F2),
    surface: Color(0xFFFFFFFF),
    border: Color(0x1A3B3330),
    track: Color(0x1F3B3330),
    textPrimary: Color(0xFF3A322E),
    textSecondary: Color(0xFF51473F),
    textMuted: Color(0xFF665B53),
    isDark: false,
  );

  @override
  String get id => 'liquid';
  @override
  String get name => 'Liquid Harmony';
  @override
  String get description => 'Soft pastel forms that drift and settle together.';
  @override
  BreakPalette get palette => _palette;

  @override
  Widget immersive(BuildContext context, BreakSession s, MotionClock clock) =>
      Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _LiquidPainter(clock, _Mode.full, s: s),
              ),
            ),
          ),
          Center(child: _readout(s)),
        ],
      );

  @override
  Widget compactArt(BuildContext context, BreakSession s, MotionClock clock) =>
      CustomPaint(
        size: Size.infinite,
        painter: _LiquidPainter(clock, _Mode.strip, s: s),
      );

  @override
  Widget reminderArt(
    BuildContext context,
    ReminderKind kind,
    MotionClock clock,
  ) => CustomPaint(
    size: Size.infinite,
    painter: _LiquidPainter(clock, _Mode.mark, kind: kind),
  );
}

Widget _readout(BreakSession s) {
  const p = LiquidTemplate._palette;
  return Semantics(
    container: true,
    label: '${s.title}. ${spokenRemaining(s.remainingSeconds)} remaining',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.title, style: WellnessType.label(p)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatRemaining(s.remainingSeconds),
                style: TextStyle(
                  fontFamily: BreakOverlayTheme.fontFamily,
                  fontSize: 104,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  color: p.textPrimary,
                  fontFeatures: BreakOverlayTheme.tabular,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                s.instruction,
                textAlign: TextAlign.center,
                style: WellnessType.instruction(p),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

enum _Mode { full, strip, mark }

class _Blob {
  const _Blob(this.home, this.rest, this.r, this.color, this.seed);
  final Offset home, rest;
  final double r;
  final Color color;
  final int seed;
}

const _blobs = [
  _Blob(Offset(0.16, 0.30), Offset(0.20, 0.62), 0.24, Color(0xFFF2C4A8), 3),
  _Blob(Offset(0.86, 0.72), Offset(0.80, 0.40), 0.20, Color(0xFFF0D9B8), 17),
];

const _kindColors = [
  Color(0xFFF2C4A8),
  Color(0xFFF0D9B8),
  Color(0xFFF2C4A8),
  Color(0xFFF0D9B8),
  Color(0xFFF2C4A8),
  Color(0xFFF0D9B8),
];

class _LiquidPainter extends CustomPainter {
  _LiquidPainter(this.clock, this.mode, {this.s, this.kind})
    : super(repaint: clock);

  final MotionClock clock;
  final _Mode mode;
  final BreakSession? s;
  final ReminderKind? kind;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final session = s;
    final tier = session?.tier ?? clock.tier;
    final t = clock.value * (tier == MotionTier.reduced ? 0.4 : 1);
    final p =
        session?.progressAt(
          session.startedAtMs + (clock.value * 1000).round(),
        ) ??
        0.0;
    final settle = easeInOut((p - 0.9) / 0.1);
    final m = Motion.amp(tier, session?.intensity ?? 0.6) * (1 - 0.7 * settle);
    final e = easeInOut(p);
    final w = size.width, h = size.height, side = math.min(w, h);
    final rect = Offset.zero & size;
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x59FFFFFF);

    void blob(
      Offset c,
      double r,
      _Blob b,
      double wobble, {
      double sx = 1,
      double sy = 1,
    }) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(sx, sy);
      final path = Motion.blob(
        Offset.zero,
        r,
        b.seed,
        t,
        wobble: wobble,
        period: 22 + b.seed.toDouble(),
      );
      canvas.drawPath(path, fill..color = b.color.withValues(alpha: 0.55));
      canvas.drawPath(path, edge);
      canvas.restore();
    }

    void ring(Offset c, double r, double alpha, Color color, double width) =>
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..color = color.withValues(alpha: alpha),
        );

    canvas.save();
    switch (mode) {
      case _Mode.full:
        final stretch = session?.focus == BreakFocus.stretch;
        for (var i = 0; i < _blobs.length; i++) {
          final b = _blobs[i];
          final pos = Offset.lerp(b.home, b.rest, e)!;
          final fl = Motion.float(
            t,
            18 + b.seed % 7,
            side * 0.02 * m,
            i.toDouble(),
          );
          blob(
            Offset(pos.dx * w + fl.dx, pos.dy * h + fl.dy),
            b.r * side,
            b,
            0.08 + 0.08 * m,
            sx: stretch ? 1.12 : 1,
            sy: stretch ? 0.92 : 1,
          );
        }
        if (session?.focus == BreakFocus.hydration) {
          final f = m > 0 ? (t / 5) % 1 : 0.4;
          final c = Offset.lerp(_blobs[1].home, _blobs[1].rest, e)!;
          ring(
            Offset(c.dx * w, c.dy * h),
            8 + 34 * f,
            0.3 * (1 - f),
            const Color(0xFF6FA8A6),
            1.2,
          );
        }
      case _Mode.strip:
        canvas.clipRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        );
        canvas.drawRect(
          rect,
          Paint()..color = LiquidTemplate._palette.canvasRaised,
        );
        final a = _blobs[0], b = _blobs[1];
        blob(
          Offset(w * (0.24 + 0.16 * e), h * 0.52),
          h * 0.5,
          a,
          0.08 + 0.08 * m,
        );
        blob(
          Offset(w * (0.70 - 0.14 * e), h * 0.46),
          h * 0.42,
          b,
          0.08 + 0.08 * m,
        );
        final y = h - 2;
        canvas.drawLine(
          Offset(0, y),
          Offset(w * p, y),
          Paint()
            ..strokeWidth = 1.5
            ..color = const Color(0x80C98A98),
        );
      case _Mode.mark:
        final k = kind ?? ReminderKind.mindful;
        final b = _Blob(
          Offset.zero,
          Offset.zero,
          0.4,
          _kindColors[k.index],
          3 + k.index * 4,
        );
        blob(size.center(Offset.zero), side * 0.34, b, 0.08 + 0.08 * m);
        if (k == ReminderKind.hydration) {
          final f = m > 0 ? (t / 5) % 1 : 0.5;
          ring(
            size.center(Offset.zero),
            side * 0.2 + side * 0.28 * f,
            0.4 * (1 - f),
            const Color(0xFF6FA8A6),
            1,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiquidPainter old) =>
      old.s != s || old.mode != mode || old.kind != kind;
}
