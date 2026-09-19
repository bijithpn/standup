import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:window_manager/window_manager.dart';

import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_3d_view.dart';

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
  final bool prefer3D;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Offset? externalLookAt;

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
    this.prefer3D = true,
    this.onTap,
    this.onDoubleTap,
    this.externalLookAt,
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
  Timer? _screenCursorTimer;

  Offset _gazeOffset = Offset.zero;
  Offset _targetGaze = Offset.zero;
  double _currentYaw = 0.0;
  final List<_AvatarParticle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _initController();

    if (widget.externalLookAt != null) {
      _targetGaze = widget.externalLookAt!;
      _gazeOffset = widget.externalLookAt!;
      _currentYaw = widget.externalLookAt!.dx * 0.48;
    }

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
          _targetGaze = Offset(event.lookAtX, event.lookAtY);
          _gazeOffset = Offset(
            ui.lerpDouble(_gazeOffset.dx, _targetGaze.dx, 0.35) ?? _targetGaze.dx,
            ui.lerpDouble(_gazeOffset.dy, _targetGaze.dy, 0.35) ?? _targetGaze.dy,
          );
          _currentYaw = event.yaw;
        });
      } else if (event is AvatarAnimationStartedEvent ||
          event is AvatarAnimationFinishedEvent) {
        setState(() {});
      }
    });
  }

  Offset _cachedWindowOrigin = Offset.zero;

  void _updateWindowOrigin() async {
    if (Platform.isMacOS || Platform.isWindows) {
      try {
        _cachedWindowOrigin = await windowManager.getPosition();
      } catch (_) {}
    }
  }

  void _setupCursorTracking() {
    if (!widget.autoTrackCursor) return;

    _updateWindowOrigin();
    final tracker = widget.cursorTracker ?? CursorTracker.instance;
    _cursorSub?.cancel();
    _cursorSub = tracker.positionStream.listen((globalCursorPos) {
      if (!mounted) return;
      _handleScreenCursor(globalCursorPos);
    });

    if (Platform.isMacOS || Platform.isWindows) {
      _screenCursorTimer?.cancel();
      _screenCursorTimer = Timer.periodic(const Duration(milliseconds: 33), (_) async {
        if (!mounted || widget.isStatic || !widget.autoTrackCursor) return;
        if (widget.externalLookAt != null) return;
        try {
          final globalCursor = await NativeBridge.getCursorPosition();
          if (!mounted) return;
          _handleScreenCursor(globalCursor);
        } catch (_) {}
      });
    }
  }

  void _handleScreenCursor(Offset globalCursor) {
    if (!mounted || widget.externalLookAt != null) return;
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final localCenter = renderBox.localToGlobal(
        Offset(renderBox.size.width / 2.0, renderBox.size.height / 2.0),
      );
      final widgetScreenCenter = Offset(
        _cachedWindowOrigin.dx + localCenter.dx,
        _cachedWindowOrigin.dy + localCenter.dy,
      );

      final dx = globalCursor.dx - widgetScreenCenter.dx;
      final dy = globalCursor.dy - widgetScreenCenter.dy;

      final normX = (dx / 380.0).clamp(-1.0, 1.0);
      final normY = (dy / 380.0).clamp(-1.0, 1.0);

      _applyTargetLookAt(normX, normY);
    } catch (_) {}
  }

  void _applyTargetLookAt(double normX, double normY) {
    _targetGaze = Offset(normX, normY);
    _controller.setLookAt(normX, normY);
    if (!mounted) return;
    setState(() {
      _gazeOffset = Offset(
        ui.lerpDouble(_gazeOffset.dx, _targetGaze.dx, 0.28) ?? _targetGaze.dx,
        ui.lerpDouble(_gazeOffset.dy, _targetGaze.dy, 0.28) ?? _targetGaze.dy,
      );
      _currentYaw = _gazeOffset.dx * 0.48;
    });
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalLookAt != null && widget.externalLookAt != oldWidget.externalLookAt) {
      _applyTargetLookAt(widget.externalLookAt!.dx, widget.externalLookAt!.dy);
    }

    if (oldWidget.controller != widget.controller) {
      _cursorSub?.cancel();
      _screenCursorTimer?.cancel();
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
    _screenCursorTimer?.cancel();
    _eventSub?.cancel();
    _animController.dispose();
    _bounceController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (!widget.autoTrackCursor || widget.externalLookAt != null) return;
    final w = widget.width > 0 ? widget.width : 160.0;
    final h = widget.height > 0 ? widget.height : 160.0;

    final normalizedX =
        ((event.localPosition.dx / (w / 2.0)) - 1.0).clamp(-1.0, 1.0);
    final normalizedY =
        ((event.localPosition.dy / (h / 2.0)) - 1.0).clamp(-1.0, 1.0);

    _applyTargetLookAt(normalizedX, normalizedY);
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

    if (widget.prefer3D) {
      return MouseRegion(
        onHover: _handlePointerHover,
        child: Pet3DView(
          definition: widget.definition,
          width: widget.width,
          height: widget.height,
          enableRotation: widget.isInteractive,
          enableZoom: widget.isInteractive,
          transparentBackground: widget.transparent,
          isStatic: widget.isStatic,
          externalLookAt: widget.externalLookAt ?? _gazeOffset,
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
        ),
      );
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

        // 3D Rotations:
        // Yaw: Left-right turning up to ~28 degrees in 3D
        final yaw = _currentYaw + math.sin(_animController.value * math.pi) * 0.04;
        // Pitch: Looking up/down up to ~22 degrees in 3D
        final pitch = -lookY * 0.38;
        // Roll: Natural head tilt banking into the turn
        final roll = lookX * 0.10 + math.sin(_animController.value * math.pi) * 0.02;

        // 3D Perspective Matrix with realistic depth convergence
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0022) // perspective depth
          ..translateByDouble(lookX * 16.0, bounceY + lookY * 10.0, -lookY.abs() * 6.0, 1.0)
          ..rotateY(yaw)
          ..rotateX(pitch)
          ..rotateZ(roll)
          ..scaleByDouble(scaleX, scaleY, 1.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Dynamic 3D ground drop shadow reacting to 3D perspective tilt
            Positioned(
              bottom: (widget.height - avatarSize) / 2 - 10.0 + (lookY * 4.0),
              left: (widget.width - (avatarSize * 0.65 * shadowScale)) / 2 - (lookX * 12.0),
              child: CustomPaint(
                size: Size(avatarSize * 0.65 * shadowScale, 14 * shadowScale),
                painter: _AvatarShadowPainter(shadowScale, skewX: lookX * 0.2),
              ),
            ),

            // Authentic Animated SVG Vector Companion with 3D Specular Lighting
            Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Authentic SVG Artwork
                    SvgPicture.asset(
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

                    // Dynamic 3D Spherical Specular Light & Volumetric Depth Shading
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment(-lookX * 0.65 - 0.12, -lookY * 0.65 - 0.12),
                            radius: 0.92,
                            colors: [
                              Colors.white.withValues(alpha: 0.20),
                              Colors.white.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
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
  final double skewX;

  _AvatarShadowPainter(this.scale, {this.skewX = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (skewX != 0.0) {
      canvas.skew(skewX, 0.0);
    }
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: (0.24 * scale).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: size.height,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarShadowPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.skewX != skewX;
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
