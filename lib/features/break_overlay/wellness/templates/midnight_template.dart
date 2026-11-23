import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';
import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';

class MidnightTemplate extends WellnessTemplate {
  const MidnightTemplate();

  static const _palette = BreakPalette(
    canvas: Color(0xFF080C16),
    canvasRaised: Color(0xFF0C1220),
    surface: Color(0xFF111A2B),
    border: Color(0x1AFFFFFF),
    track: Color(0x24C8D0E0),
    textPrimary: Color(0xFFC9D1E0),
    textSecondary: Color(0xFFA9B3C6),
    textMuted: Color(0xFF8C97AC),
    isDark: true,
  );

  @override
  String get id => 'midnight';
  @override
  String get name => 'Midnight Drift';
  @override
  String get description => 'A quiet night sky with a slowly orbiting moon.';
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
                painter: _MidnightPainter(clock, _Mode.full, s: s),
              ),
            ),
          ),
          Align(alignment: const Alignment(0, 0.86), child: _readout(s)),
        ],
      );

  @override
  Widget compactArt(BuildContext context, BreakSession s, MotionClock clock) =>
      CustomPaint(
        size: Size.infinite,
        painter: _MidnightPainter(clock, _Mode.strip, s: s),
      );

  @override
  Widget reminderArt(
    BuildContext context,
    ReminderKind kind,
    MotionClock clock,
  ) => CustomPaint(
    size: Size.infinite,
    painter: _MidnightPainter(clock, _Mode.mark, kind: kind.index),
  );
}

