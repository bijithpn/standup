import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';

/// Configurable circular / open-arc progress indicator.
///
/// [size] is the ring's outer diameter. Ticks are drawn *outside* that box.
/// Progress interpolates smoothly between per-second updates; the painter
/// repaints through its animation, never through `setState`.
class BreakProgressRing extends StatefulWidget {
  /// Elapsed fraction, 0..1.
  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  /// Where the arc starts, radians. Default is 12 o'clock.
  final double startAngle;

  /// Angular extent of the whole ring. 2pi is a full circle; less is an open
  /// gauge.
  final double sweep;

  /// Outer ticks. Ticks that fall inside the elapsed range are lit with
  /// [color], the rest use [tickColor] (defaults to [trackColor]).
  final int tickCount;
  final double tickLength;
  final double tickWidth;
  final double tickGap;
  final Color? tickColor;

  /// When true, ticks that have *not* yet elapsed are lit and elapsed ticks
  /// fade to [tickColor] (a countdown). Default lights the elapsed ones.
  final bool ticksRemainingLit;

  /// Widen the last [taperDegrees] of the arc from [strokeWidth] to
  /// [taperTo], ending in a round cap.
  final double taperDegrees;
  final double taperTo;

  /// Fade the trailing [cometDegrees] of the arc up from transparent.
  final double cometDegrees;

  /// Halo around the head, 0..1 alpha.
  final double glow;

  /// Extra glow added briefly on completion, 0..1.
  final double flash;

  /// Interpolate progress between updates. Off for static frames.
  final bool smooth;
  final Widget? child;

  const BreakProgressRing({
    super.key,
    required this.progress,
    required this.size,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 3,
    this.startAngle = -math.pi / 2,
    this.sweep = math.pi * 2,
    this.tickCount = 0,
    this.tickLength = 6,
    this.tickWidth = 1.5,
    this.tickGap = 12,
    this.tickColor,
    this.ticksRemainingLit = false,
    this.taperDegrees = 0,
    this.taperTo = 4,
    this.cometDegrees = 0,
    this.glow = 0,
    this.flash = 0,
    this.smooth = true,
    this.child,
  });

  @override
  State<BreakProgressRing> createState() => _BreakProgressRingState();
}

