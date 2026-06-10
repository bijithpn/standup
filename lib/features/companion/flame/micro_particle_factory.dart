import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/utils/logger.dart';

class MicroParticleFactory {
  MicroParticleFactory._();

  static final AppLogger _logger = AppLogger();
  static final Random _rng = Random();

  static ParticleSystemComponent? heart(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 0.8;
      const double riseDistance = 30.0;

      final particle = ComputedParticle(
        lifespan: durationSec,
        renderer: (canvas, particle) {
          final double t = particle.progress;
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

  static ParticleSystemComponent? crumbs(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 0.6;
      const double speed = 40.0;

      final int count = 2 + _rng.nextInt(3);
      final double step = (2 * pi) / count;
      final double phaseOffset = _rng.nextDouble() * 2 * pi;

      final crumbColors = [
        const Color(0xFFD4A056),
        const Color(0xFFB8875E),
        const Color(0xFFE8C87A),
        const Color(0xFFC49A6C),
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

  static ParticleSystemComponent? sparkle(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 1.0;
      const double speed = 50.0;

      final int count = 4 + _rng.nextInt(3);
      final double step = (2 * pi) / count;
      final double phaseOffset = _rng.nextDouble() * 2 * pi;

      final sparkleColors = [
        const Color(0xFFFFE066),
        const Color(0xFFFFD700),
        const Color(0xFFFFF0A0),
        const Color(0xFFFFEC6E),
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

  static ParticleSystemComponent? sleepBubble(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 2.0;
      const double riseDistance = 20.0;
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

  static ParticleSystemComponent? bounce(
    Offset center, {
    bool quietMode = false,
  }) {
    if (quietMode) return null;

    try {
      const double durationSec = 0.3;
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

  static void _drawHeart(Canvas canvas, double size, Paint paint) {
    final double s = size / 2.0;
    final path = Path();
    path.moveTo(0, s * 0.5);
    path.cubicTo(-s * 2, -s * 0.5, -s * 2, -s * 1.5, 0, -s * 0.5);
    path.cubicTo(s * 2, -s * 1.5, s * 2, -s * 0.5, 0, s * 0.5);
    path.close();
    canvas.drawPath(path, paint);
  }

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