Widget _readout(BreakSession s) {
  const p = MidnightTemplate._palette;
  return Semantics(
    container: true,
    label: '${s.title}. ${spokenRemaining(s.remainingSeconds)} remaining',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatRemaining(s.remainingSeconds),
                style: TextStyle(
                  fontFamily: BreakOverlayTheme.monoFamily,
                  fontSize: 56,
                  height: 1,
                  color: p.textPrimary,
                  fontFeatures: BreakOverlayTheme.tabular,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(s.title, style: WellnessType.label(p)),
            const SizedBox(height: 4),
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

typedef _Star = ({double x, double y, double r, int layer, double phase});

List<_Star> _makeStars(int n) {
  var x = stableSeed('midnight');
  double next() {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    return x / 0x7fffffff;
  }

  return [
    for (var i = 0; i < n; i++)
      (
        x: next(),
        y: next(),
        r: 0.6 + next() * 0.8,
        layer: i.isEven ? 0 : 1,
        phase: next(),
      ),
  ];
}

final _stars = _makeStars(40);
final _starsSmall = _makeStars(10);

const _silver = Color(0xFFC9D1E0);

class _MidnightPainter extends CustomPainter {
  _MidnightPainter(this.clock, this.mode, {this.s, this.kind = 0})
    : super(repaint: clock);

  final MotionClock clock;
  final _Mode mode;
  final BreakSession? s;
  final int kind;

  Size? _size;
  late Paint _bg;

  void _build(Size size) {
    final rect = Offset.zero & size;
    var top = const Color(0xFF0B1326), bottom = const Color(0xFF060A14);
    if (s?.timeOfDay ?? false) {
      final tint = breakEveningTint(DateTime.now()) * 0.5;
      const warm = Color(0xFF1A1512);
      top = Color.lerp(top, warm, tint)!;
      bottom = Color.lerp(bottom, warm, tint)!;
    }
    _bg = Paint()
      ..shader = mode == _Mode.mark
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ).createShader(rect);
    if (mode == _Mode.mark) _bg.color = top;
    _size = size;
  }

  void _moon(Canvas canvas, Offset c, double r, double f, double lit) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF161E32));
    final k = math.cos(math.pi * f);
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..arcTo(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi,
        false,
      )
      ..arcTo(
        Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r),
        math.pi / 2,
        k > 0 ? -math.pi : math.pi,
        false,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFD6DCE8).withValues(alpha: lit),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _silver.withValues(alpha: 0.12),
    );
  }

  void _drawStars(Canvas canvas, Size size, double t, double m, Rect area) {
    final list = switch (mode) {
      _Mode.full => _stars,
      _Mode.strip => _starsSmall,
      _Mode.mark => _starsSmall.take(4).toList(),
    };
    final paint = Paint();
    for (final st in list) {
      final dx = t * 0.06 * (st.layer + 1) * m;
      final x = (st.x * area.width + dx) % area.width;
      final tw =
          0.85 + 0.15 * m.sign * math.sin(2 * math.pi * (t * 0.04 + st.phase));
      paint.color = _silver.withValues(
        alpha: (st.layer == 0 ? 0.35 : 0.6) * tw,
      );
      canvas.drawCircle(Offset(x, st.y * area.height), st.r, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final session = s;
    final t = clock.value;
    final p =
        session?.progressAt(session.startedAtMs + (t * 1000).round()) ?? 0.0;
    final tier = session?.tier ?? clock.tier;
    final settle = easeInOut((p - 0.9) / 0.1);
    final m = Motion.amp(tier, session?.intensity ?? 0.6);
    final rect = Offset.zero & size;
    final minSide = math.min(size.width, size.height);
    final c = mode == _Mode.full
        ? Offset(size.width / 2, size.height * 0.40)
        : size.center(Offset.zero);
    final big = mode == _Mode.full
        ? math.min(size.width * 0.42, size.height * 0.30)
        : minSide * 0.4;
    final rm = mode == _Mode.full
        ? big * 0.22
        : (mode == _Mode.strip ? 7.0 : 8.0);
    if (_size != size) _build(size);

    canvas.save();
    switch (mode) {
      case _Mode.mark:
        canvas.clipPath(Path()..addOval(rect));
      case _Mode.strip:
        canvas.clipRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        );
      case _Mode.full:
        break;
    }
    canvas.drawRect(rect, _bg);
    _drawStars(canvas, size, t, m, rect);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _silver.withValues(alpha: 0.14 * (1 - 0.4 * settle));

    switch (mode) {
      case _Mode.full:
        canvas.drawCircle(c, big, ring);
        final a = -math.pi / 2;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: big),
          a,
          2 * math.pi * p,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round
            ..color = _silver.withValues(alpha: 0.4 * (1 - 0.4 * settle)),
        );
        canvas.drawCircle(
          c +
              Offset(
                    math.cos(a + 2 * math.pi * p),
                    math.sin(a + 2 * math.pi * p),
                  ) *
                  big,
          3.5,
          Paint()..color = _silver.withValues(alpha: 0.9 * (1 - 0.4 * settle)),
        );
        _moon(
          canvas,
          c,
          rm,
          0.35 + 0.4 * easeInOut(p),
          0.78 + 0.06 * Motion.breathe(t * m, 120),
        );
      case _Mode.strip:
        final rx = size.width * 0.3, ry = size.height * 0.3;
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 2 * rx, height: 2 * ry),
          ring,
        );
        canvas.drawCircle(
          c,
          1.5,
          Paint()..color = _silver.withValues(alpha: 0.5),
        );
        _moon(
          canvas,
          Motion.orbit(c, rx, ry, t * m, 80, 0.15 + 0.6 * p),
          rm,
          0.35 + 0.4 * easeInOut(p),
          0.8,
        );
        final y = size.height - 2;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()
            ..strokeWidth = 1.5
            ..color = const Color(0x1FC9D1E0),
        );
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width * p, y),
          Paint()
            ..strokeWidth = 1.5
            ..color = const Color(0x80C9D1E0),
        );
      case _Mode.mark:
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.5 + Motion.rotation(t * m, 600));
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 34, height: 12),
          ring,
        );
        canvas.restore();
        _moon(canvas, c, rm, 0.25 + kind * 0.1, 0.8);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MidnightPainter old) =>
      old.s != s || old.mode != mode || old.kind != kind;
}
