import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';

/// Floating particle data structure for interactive tap reactions
class _AvatarParticle {
  Offset position;
  Offset velocity;
  double opacity;
  double scale;
  final Color color;
  final bool isHeart;

  _AvatarParticle({
    required this.position,
    required this.velocity,
    required this.opacity,
    required this.scale,
    required this.color,
    required this.isHeart,
  });
}

/// A companion viewport widget showcasing the authentic species SVG vector artwork
/// with lively physics-based 3D animations:
/// - Smooth idle breathing and floating bob
/// - Real-time mouse cursor head tilt and gaze sway
/// - Interactive squash-and-stretch bounce on tap
/// - Floating hearts and sparkle burst particles
/// - Dynamic ground drop shadow scaling with height
class AvatarView extends StatefulWidget {
  final AvatarDefinition definition;
  final AvatarEngineController? controller;
  final double width;
  final double height;
  final bool isInteractive;
  final bool autoTrackCursor;
  final bool isStatic;
  final CursorTracker? cursorTracker;
  final Widget? fallback;
  final WidgetBuilder? fallbackBuilder;
  final bool transparent;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const AvatarView({
    super.key,
    required this.definition,
    this.controller,
    this.width = 160.0,
    this.height = 160.0,
    this.isInteractive = true,
    this.autoTrackCursor = true,
    this.isStatic = false,
    this.cursorTracker,
    this.fallback,
    this.fallbackBuilder,
    this.transparent = true,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> with TickerProviderStateMixin {
  late AvatarEngineController _controller;
  bool _ownsController = false;

  late AnimationController _animController;
  late AnimationController _bounceController;

  StreamSubscription<AvatarEvent>? _eventSub;
  StreamSubscription<ui.Offset>? _cursorSub;

  Offset _gazeOffset = Offset.zero;
  double _currentYaw = 0.0;
  final List<_AvatarParticle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _initController();

    // Idle breathing and floating animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    if (!widget.isStatic) {
      _animController.repeat(reverse: true);
    }

    // Tap reaction squash-and-stretch bounce controller
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _bindControllerEvents();
    _setupCursorTracking();

    _controller.setDefinition(widget.definition);
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = AvatarEngineController();
      _ownsController = true;
    }
  }

  void _bindControllerEvents() {
    _eventSub?.cancel();
    _eventSub = _controller.eventChannel.events.listen((event) {
      if (!mounted) return;
      if (event is AvatarGazeEvent) {
        setState(() {
          _gazeOffset = Offset(event.lookAtX, event.lookAtY);
          _currentYaw = event.yaw;
        });
      } else if (event is AvatarAnimationStartedEvent ||
          event is AvatarAnimationFinishedEvent) {
        setState(() {});
      }
    });
  }

  void _setupCursorTracking() {
    if (!widget.autoTrackCursor) return;

    final tracker = widget.cursorTracker ?? CursorTracker.instance;
    _cursorSub?.cancel();
    _cursorSub = tracker.positionStream.listen((globalCursorPos) {
      if (!mounted) return;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final localPos = renderBox.globalToLocal(globalCursorPos);
      final size = renderBox.size;
      final centerX = size.width / 2.0;
      final centerY = size.height / 2.0;

      final normalizedX = ((localPos.dx - centerX) / (size.width * 1.5))
          .clamp(-1.0, 1.0);
      final normalizedY = ((localPos.dy - centerY) / (size.height * 1.5))
          .clamp(-1.0, 1.0);

      _controller.setLookAt(normalizedX, normalizedY);
      setState(() {
        _gazeOffset = Offset(normalizedX, normalizedY);
        _currentYaw = normalizedX * 0.35;
      });
    });
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _cursorSub?.cancel();
      _eventSub?.cancel();
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      _bindControllerEvents();
      _controller.setDefinition(widget.definition);
    }

    if (oldWidget.definition != widget.definition) {
      _controller.setDefinition(widget.definition);
      setState(() {});
    }