class _BreakProgressRingState extends State<BreakProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: widget.progress.clamp(0.0, 1.0),
  );

  @override
  void didUpdateWidget(covariant BreakProgressRing old) {
    super.didUpdateWidget(old);
    final target = widget.progress.clamp(0.0, 1.0);
    if (target == _c.value) return;
    if (widget.smooth && target > _c.value && !breakShouldFreeze(context)) {
      _c.animateTo(
        target,
        duration: const Duration(seconds: 1),
        curve: Curves.linear,
      );
    } else {
      _c.value = target;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return RepaintBoundary(
      child: SizedBox(
        width: w.size,
        height: w.size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: _c,
            strokeWidth: w.strokeWidth,
            color: w.color,
            trackColor: w.trackColor,
            startAngle: w.startAngle,
            sweep: w.sweep,
            tickCount: w.tickCount,
            tickLength: w.tickLength,
            tickWidth: w.tickWidth,
            tickGap: w.tickGap,
            tickColor: w.tickColor ?? w.trackColor,
            ticksRemainingLit: w.ticksRemainingLit,
            taperDegrees: w.taperDegrees,
            taperTo: w.taperTo,
            cometDegrees: w.cometDegrees,
            glow: w.glow,
            flash: w.flash,
          ),
          child: w.child == null ? null : Center(child: w.child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Animation<double> progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final double startAngle;
  final double sweep;
  final int tickCount;
  final double tickLength;
  final double tickWidth;
  final double tickGap;
  final Color tickColor;
  final bool ticksRemainingLit;
  final double taperDegrees;
  final double taperTo;
  final double cometDegrees;
  final double glow;
  final double flash;

  final Paint _track = Paint()..style = PaintingStyle.stroke;
  final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _tick = Paint()..strokeCap = StrokeCap.round;
  final Paint _halo = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
    required this.startAngle,
    required this.sweep,
    required this.tickCount,
    required this.tickLength,
    required this.tickWidth,
    required this.tickGap,
    required this.tickColor,
    required this.ticksRemainingLit,
    required this.taperDegrees,
    required this.taperTo,
    required this.cometDegrees,
    required this.glow,
    required this.flash,
  }) : super(repaint: progress);

  static const int _segments = 10;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = progress.value.clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    _track
      ..strokeWidth = strokeWidth
      ..strokeCap = sweep < math.pi * 2 ? StrokeCap.round : StrokeCap.butt
      ..color = trackColor;
    canvas.drawArc(rect, startAngle, sweep, false, _track);

    if (tickCount > 0) _paintTicks(canvas, center, radius, p);

    final lit = sweep * p;
    if (lit <= 0) return;

    final taper = math.min(taperDegrees * math.pi / 180, lit);
    final comet = math.min(cometDegrees * math.pi / 180, lit - taper);
    final bodyEnd = lit - taper - (comet > 0 ? comet : 0);

    _arc.strokeWidth = strokeWidth;
    if (bodyEnd > 0) {
      _arc.color = comet > 0 ? color.withValues(alpha: 0.35) : color;
      canvas.drawArc(rect, startAngle, bodyEnd, false, _arc);
    }
    if (comet > 0) {
      final step = comet / _segments;
      for (var i = 0; i < _segments; i++) {
        final t = (i + 1) / _segments;
        _arc.color = color.withValues(alpha: 0.35 + 0.65 * t);
        canvas.drawArc(
          rect,
          startAngle + bodyEnd + step * i,
          step * 1.05,
          false,
          _arc,
        );
      }
    }
    if (taper > 0) {
      final begin = startAngle + lit - taper;
      final step = taper / _segments;
      _arc.color = color;
      for (var i = 0; i < _segments; i++) {
        final t = (i + 1) / _segments;
        _arc.strokeWidth = strokeWidth + (taperTo - strokeWidth) * t;
        canvas.drawArc(rect, begin + step * i, step * 1.05, false, _arc);
      }
    }

    final haloAlpha = (glow + flash).clamp(0.0, 1.0);
    if (haloAlpha > 0) {
      final a = startAngle + lit;
      final head = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      _halo.color = color.withValues(alpha: haloAlpha * 0.6);
      canvas.drawCircle(head, strokeWidth * 2.2 + flash * 6, _halo);
    }
  }

  void _paintTicks(Canvas canvas, Offset center, double radius, double p) {
    final inner = radius + strokeWidth / 2 + tickGap;
    final outer = inner + tickLength;
    _tick.strokeWidth = tickWidth;
    final litCount = (p * tickCount).floor();
    final full = sweep >= math.pi * 2 - 1e-6;
    final n = full ? tickCount : tickCount - 1;
    for (var i = 0; i < tickCount; i++) {
      final a = startAngle + sweep * (n == 0 ? 0 : i / n);
      final cs = math.cos(a);
      final sn = math.sin(a);
      if (ticksRemainingLit) {
        // Elapsed ticks fade from the accent to the track colour.
        final e = (p * tickCount - i).clamp(0.0, 1.0);
        _tick.color = Color.lerp(color, tickColor, e)!;
      } else {
        _tick.color = i < litCount ? color : tickColor;
      }
      canvas.drawLine(
        Offset(center.dx + cs * inner, center.dy + sn * inner),
        Offset(center.dx + cs * outer, center.dy + sn * outer),
        _tick,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.startAngle != startAngle ||
      old.sweep != sweep ||
      old.tickCount != tickCount ||
      old.tickLength != tickLength ||
      old.tickWidth != tickWidth ||
      old.tickGap != tickGap ||
      old.tickColor != tickColor ||
      old.ticksRemainingLit != ticksRemainingLit ||
      old.taperDegrees != taperDegrees ||
      old.taperTo != taperTo ||
      old.cometDegrees != cometDegrees ||
      old.glow != glow ||
      old.flash != flash;
}
