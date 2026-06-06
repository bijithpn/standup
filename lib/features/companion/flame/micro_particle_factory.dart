import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Factory of lightweight Flame particle effects rendered inside [CompanionGame].
///
/// Every factory method:
/// - Returns `null` immediately when [quietMode] is `true` (Req 13.7).
/// - Wraps the [ParticleSystemComponent] constructor in `try/catch`; on error
///   it logs via [AppLogger] and returns `null` (Req 13.6 error-handling note).
///
/// All returned components should be added as children of [CompanionGame] so
/// they remain scoped to the CompanionWindow (Req 13.6).
class MicroParticleFactory {
  MicroParticleFactory._(); // pure static utility — not instantiatable

  static final AppLogger _logger = AppLogger();
  static final Random _rng = Random();

  // ────────────────────────────────────────────────────────────────────────────
  // heart — Req 13.1
  // ────────────────────────────────────────────────────────────────────────────

  /// Spawns a single heart that rises 30 logical pixels upward and fades from
  /// fully opaque to fully transparent over 800 ms.
  ///
  /// Returns `null` when [quietMode] is `true`.
  static ParticleSystemComponent? heart(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 0.8; // 800 ms
      const double riseDistance = 30.0; // 30 px upward

      final particle = ComputedParticle(
        lifespan: durationSec,
        renderer: (canvas, particle) {
          final double t = particle.progress; // 0.0 → 1.0 over lifespan
          final double alpha = (1.0 - t).clamp(0.0, 1.0);
          final double offsetY = -riseDistance * t;

          final paint = Paint()
            ..color = const Color(0xFFFF6B8A).withValues(alpha: alpha);
          canvas.save();
          canvas.translate(0, offsetY);
          _drawHeart(canvas, 8.0, paint);
          canvas.restore();
        },
      );

      return ParticleSystemComponent(
        particle: particle,
        position: Vector2(center.dx, center.dy),
      );
    } catch (e, st) {
      _logger.warning('MicroParticleFactory.heart failed: $e\n$st');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // crumbs — Req 13.2
  // ────────────────────────────────────────────────────────────────────────────

  /// Spawns 2–4 crumb particles scattered in distinct directions with ≥ 45°
  /// angular spacing, fading from fully opaque to fully transparent over 600 ms.
  ///
  /// Returns `null` when [quietMode] is `true`.
  static ParticleSystemComponent? crumbs(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 0.6; // 600 ms
      const double speed = 40.0; // px/s outward

      // Choose between 2 and 4 particles (both extremes inclusive)
      final int count = 2 + _rng.nextInt(3); // yields 2, 3, or 4
      // Evenly distribute angles — guarantees ≥ (360 / count)° spacing.
      // For count 2: 180°; count 3: 120°; count 4: 90° — all ≥ 45°.
      final double step = (2 * pi) / count;
      // Random phase so crumbs scatter in varied directions each call
      final double phaseOffset = _rng.nextDouble() * 2 * pi;

      final crumbColors = [
        const Color(0xFFD4A056), // golden brown
        const Color(0xFFB8875E), // warm brown
        const Color(0xFFE8C87A), // light gold
        const Color(0xFFC49A6C), // tan
      ];

      final particles = List<Particle>.generate(count, (i) {
        final double angle = phaseOffset + i * step;
        final double vx = cos(angle) * speed;
        final double vy = sin(angle) * speed;
        final Color color = crumbColors[i % crumbColors.length];
        final double radius = 2.0 + _rng.nextDouble() * 2.0;

        return ComputedParticle(
          lifespan: durationSec,
          renderer: (canvas, particle) {
            final double t = particle.progress;
            final double alpha = (1.0 - t).clamp(0.0, 1.0);
            final double px = vx * t * durationSec;
            final double py = vy * t * durationSec;
            final paint = Paint()..color = color.withValues(alpha: alpha);
            canvas.drawCircle(Offset(px, py), radius, paint);
          },
        );
      });

      return ParticleSystemComponent(
        particle: ComposedParticle(children: particles),
        position: Vector2(center.dx, center.dy),
      );
    } catch (e, st) {
      _logger.warning('MicroParticleFactory.crumbs failed: $e\n$st');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // sparkle — Req 13.3
  // ────────────────────────────────────────────────────────────────────────────

  /// Spawns 4–6 sparkle particles radiating outward in evenly distributed
  /// directions, fading from fully opaque to fully transparent over 1 000 ms.
  ///
  /// Returns `null` when [quietMode] is `true`.
  static ParticleSystemComponent? sparkle(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 1.0; // 1 000 ms
      const double speed = 50.0; // px/s outward

      // Choose between 4 and 6 particles (both extremes inclusive)
      final int count = 4 + _rng.nextInt(3); // yields 4, 5, or 6
      // Evenly distribute angles across a full circle
      final double step = (2 * pi) / count;
      final double phaseOffset = _rng.nextDouble() * 2 * pi;

      final sparkleColors = [
        const Color(0xFFFFE066), // yellow
        const Color(0xFFFFD700), // gold
        const Color(0xFFFFF0A0), // pale yellow
        const Color(0xFFFFEC6E), // warm yellow
      ];

      final particles = List<Particle>.generate(count, (i) {
        final double angle = phaseOffset + i * step;
        final double vx = cos(angle) * speed;
        final double vy = sin(angle) * speed;
        final Color color = sparkleColors[i % sparkleColors.length];
        final double size = 4.0 + _rng.nextDouble() * 3.0;

        return ComputedParticle(
          lifespan: durationSec,
          renderer: (canvas, particle) {
            final double t = particle.progress;
            final double alpha = (1.0 - t).clamp(0.0, 1.0);
            final double px = vx * t * durationSec;
            final double py = vy * t * durationSec;
            final paint = Paint()..color = color.withValues(alpha: alpha);
            canvas.save();
            canvas.translate(px, py);
            _drawStar(canvas, size, paint);
            canvas.restore();
          },
        );
      });

      return ParticleSystemComponent(
        particle: ComposedParticle(children: particles),
        position: Vector2(center.dx, center.dy),
      );
    } catch (e, st) {
      _logger.warning('MicroParticleFactory.sparkle failed: $e\n$st');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // sleepBubble — Req 13.4
  // ────────────────────────────────────────────────────────────────────────────

  /// Spawns a single sleep-bubble "z" that rises 20 logical pixels and fades
  /// over 2 000 ms. The repeating cycle is managed externally by
  /// [CompanionGame]: when this component finishes its lifespan, spawn another
  /// while still in [PetState.sleep].
  ///
  /// Returns `null` when [quietMode] is `true`.
  static ParticleSystemComponent? sleepBubble(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 2.0; // 2 000 ms
      const double riseDistance = 20.0; // 20 px upward
      const double radius = 5.0;

      final particle = ComputedParticle(
        lifespan: durationSec,
        renderer: (canvas, particle) {
          final double t = particle.progress;
          final double alpha = (1.0 - t).clamp(0.0, 1.0);
          final double offsetY = -riseDistance * t;

          final bubblePaint = Paint()
            ..color = const Color(0xFFADD8E6).withValues(alpha: alpha)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.2;

          canvas.save();
          canvas.translate(0, offsetY);
          canvas.drawCircle(Offset.zero, radius, bubblePaint);

          // Draw the "z" label inside the bubble
          final textPainter = TextPainter(
            text: TextSpan(
              text: 'z',
              style: TextStyle(
                color: const Color(0xFFADD8E6).withValues(alpha: alpha),
                fontSize: radius * 0.9,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(-textPainter.width / 2, -textPainter.height / 2),
          );

          canvas.restore();
        },
      );

      return ParticleSystemComponent(
        particle: particle,
        position: Vector2(center.dx, center.dy),
      );
    } catch (e, st) {
      _logger.warning('MicroParticleFactory.sleepBubble failed: $e\n$st');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // bounce — Req 13.5
  // ────────────────────────────────────────────────────────────────────────────

  /// Spawns an expanding ring that grows outward to a radius of 20 logical
  /// pixels and fades from fully opaque to fully transparent over 300 ms.
  ///
  /// Returns `null` when [quietMode] is `true`.
  static ParticleSystemComponent? bounce(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 0.3; // 300 ms
      const double maxRadius = 20.0;

      final particle = ComputedParticle(
        lifespan: durationSec,
        renderer: (canvas, particle) {
          final double t = particle.progress;
          final double alpha = (1.0 - t).clamp(0.0, 1.0);
          final double currentRadius = maxRadius * t;

          final paint = Paint()
            ..color = const Color(0xFFFFB347).withValues(alpha: alpha)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.5;

          canvas.drawCircle(
            Offset.zero,
            currentRadius.clamp(0.5, maxRadius),
            paint,
          );
        },
      );

      return ParticleSystemComponent(
        particle: particle,
        position: Vector2(center.dx, center.dy),
      );
    } catch (e, st) {
      _logger.warning('MicroParticleFactory.bounce failed: $e\n$st');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Private drawing helpers
  // ────────────────────────────────────────────────────────────────────────────

  /// Draws an approximate heart shape centered at [Offset.zero].
  static void _drawHeart(Canvas canvas, double size, Paint paint) {
    final double s = size / 2.0;
    final path = Path();
    // Two cubic bezier arcs meeting at the bottom point
    path.moveTo(0, s * 0.5);
    path.cubicTo(-s * 2, -s * 0.5, -s * 2, -s * 1.5, 0, -s * 0.5);
    path.cubicTo(s * 2, -s * 1.5, s * 2, -s * 0.5, 0, s * 0.5);
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Draws a 4-pointed star centered at [Offset.zero].
  static void _drawStar(Canvas canvas, double size, Paint paint) {
    final double outer = size / 2.0;
    final double inner = outer * 0.4;
    final path = Path();
    const int points = 4;
    const double startAngle = -pi / 2;

    for (int i = 0; i < points * 2; i++) {
      final double angle = startAngle + i * pi / points;
      final double r = i.isEven ? outer : inner;
      final double x = cos(angle) * r;
      final double y = sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