    if (oldWidget.cursorTracker != widget.cursorTracker ||
        oldWidget.autoTrackCursor != widget.autoTrackCursor) {
      _setupCursorTracking();
    }
  }

  @override
  void dispose() {
    _cursorSub?.cancel();
    _eventSub?.cancel();
    _animController.dispose();
    _bounceController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (!widget.autoTrackCursor) return;
    final w = widget.width > 0 ? widget.width : 160.0;
    final h = widget.height > 0 ? widget.height : 160.0;

    final normalizedX =
        ((event.localPosition.dx / (w / 2.0)) - 1.0).clamp(-1.0, 1.0);
    final normalizedY =
        ((event.localPosition.dy / (h / 2.0)) - 1.0).clamp(-1.0, 1.0);

    _controller.setLookAt(normalizedX, normalizedY);
    _controller.eventChannel.emit(
      AvatarGazeEvent(
        lookAtX: normalizedX,
        lookAtY: normalizedY,
        yaw: normalizedX * 0.35,
      ),
    );
    setState(() {
      _gazeOffset = Offset(normalizedX, normalizedY);
      _currentYaw = normalizedX * 0.35;
    });
  }

  void _spawnParticles(Offset origin) {
    final colors = [
      const Color(0xFFFF5252),
      const Color(0xFFFF4081),
      const Color(0xFFFFB74D),
      const Color(0xFF64B5F6),
      const Color(0xFFE040FB),
    ];
    for (int i = 0; i < 6; i++) {
      final angle = (_rng.nextDouble() * math.pi) - math.pi;
      final speed = 30.0 + _rng.nextDouble() * 50.0;
      _particles.add(
        _AvatarParticle(
          position: origin,
          velocity: Offset(
            math.cos(angle) * speed,
            math.sin(angle) * speed - 25.0,
          ),
          opacity: 1.0,
          scale: 0.8 + _rng.nextDouble() * 0.6,
          color: colors[_rng.nextInt(colors.length)],
          isHeart: i % 2 == 0,
        ),
      );
    }
  }

  void _updateParticles(double dt) {
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.position += p.velocity * dt;
      p.opacity -= dt * 1.5;
      p.scale += dt * 0.3;
      if (p.opacity <= 0) {
        _particles.removeAt(i);
      }
    }
  }

  void _handleTap() {
    if (!widget.isInteractive) return;
    _bounceController.forward(from: 0.0);
    final center = Offset(widget.width / 2, widget.height / 2);
    _spawnParticles(center);
    widget.onTap?.call();
    _controller.eventChannel.emit(AvatarTapEvent());
  }

  void _handleDoubleTap() {
    if (!widget.isInteractive) return;
    _bounceController.forward(from: 0.0);
    final center = Offset(widget.width / 2, widget.height / 2);
    _spawnParticles(center);
    _spawnParticles(center);
    widget.onDoubleTap?.call();
    _controller.eventChannel.emit(AvatarDoubleTapEvent());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fallbackBuilder != null) {
      return widget.fallbackBuilder!(context);
    }
    if (widget.fallback != null) {
      return widget.fallback!;
    }

    final svgPath = widget.definition.species.svgAssetPath;
    final double avatarSize =
        math.min(widget.width, widget.height) * 0.85 * widget.definition.scale;

    Widget avatarContent = AnimatedBuilder(
      animation: Listenable.merge([_animController, _bounceController]),
      builder: (context, _) {
        _updateParticles(0.016);

        // Dynamic motion calculations
        double bounceY = 0.0;
        double scaleX = 1.0;
        double scaleY = 1.0;

        final bounceVal = _bounceController.value;
        if (bounceVal > 0) {
          bounceY = -math.sin(bounceVal * math.pi) * 16.0;
          scaleX = 1.0 + math.sin(bounceVal * math.pi) * 0.12;
          scaleY = 1.0 - math.sin(bounceVal * math.pi) * 0.10;
        } else {
          final clip = _controller.currentClip;
          if (clip == AvatarAnimationClip.celebrate ||
              clip == AvatarAnimationClip.bounce) {
            bounceY =
                -math.sin(_animController.value * math.pi * 2).abs() * 14.0;
            scaleX = 1.0 + math.sin(_animController.value * math.pi * 2) * 0.08;
            scaleY = 1.0 - math.sin(_animController.value * math.pi * 2) * 0.06;
          } else if (clip == AvatarAnimationClip.sleep) {
            bounceY = math.sin(_animController.value * math.pi) * 2.5;
            scaleX = 1.0 + math.sin(_animController.value * math.pi) * 0.02;
          } else {
            // Idle breathing float
            bounceY = math.sin(_animController.value * math.pi) * 6.0;
            scaleX = 1.0 + math.sin(_animController.value * math.pi) * 0.02;
            scaleY = 1.0 - math.sin(_animController.value * math.pi) * 0.015;
          }
        }

        final shadowScale = math.max(0.4, 1.0 - (-bounceY / 35.0));

        // 3D perspective matrix based on cursor gaze and yaw
        final lookX = _gazeOffset.dx.clamp(-1.0, 1.0);
        final lookY = _gazeOffset.dy.clamp(-1.0, 1.0);
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..translateByDouble(lookX * 6.0, bounceY + lookY * 4.0, 0.0, 1.0)
          ..rotateY(_currentYaw * 0.22)
          ..rotateX(-lookY * 0.12)
          ..scaleByDouble(scaleX, scaleY, 1.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft ground drop shadow
            Positioned(
              bottom: (widget.height - avatarSize) / 2 - 8.0,
              child: CustomPaint(
                size: Size(avatarSize * 0.65 * shadowScale, 14 * shadowScale),
                painter: _AvatarShadowPainter(shadowScale),
              ),
            ),

            // Authentic Animated SVG Artwork
            Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: SvgPicture.asset(
                  svgPath,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            ),

            // Floating Interactive Tap Particles
            if (_particles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _AvatarParticlesPainter(
                      particles: List.unmodifiable(_particles),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );

    Widget interactiveContent = MouseRegion(
      onHover: _handlePointerHover,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: avatarContent,
        ),
      ),
    );

    if (widget.transparent) {
      return ColoredBox(
        color: Colors.transparent,
        child: interactiveContent,
      );
    }

    return interactiveContent;
  }
}

/// Soft drop shadow painter below the avatar
class _AvatarShadowPainter extends CustomPainter {
  final double scale;

  _AvatarShadowPainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22 * scale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: size.height,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarShadowPainter oldDelegate) =>
      oldDelegate.scale != scale;
}

/// Painter for interactive floating hearts and sparkle particles
class _AvatarParticlesPainter extends CustomPainter {
  final List<_AvatarParticle> particles;

  _AvatarParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      if (p.isHeart) {
        final s = 7.0 * p.scale;
        final path = Path()
          ..moveTo(p.position.dx, p.position.dy)
          ..cubicTo(
            p.position.dx - s,
            p.position.dy - s * 1.2,
            p.position.dx - s * 1.5,
            p.position.dy + s * 0.2,
            p.position.dx,
            p.position.dy + s * 1.3,
          )
          ..cubicTo(
            p.position.dx + s * 1.5,
            p.position.dy + s * 0.2,
            p.position.dx + s,
            p.position.dy - s * 1.2,
            p.position.dx,
            p.position.dy,
          );
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(p.position, 3.5 * p.scale, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarParticlesPainter oldDelegate) => true;
}
