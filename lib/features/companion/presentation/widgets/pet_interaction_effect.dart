import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The three things a user can do to the companion, each with a prop or effect
/// of its own so they do not all read as the same bounce.
enum PetInteractionKind {
  /// Hearts drift up from the head.
  pet(Duration(milliseconds: 1500)),

  /// A ball is thrown in, lands, and bounces away.
  play(Duration(milliseconds: 2400)),

  /// A cookie drops to the mouth and is eaten in bites.
  treat(Duration(milliseconds: 1900));

  const PetInteractionKind(this.duration);

  final Duration duration;

  /// Moments, as a 0..1 fraction of [duration], when the pet should hop in
  /// time with what is drawn.
  List<({double at, double strength})> get hops => switch (this) {
    PetInteractionKind.pet => const [],
    PetInteractionKind.play => const [
      (at: 0.30, strength: 200.0),
      (at: 0.52, strength: 150.0),
      (at: 0.72, strength: 110.0),
    ],
    PetInteractionKind.treat => const [
      (at: 0.42, strength: 70.0),
      (at: 0.58, strength: 70.0),
      (at: 0.74, strength: 70.0),
    ],
  };
}

/// Plays one [PetInteractionKind] over a square [size] stage, then calls
/// [onDone]. Give it a fresh key per interaction to replay it.
class PetInteractionEffect extends StatefulWidget {
  const PetInteractionEffect({
    super.key,
    required this.kind,
    required this.size,
    required this.onDone,
  });

  final PetInteractionKind kind;
  final double size;
  final VoidCallback onDone;

  @override
  State<PetInteractionEffect> createState() => _PetInteractionEffectState();
}

class _PetInteractionEffectState extends State<PetInteractionEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.kind.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _EffectPainter(widget.kind, _controller)),
      ),
    );
  }
}

class _EffectPainter extends CustomPainter {
  _EffectPainter(this.kind, this.animation) : super(repaint: animation);

  final PetInteractionKind kind;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    switch (kind) {
      case PetInteractionKind.pet:
        _hearts(canvas, size, t);
      case PetInteractionKind.play:
        _ball(canvas, size, t);
      case PetInteractionKind.treat:
        _cookie(canvas, size, t);
    }
  }

  // ── Pet: hearts ───────────────────────────────────────────────────────────

  void _hearts(Canvas canvas, Size size, double t) {
    const offsets = [-0.18, 0.04, 0.2, -0.06, 0.12];
    for (var i = 0; i < offsets.length; i++) {
      final start = i * 0.12;
      final p = ((t - start) / 0.55).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final x =
          size.width * (0.5 + offsets[i]) +
          math.sin(p * math.pi * 2 + i) * size.width * 0.025;
      final y = size.height * (0.34 - p * 0.3);
      final fade = p < 0.2 ? p / 0.2 : 1.0 - (p - 0.2) / 0.8;
      final scale = size.width * (0.05 + 0.025 * (i % 3)) * (0.6 + p * 0.5);
      _heart(
        canvas,
        Offset(x, y),
        scale,
        const Color(0xFFFF6B8B).withValues(alpha: fade.clamp(0.0, 1.0)),
      );
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(
        c.dx - r * 1.6,
        c.dy - r * 0.2,
        c.dx - r * 0.7,
        c.dy - r * 1.3,
        c.dx,
        c.dy - r * 0.45,
      )
      ..cubicTo(
        c.dx + r * 0.7,
        c.dy - r * 1.3,
        c.dx + r * 1.6,
        c.dy - r * 0.2,
        c.dx,
        c.dy + r * 0.9,
      );
    canvas.drawPath(path, Paint()..color = color);
  }

  // ── Play: ball ────────────────────────────────────────────────────────────

  void _ball(Canvas canvas, Size size, double t) {
    final r = size.width * 0.06;
    final ground = size.height * 0.86;
    final Offset c;
    final double spin;

    if (t < 0.3) {
      // Thrown in from the right, landing in front of the pet.
      final p = t / 0.3;
      final x = size.width * (1.08 - p * 0.5);
      final arc = math.sin(p * math.pi) * size.height * 0.28;
      c = Offset(x, ground - r - arc);
      spin = p * 6;
    } else {
      // Three shrinking bounces while it rolls off to the left.
      final p = (t - 0.3) / 0.7;
      final x = size.width * (0.58 - p * 0.75);
      final bounce =
          math.pow(1 - p, 1.6) *
          size.height *
          0.2 *
          math.sin(p * math.pi * 3).abs();
      c = Offset(x, ground - r - bounce);
      spin = 6 + p * 12;
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, ground),
        width: r * 1.6,
        height: r * 0.4,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFFF7A3D));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 0.78),
      0.5,
      2.1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.restore();
  }

  // ── Treat: cookie ─────────────────────────────────────────────────────────

  void _cookie(Canvas canvas, Size size, double t) {
    final r = size.width * 0.075;
    const mouth = 0.58;

    if (t < 0.4) {
      // Falls from above onto the mouth.
      final p = Curves.easeIn.transform(t / 0.4);
      final y = size.height * (0.05 + (mouth - 0.05) * p);
      _cookieAt(canvas, Offset(size.width / 2, y), r);
      return;
    }

    // Eaten away in three chomps, which also throws up a few crumbs.
    final p = ((t - 0.4) / 0.4).clamp(0.0, 1.0);
    if (p < 1) {
      _cookieAt(
        canvas,
        Offset(size.width / 2, size.height * mouth),
        r * (1 - (p * 3).floor() / 3),
      );
    }

    final crumbs = ((t - 0.4) / 0.5).clamp(0.0, 1.0);
    if (crumbs > 0 && crumbs < 1) {
      final paint = Paint()
        ..color = const Color(0xFFC98B4B).withValues(alpha: 1 - crumbs);
      for (var i = 0; i < 6; i++) {
        final a = -math.pi * (0.15 + 0.7 * i / 5);
        final d = r * (0.8 + crumbs * 2.2);
        canvas.drawCircle(
          Offset(
            size.width / 2 + math.cos(a) * d,
            size.height * mouth -
                math.sin(a).abs() * d * 0.6 +
                crumbs * crumbs * r * 3,
          ),
          r * 0.1,
          paint,
        );
      }
    }

    // A little sparkle once it is gone: it was a good one.
    final sparkle = ((t - 0.78) / 0.22).clamp(0.0, 1.0);
    if (sparkle > 0) {
      _sparkle(
        canvas,
        Offset(size.width * 0.68, size.height * 0.3),
        r * 0.6 * math.sin(sparkle * math.pi),
      );
    }
  }

  void _cookieAt(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFD9A066));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0xFFB27A3E),
    );
    final chip = Paint()..color = const Color(0xFF5A3A22);
    for (final o in const [
      Offset(-0.35, -0.25),
      Offset(0.3, -0.35),
      Offset(0.05, 0.1),
      Offset(-0.3, 0.38),
      Offset(0.4, 0.3),
    ]) {
      canvas.drawCircle(c + o * r, r * 0.12, chip);
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    if (r <= 0) return;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFD84D));
  }

  @override
  bool shouldRepaint(_EffectPainter old) => old.kind != kind;
}
