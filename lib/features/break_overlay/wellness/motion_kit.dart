import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'wellness_models.dart';

/// Ambient clock: seconds of phase, repainted at a capped frame rate.
/// One per visible artwork; stops when [tier] is still or the clock is
/// disposed. Painters take it as `repaint:` so no widget rebuilds happen.
class MotionClock extends ValueNotifier<double> {
  MotionClock({required this.startedAtMs, required this.tier, this.fps = 30})
    : super(0) {
    value = _phase();
    if (tier != MotionTier.still) {
      _ticker = Ticker(_onTick)..start();
    }
  }

  final int startedAtMs;
  final MotionTier tier;
  final int fps;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  double _phase() =>
      (DateTime.now().millisecondsSinceEpoch - startedAtMs) / 1000.0;

  int get _minGapMs => 1000 ~/ (tier == MotionTier.reduced ? 12 : fps);

  void _onTick(Duration d) {
    if ((d - _last).inMilliseconds < _minGapMs) return;
    _last = d;
    value = _phase();
  }

  void pause() => _ticker?.muted = true;
  void resume() => _ticker?.muted = false;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

/// Owns a [MotionClock] for a subtree and exposes it. Pauses when the
/// widget is hidden via [TickerMode], restarts when [tier] changes.
class MotionScope extends StatefulWidget {
  const MotionScope({
    super.key,
    required this.startedAtMs,
    required this.tier,
    required this.builder,
  });

  final int startedAtMs;
  final MotionTier tier;
  final Widget Function(BuildContext, MotionClock) builder;

  @override
  State<MotionScope> createState() => _MotionScopeState();
}

class _MotionScopeState extends State<MotionScope> {
  late MotionClock _clock = _make();

  MotionClock _make() => MotionClock(
    startedAtMs: widget.startedAtMs,
    tier: widget.tier,
    fps: widget.tier == MotionTier.full ? 30 : 12,
  );

  @override
  void didUpdateWidget(MotionScope old) {
    super.didUpdateWidget(old);
    if (old.tier != widget.tier || old.startedAtMs != widget.startedAtMs) {
      _clock.dispose();
      _clock = _make();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _clock);
}

/// Pure motion primitives. All take seconds `t` and return smooth values,
/// periodic in `period` so loops are seamless.
abstract final class Motion {
  static const _tau = math.pi * 2;

  /// Angle in radians of a steady rotation.
  static double rotation(double t, double period, [double phase = 0]) =>
      _tau * (t / period + phase);

  /// Point on an elliptical orbit around [c].
  static Offset orbit(
    Offset c,
    double rx,
    double ry,
    double t,
    double period, [
    double phase = 0,
  ]) {
    final a = rotation(t, period, phase);
    return Offset(c.dx + rx * math.cos(a), c.dy + ry * math.sin(a));
  }

  /// Damped-look pendulum angle: sinusoid with slightly lagging harmonic so
  /// it reads as inertia without a physics sim.
  static double pendulum(
    double t,
    double period,
    double amp, [
    double phase = 0,
  ]) {
    final a = rotation(t, period, phase);
    return amp * (math.sin(a) + 0.12 * math.sin(2 * a - 0.6));
  }

  /// 0..1 eased breathe.
  static double breathe(double t, double period, [double phase = 0]) =>
      0.5 - 0.5 * math.cos(rotation(t, period, phase));

  /// Vertical/horizontal float offset in logical px.
  static Offset float(double t, double period, double amp, [double phase = 0]) {
    final a = rotation(t, period, phase);
    return Offset(math.sin(a * 0.7 + 1.3) * amp * 0.5, math.sin(a) * amp);
  }

  /// Smooth periodic pseudo-noise in -1..1 from a seed (sum of sines, no
  /// random calls per frame).
  static double noise(double t, int seed, [double period = 20]) {
    final s = (seed % 97) / 97.0;
    final a = rotation(t, period, s);
    return (math.sin(a) * 0.6 +
            math.sin(a * 2 + seed) * 0.3 +
            math.sin(a * 3 - seed * 0.5) * 0.1)
        .clamp(-1.0, 1.0);
  }

  /// Closed organic blob. Radii are fixed per [seed]; [t] only modulates them.
  static Path blob(
    Offset c,
    double r,
    int seed,
    double t, {
    int points = 7,
    double wobble = 0.14,
    double period = 24,
  }) {
    final pts = <Offset>[];
    for (var i = 0; i < points; i++) {
      final base = 1 + wobble * math.sin(seed * 1.7 + i * 2.1);
      final live =
          wobble * 0.7 * math.sin(rotation(t, period, i / points) + seed + i);
      final a = _tau * i / points;
      pts.add(c + Offset(math.cos(a), math.sin(a)) * r * (base + live));
    }
    return closedSpline(pts);
  }

  /// Catmull-Rom through [pts], closed, as cubic Beziers.
  static Path closedSpline(List<Offset> pts) {
    final n = pts.length;
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n], p1 = pts[i];
      final p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
      p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return p..close();
  }

  /// Amplitude multiplier for a tier + user intensity.
  static double amp(MotionTier tier, double intensity) => switch (tier) {
    MotionTier.full => 0.4 + 0.6 * intensity,
    MotionTier.reduced => 0.25 * (0.4 + 0.6 * intensity),
    MotionTier.still => 0,
  };

  /// Extracts the first [fraction] of [path] (path-following progress).
  static Path trim(Path path, double fraction) {
    final out = Path();
    var left = clamp01(fraction);
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var remaining = total * left;
    for (final m in metrics) {
      if (remaining <= 0) break;
      out.addPath(m.extractPath(0, math.min(remaining, m.length)), Offset.zero);
      remaining -= m.length;
    }
    return out;
  }
}

/// Resolves the tier from user prefs + OS accessibility flags.
MotionTier resolveTier({
  required bool animationsEnabled,
  required bool reduceMotionPref,
  required bool osReduce,
  bool lowPower = false,
}) {
  if (!animationsEnabled || osReduce) return MotionTier.still;
  if (reduceMotionPref || lowPower) return MotionTier.reduced;
  return MotionTier.full;
}
