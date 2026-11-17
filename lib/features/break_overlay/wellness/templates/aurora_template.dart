import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';

class AuroraTemplate extends WellnessTemplate {
  const AuroraTemplate();

  static const _palette = BreakPalette(
    canvas: Color(0xFF071A26),
    canvasRaised: Color(0xFF0C2433),
    surface: Color(0xFF10303F),
    border: Color(0x1FFFFFFF),
    track: Color(0x24FFFFFF),
    textPrimary: Color(0xFFE8F3F5),
    textSecondary: Color(0xFFB4CCD3),
    textMuted: Color(0xFF93B0BA),
    isDark: true,
  );

  @override
  String get id => 'aurora';
  @override
  String get name => 'Aurora Flow';
  @override
  String get description => 'Slow light drifting over a deep ocean sky.';
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
                painter: _AuroraPainter(clock, _Mode.full, s: s),
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
        painter: _AuroraPainter(clock, _Mode.strip, s: s),
      );

  @override
  Widget reminderArt(
    BuildContext context,
    ReminderKind kind,
    MotionClock clock,
  ) => CustomPaint(
    size: Size.infinite,
    painter: _AuroraPainter(clock, _Mode.mark, kind: kind.index),
  );
}

Widget _readout(BreakSession s) {
  const p = AuroraTemplate._palette;
  return Semantics(
    container: true,
    label: '${s.title}. ${spokenRemaining(s.remainingSeconds)} remaining',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.title,
              style: TextStyle(
                fontFamily: BreakOverlayTheme.fontFamily,
                fontSize: 15,
                letterSpacing: 0.2,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatRemaining(s.remainingSeconds),
                style: TextStyle(
                  fontFamily: BreakOverlayTheme.fontFamily,
                  fontSize: 128,
                  height: 1,
                  letterSpacing: -3,
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
                style: TextStyle(
                  fontFamily: BreakOverlayTheme.fontFamily,
                  fontSize: 16,
                  height: 1.5,
                  color: p.textSecondary,
                ),
              ),
            ),
            if (s.focus == BreakFocus.eyes) ...[
              const SizedBox(height: 8),
              Text(
                'Look at something far away.',
                style: TextStyle(
                  fontFamily: BreakOverlayTheme.fontFamily,
                  fontSize: 13,
                  color: p.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

enum _Mode { full, strip, mark }

class _Band {
  const _Band(this.y, this.h, this.color, this.seed, this.alpha);
  final double y, h, alpha;
  final Color color;
  final int seed;
}

const _bands = [
  _Band(0.30, 0.30, Color(0xFF1F9AA0), 11, 0.30),
  _Band(0.45, 0.28, Color(0xFF2A6F9E), 23, 0.26),
  _Band(0.58, 0.26, Color(0xFF8C84C8), 37, 0.18),
  _Band(0.72, 0.22, Color(0xFF3FB5B0), 41, 0.14),
];

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.clock, this.mode, {this.s, this.kind = 0})
    : super(repaint: clock);

  final MotionClock clock;
  final _Mode mode;
  final BreakSession? s;
  final int kind;

  Size? _size;
  late Paint _bg, _glow;
  late List<Paint> _paints;

  List<_Band> get _used => mode == _Mode.full ? _bands : [_bands[0], _bands[2]];

  void _build(Size size) {
    final rect = Offset.zero & size;
    _bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A2234), Color(0xFF04121C)],
      ).createShader(rect);
    _glow = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.55, -0.6),
        radius: 0.7,
        colors: [Color(0x248C84C8), Color(0x008C84C8)],
      ).createShader(rect);
    _paints = [
      for (final b in _used)
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  b.color.withValues(alpha: 0),
                  b.color.withValues(alpha: b.alpha),
                  b.color.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromLTRB(
                  0,
                  b.y * size.height,
                  size.width,
                  (b.y + b.h) * size.height,
                ),
              ),
    ];
    _size = size;
  }

  Path _ribbon(_Band b, Size size, double t, double m, double p, double freq) {
    const n = 6;
    final w = size.width, h = size.height;
    final seed = b.seed + kind * 5;
    final top = <Offset>[], bottom = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = w * (-0.15 + 1.3 * i / (n - 1));
      final y =
          h * (b.y - 0.04 * p) +
          h * 0.09 * math.sin(i * 1.4 * freq + seed) +
          m * h * 0.05 * Motion.noise(t, seed + i, 45);
      top.add(Offset(x, y));
      bottom.add(
        Offset(
          x,
          y +
              h * b.h * (1 + 0.15 * math.sin(i * 2.0 + seed)) +
              m * h * 0.03 * Motion.noise(t, seed * 3 + i, 60),
        ),
      );
    }
    return Motion.closedSpline([...top, ...bottom.reversed]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size) _build(size);
    final session = s;
    final t = clock.value;
    final p =
        session?.progressAt(session.startedAtMs + (t * 1000).round()) ?? 0.0;
    final tier = session?.tier ?? clock.tier;
    final settle = easeInOut((p - 0.85) / 0.15);
    final m = Motion.amp(tier, session?.intensity ?? 0.6) * (1 - 0.75 * settle);
    final freq = session?.focus == BreakFocus.stretch ? 1.3 : 1.0;
    final rect = Offset.zero & size;

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
    if (mode == _Mode.full) canvas.drawRect(rect, _glow);
    final used = _used;
    for (var i = 0; i < used.length; i++) {
      canvas.drawPath(_ribbon(used[i], size, t, m, p, freq), _paints[i]);
    }

    if (mode == _Mode.full && session?.focus == BreakFocus.hydration) {
      final f = m > 0 ? (t / 9) % 1 : 0.4;
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.82),
        12 + 70 * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFB4CCD3).withValues(alpha: 0.14 * (1 - f)),
      );
    }

    if (mode == _Mode.strip) {
      final y = size.height - 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..strokeWidth = 1.5
          ..color = const Color(0x1FFFFFFF),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * p, y),
        Paint()
          ..strokeWidth = 1.5
          ..color = const Color(0x993FB5B0),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.s != s || old.mode != mode || old.kind != kind;
}
