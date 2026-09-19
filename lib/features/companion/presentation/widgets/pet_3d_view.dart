import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/pet_animation.dart';
import 'package:breakmate/features/companion/engine/pet_procedural_animator.dart';
import 'package:breakmate/features/companion/presentation/controllers/pet_3d_controller.dart';

/// Interactive Native 3D Pet Companion Viewport Widget
/// Renders the authentic OneWorks SVG pet companion in genuine 3D perspective space
/// with full orbit camera controls (yaw, pitch, zoom, double-tap reset),
/// dynamic 3D ground drop shadows, volumetric specular lighting, and procedural animations.
class Pet3DView extends StatefulWidget {
  final Pet3DController? controller;
  final AvatarDefinition definition;
  final double width;
  final double height;
  final bool enableRotation;
  final bool enableZoom;
  final bool enablePan;
  final bool autoRotate;
  final bool transparentBackground;
  final bool isStatic;
  final Offset? externalLookAt;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const Pet3DView({
    super.key,
    this.controller,
    required this.definition,
    this.width = 200.0,
    this.height = 200.0,
    this.enableRotation = true,
    this.enableZoom = true,
    this.enablePan = false,
    this.autoRotate = false,
    this.transparentBackground = true,
    this.isStatic = false,
    this.externalLookAt,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<Pet3DView> createState() => _Pet3DViewState();
}

class _Pet3DViewState extends State<Pet3DView> with TickerProviderStateMixin {
  late Pet3DController _controller;
  bool _ownsController = false;
  AnimationController? _tickController;
  late AnimationController _bounceController;
  final PetProceduralAnimator _proceduralAnimator = PetProceduralAnimator();

  final List<_Pet3DParticle> _particles = [];
  final math.Random _rng = math.Random();
  double _baseDistance = 1.0;

  @override
  void initState() {
    super.initState();
    _initController();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    if (!widget.isStatic) {
      _tickController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      )..addListener(_onTick);

      _tickController!.repeat();
    }
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = Pet3DController();
      _ownsController = true;
    }
  }

  void _onTick() {
    _proceduralAnimator.update(0.016);
    _updateParticles(0.016);
    if (widget.autoRotate) {
      _controller.rotate(deltaAzimuth: 0.5, deltaElevation: 0.0);
    }
  }

  @override
  void didUpdateWidget(Pet3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    _tickController?.dispose();
    _bounceController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
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
        _Pet3DParticle(
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
    if (_particles.isEmpty) return;
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
    _bounceController.forward(from: 0.0);
    _spawnParticles(Offset(widget.width / 2, widget.height / 2));
    _proceduralAnimator.playAnimation(PetAnimation.happy);
    widget.onTap?.call();
  }

  void _handleDoubleTap() {
    _controller.resetCamera();
    widget.onDoubleTap?.call();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseDistance = _controller.cameraState.distance;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1 && widget.enableZoom) {
      _controller.zoom(details.scale / _baseDistance);
    } else if (widget.enableRotation) {
      // Horizontal drag -> Yaw, Vertical drag -> Elevation
      final deltaAzimuth = details.focalPointDelta.dx * 0.8;
      final deltaElevation = -details.focalPointDelta.dy * 0.5;
      _controller.rotate(
        deltaAzimuth: deltaAzimuth,
        deltaElevation: deltaElevation,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[_controller, _bounceController];
    if (_tickController != null) listenables.add(_tickController!);

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final camera = _controller.cameraState;
        final pose = _controller.pose;
        final proc = _proceduralAnimator.currentState;

        // Gaze / Cursor look-at
        final lookX = widget.externalLookAt?.dx ?? (pose.yaw * 0.5).clamp(-1.0, 1.0);
        final lookY = widget.externalLookAt?.dy ?? (pose.pitch * 0.5).clamp(-1.0, 1.0);

        // Convert camera azimuth & elevation to total 3D rotations in radians
        final totalYaw = (camera.azimuth * math.pi / 180.0) + (lookX * 0.45);
        final totalPitch = -(camera.elevation * math.pi / 180.0) - (lookY * 0.38);
        final totalRoll = pose.roll + (lookX * 0.10);

        final double zoomScale = (1.0 / camera.distance.clamp(0.4, 4.0));
        final double baseAvatarSize =
            math.min(widget.width, widget.height) * 0.85 * widget.definition.scale;
        final double currentSize = baseAvatarSize * zoomScale;

        // Dynamic squash and stretch from bounce
        double bounceY = proc.offsetY;
        double scaleX = proc.scaleX;
        double scaleY = proc.scaleY;

        final bounceVal = _bounceController.value;
        if (bounceVal > 0) {
          bounceY -= math.sin(bounceVal * math.pi) * 16.0;
          scaleX *= 1.0 + math.sin(bounceVal * math.pi) * 0.12;
          scaleY *= 1.0 - math.sin(bounceVal * math.pi) * 0.10;
        }

        final shadowScale = math.max(0.4, 1.0 - (-bounceY / 35.0));

        // 3D Perspective Matrix with realistic depth convergence
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0022) // Genuine 3D perspective depth
          ..translateByDouble(
            lookX * 16.0,
            bounceY + lookY * 10.0,
            -lookY.abs() * 6.0 - (math.sin(totalPitch.abs()) * 10.0),
            1.0,
          )
          ..rotateY(totalYaw)
          ..rotateX(totalPitch)
          ..rotateZ(totalRoll)
          ..scaleByDouble(
            scaleX * zoomScale,
            scaleY * zoomScale,
            zoomScale,
            1.0,
          );

        final svgPath = widget.definition.species.svgAssetPath;

        final viewContent = Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Dynamic 3D Ground Drop Shadow reacting to 3D Orbit Camera angles
            Positioned(
              bottom: (widget.height - currentSize) / 2 - 10.0 - (camera.elevation * 0.25),
              left: (widget.width - (currentSize * 0.65 * shadowScale)) / 2 - (camera.azimuth * 0.15),
              child: CustomPaint(
                size: Size(currentSize * 0.65 * shadowScale, 14 * shadowScale),
                painter: _Pet3DShadowPainter(
                  shadowScale,
                  skewX: (lookX * 0.2 + camera.azimuth * 0.004).clamp(-0.4, 0.4),
                ),
              ),
            ),

            // 2. The EXACT Authentic SVG Pet Asset inside 3D Perspective Space
            Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: SizedBox(
                width: baseAvatarSize,
                height: baseAvatarSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Authentic OneWorks Vector SVG Pet (Cat, Fox, Dog, Bear, etc.)
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
                            center: Alignment(
                              (-lookX * 0.65 - 0.12 - (camera.azimuth * 0.005)).clamp(-1.0, 1.0),
                              (-lookY * 0.65 - 0.12 + (camera.elevation * 0.005)).clamp(-1.0, 1.0),
                            ),
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

            // 3. Floating Interactive Tap Particles
            if (_particles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _Pet3DParticlesPainter(
                      particles: List.unmodifiable(_particles),
                    ),
                  ),
                ),
              ),
          ],
        );

        Widget interactive = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          onLongPress: widget.onLongPress,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: viewContent,
          ),
        );

        if (widget.transparentBackground) {
          return ColoredBox(
            color: Colors.transparent,
            child: interactive,
          );
        }

        return interactive;
      },
    );
  }
}

class _Pet3DShadowPainter extends CustomPainter {
  final double scale;
  final double skewX;

  _Pet3DShadowPainter(this.scale, {this.skewX = 0.0});

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
  bool shouldRepaint(covariant _Pet3DShadowPainter oldDelegate) =>
      oldDelegate.scale != scale || oldDelegate.skewX != skewX;
}

class _Pet3DParticle {
  Offset position;
  Offset velocity;
  double opacity;
  double scale;
  Color color;
  bool isHeart;

  _Pet3DParticle({
    required this.position,
    required this.velocity,
    required this.opacity,
    required this.scale,
    required this.color,
    required this.isHeart,
  });
}

class _Pet3DParticlesPainter extends CustomPainter {
  final List<_Pet3DParticle> particles;

  _Pet3DParticlesPainter({required this.particles});

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
  bool shouldRepaint(covariant _Pet3DParticlesPainter oldDelegate) => true;
}
