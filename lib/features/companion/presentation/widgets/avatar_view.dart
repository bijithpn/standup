import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';

/// Returns the SVG snapshot asset path for a given [AvatarSpecies],
/// sourced from the OneWorks Avatar (avatar-main) repository.
/// Returns null for species without a snapshot (panda, raccoon, redPanda, wolf).
String? _avatarSnapshotPath(AvatarSpecies species) {
  const overrides = <AvatarSpecies, String>{
    AvatarSpecies.guineaPig: 'assets/avatars/species/guinea-pig.svg',
  };
  if (overrides.containsKey(species)) return overrides[species];

  const knownSpecies = {
    AvatarSpecies.alpaca,
    AvatarSpecies.bear,
    AvatarSpecies.beaver,
    AvatarSpecies.capybara,
    AvatarSpecies.cat,
    AvatarSpecies.chick,
    AvatarSpecies.chinchilla,
    AvatarSpecies.cow,
    AvatarSpecies.deer,
    AvatarSpecies.dog,
    AvatarSpecies.duck,
    AvatarSpecies.ferret,
    AvatarSpecies.fox,
    AvatarSpecies.goose,
    AvatarSpecies.hamster,
    AvatarSpecies.hedgehog,
    AvatarSpecies.lion,
    AvatarSpecies.monkey,
    AvatarSpecies.otter,
    AvatarSpecies.owl,
    AvatarSpecies.parrot,
    AvatarSpecies.penguin,
    AvatarSpecies.pig,
    AvatarSpecies.rabbit,
    AvatarSpecies.seal,
    AvatarSpecies.sheep,
    AvatarSpecies.squirrel,
    AvatarSpecies.tiger,
  };
  if (knownSpecies.contains(species)) {
    return 'assets/avatars/species/${species.name}.svg';
  }
  return null;
}

/// A transparent 3D avatar viewport widget for the OneWorks Avatar Pet Companion.
///
/// Embeds the 3D avatar, handles cursor gaze tracking, gesture interactions,
/// and provides a clean animated vector/canvas fallback across platforms.
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

class _AvatarViewState extends State<AvatarView>
    with SingleTickerProviderStateMixin {
  late AvatarEngineController _controller;
  bool _ownsController = false;

  late AnimationController _animController;
  StreamSubscription<AvatarEvent>? _eventSub;
  StreamSubscription<ui.Offset>? _cursorSub;

  Offset _gazeOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initController();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (!widget.isStatic) {
      _animController.repeat(reverse: true);
    }

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
        });
      } else if (event is AvatarAnimationStartedEvent ||
          event is AvatarAnimationFinishedEvent) {
        setState(() {});
      }
    });
  }

  void _setupCursorTracking() {
    _cursorSub?.cancel();
    if (widget.autoTrackCursor && widget.cursorTracker != null) {
      _cursorSub = widget.cursorTracker!.positionStream.listen((cursorPos) {
        if (!mounted) return;
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final petCenter = renderBox.localToGlobal(
            Offset(renderBox.size.width / 2, renderBox.size.height / 2),
          );
          _controller.updateGaze(
            petScreenPosition: petCenter,
            cursorScreenPosition: cursorPos,
            maxDistance: 500.0,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
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
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (!widget.autoTrackCursor) return;
    final w = widget.width > 0 ? widget.width : 160.0;
    final h = widget.height > 0 ? widget.height : 160.0;

    final normalizedX = ((event.localPosition.dx / (w / 2.0)) - 1.0).clamp(-1.0, 1.0);
    final normalizedY = ((event.localPosition.dy / (h / 2.0)) - 1.0).clamp(-1.0, 1.0);

    _controller.setLookAt(normalizedX, normalizedY);
    _controller.eventChannel.emit(
      AvatarGazeEvent(
        lookAtX: normalizedX,
        lookAtY: normalizedY,
        yaw: _controller.currentYaw,
      ),
    );
  }

  void _handleTap() {
    if (!widget.isInteractive) return;
    widget.onTap?.call();
    _controller.eventChannel.emit(AvatarTapEvent());
  }

  void _handleDoubleTap() {
    if (!widget.isInteractive) return;
    widget.onDoubleTap?.call();
    _controller.eventChannel.emit(AvatarDoubleTapEvent());
  }

  @override
  Widget build(BuildContext context) {
    // ExternalFallback/fallbackBuilder take highest priority (caller overrides).
    Widget content;
    if (widget.fallbackBuilder != null) {
      content = widget.fallbackBuilder!(context);
    } else if (widget.fallback != null) {
      content = widget.fallback!;
    } else {
      // Try to render the real OneWorks Avatar SVG snapshot for this species.
      final svgPath = _avatarSnapshotPath(widget.definition.species);
      if (svgPath != null) {
        // Animate a gentle float effect using the existing AnimationController.
        content = AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final bounceY = widget.isStatic
                ? 0.0
                : math.sin(_animController.value * math.pi) * 4.0;
            return Transform.translate(
              offset: Offset(0, bounceY),
              child: child,
            );
          },
          child: SvgPicture.asset(
            svgPath,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.contain,
            placeholderBuilder: (context) => _buildCanvasFallback(),
          ),
        );
      } else {
        // Canvas painter fallback for species without a snapshot (panda, wolf, etc.)
        content = _buildCanvasFallback();
      }
    }

    Widget interactiveContent = MouseRegion(
      onHover: _handlePointerHover,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: content,
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

  /// Builds the canvas-drawn vector avatar painter (used as fallback when no SVG
  /// snapshot is available for the species, e.g. panda, raccoon, redPanda, wolf).
  Widget _buildCanvasFallback() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _AvatarVectorPainter(
            definition: widget.definition,
            lookAt: _gazeOffset.dx != 0 || _gazeOffset.dy != 0
                ? _gazeOffset
                : _controller.currentLookAt,
            yaw: _controller.currentYaw,
            clip: _controller.currentClip,
            animValue: _animController.value,
          ),
        );
      },
    );
  }
}


/// High fidelity vector canvas renderer for transparent 3D avatar viewport fallback.
class _AvatarVectorPainter extends CustomPainter {
  final AvatarDefinition definition;
  final Offset lookAt;
  final double yaw;
  final AvatarAnimationClip? clip;
  final double animValue;

  _AvatarVectorPainter({
    required this.definition,
    required this.lookAt,
    required this.yaw,
    required this.clip,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.38 * definition.scale;

    final palette = definition.palette;
    final primaryColor = _parseColor(palette.primary);
    final secondaryColor = _parseColor(palette.secondary);
    final accentColor = _parseColor(palette.accent);
    final eyeColor = _parseColor(palette.eyes);

    // Subtle breathing or clip animation offsets
    double bounceY = 0.0;
    double scaleAnim = 1.0;
    double rotationAnim = 0.0;

    if (clip == AvatarAnimationClip.celebrate || clip == AvatarAnimationClip.bounce) {
      bounceY = -math.sin(animValue * math.pi * 2).abs() * 12.0;
      scaleAnim = 1.0 + math.sin(animValue * math.pi * 2) * 0.06;
    } else if (clip == AvatarAnimationClip.sleep) {
      bounceY = math.sin(animValue * math.pi) * 2.0;
    } else {
      // Idle gentle float
      bounceY = math.sin(animValue * math.pi) * 4.0;
    }

    final avatarCenter = center + Offset(0, bounceY);

    canvas.save();
    canvas.translate(avatarCenter.dx, avatarCenter.dy);
    canvas.rotate(rotationAnim + yaw * 0.2);
    canvas.scale(scaleAnim, scaleAnim);

    // 1. Shadow underneath
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, baseRadius * 1.0 - bounceY * 0.5),
        width: baseRadius * 1.4,
        height: baseRadius * 0.4,
      ),
      shadowPaint,
    );

    // 2. Ears / Horns / Features
    _drawEars(canvas, baseRadius, primaryColor, accentColor);

    // 3. Main Head & Body
    final bodyPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-baseRadius * 0.2, -baseRadius * 0.2),
        baseRadius * 1.2,
        [
          primaryColor,
          secondaryColor,
        ],
      );

    canvas.drawCircle(Offset.zero, baseRadius, bodyPaint);

    // 4. Pattern Markings
    _drawPattern(canvas, baseRadius, accentColor);

    // 5. Eyes & Gaze Tracking
    _drawEyes(canvas, baseRadius, eyeColor);

    // 6. Snout / Nose / Mouth
    _drawFaceDetails(canvas, baseRadius, accentColor);

    // 7. Cheeks / Blush
    final blushPaint = Paint()..color = const Color(0xFFFF8595).withValues(alpha: 0.35);
    canvas.drawCircle(Offset(-baseRadius * 0.55, baseRadius * 0.15), baseRadius * 0.14, blushPaint);
    canvas.drawCircle(Offset(baseRadius * 0.55, baseRadius * 0.15), baseRadius * 0.14, blushPaint);

    canvas.restore();
  }

  void _drawEars(Canvas canvas, double radius, Color primary, Color accent) {
    final earPaint = Paint()..color = primary;
    final innerEarPaint = Paint()..color = accent.withValues(alpha: 0.8);

    if (definition.species.isFeline || definition.species == AvatarSpecies.fox || definition.species == AvatarSpecies.wolf) {
      // Pointy ears
      final leftEar = Path()
        ..moveTo(-radius * 0.7, -radius * 0.4)
        ..lineTo(-radius * 0.85, -radius * 1.1)
        ..lineTo(-radius * 0.25, -radius * 0.75)
        ..close();
      final rightEar = Path()
        ..moveTo(radius * 0.7, -radius * 0.4)
        ..lineTo(radius * 0.85, -radius * 1.1)
        ..lineTo(radius * 0.25, -radius * 0.75)
        ..close();
      canvas.drawPath(leftEar, earPaint);
      canvas.drawPath(rightEar, earPaint);

      // Inner ear accents
      final innerLeft = Path()
        ..moveTo(-radius * 0.65, -radius * 0.45)
        ..lineTo(-radius * 0.78, -radius * 0.95)
        ..lineTo(-radius * 0.32, -radius * 0.7)
        ..close();
      final innerRight = Path()
        ..moveTo(radius * 0.65, -radius * 0.45)
        ..lineTo(radius * 0.78, -radius * 0.95)
        ..lineTo(radius * 0.32, -radius * 0.7)
        ..close();
      canvas.drawPath(innerLeft, innerEarPaint);
      canvas.drawPath(innerRight, innerEarPaint);
    } else if (definition.species == AvatarSpecies.rabbit) {
      // Long tall ears
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-radius * 0.55, -radius * 1.5, radius * 0.35, radius * 1.1),
          Radius.circular(radius * 0.18),
        ),
        earPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(radius * 0.2, -radius * 1.5, radius * 0.35, radius * 1.1),
          Radius.circular(radius * 0.18),
        ),
        earPaint,
      );
    } else if (definition.species.isAvian) {
      // Crest / Tufts
      final crest = Path()
        ..moveTo(0, -radius * 0.8)
        ..lineTo(-radius * 0.2, -radius * 1.25)
        ..lineTo(0, -radius * 1.0)
        ..lineTo(radius * 0.2, -radius * 1.25)
        ..close();
      canvas.drawPath(crest, earPaint);
    } else {
      // Round / floppy ears (dog, panda, bear, alpaca, rodents, etc.)
      canvas.drawCircle(Offset(-radius * 0.7, -radius * 0.7), radius * 0.32, earPaint);
      canvas.drawCircle(Offset(radius * 0.7, -radius * 0.7), radius * 0.32, earPaint);
      canvas.drawCircle(Offset(-radius * 0.7, -radius * 0.7), radius * 0.18, innerEarPaint);
      canvas.drawCircle(Offset(radius * 0.7, -radius * 0.7), radius * 0.18, innerEarPaint);
    }
  }

  void _drawPattern(Canvas canvas, double radius, Color accent) {
    final pattern = definition.pattern;
    final patternPaint = Paint()..color = accent.withValues(alpha: 0.45);

    if (pattern == 'stripes') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, -radius * 0.55), width: radius * 0.3, height: radius * 0.08),
          const Radius.circular(4),
        ),
        patternPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, -radius * 0.7), width: radius * 0.4, height: radius * 0.08),
          const Radius.circular(4),
        ),
        patternPaint,
      );
    } else if (pattern == 'spots' || pattern == 'patches') {
      canvas.drawCircle(Offset(radius * 0.4, -radius * 0.3), radius * 0.22, patternPaint);
      canvas.drawCircle(Offset(-radius * 0.45, radius * 0.35), radius * 0.18, patternPaint);
    }
  }

  void _drawEyes(Canvas canvas, double radius, Color eyeColor) {
    final eyeSpacing = radius * 0.38;
    final eyeY = -radius * 0.05;
    final eyeRadius = radius * 0.15;

    final isSleeping = clip == AvatarAnimationClip.sleep;

    if (isSleeping) {
      // Closed curved eyes
      final closedEyePaint = Paint()
        ..color = eyeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..strokeCap = StrokeCap.round;

      final leftEyePath = Path()
        ..moveTo(-eyeSpacing - eyeRadius, eyeY)
        ..quadraticBezierTo(-eyeSpacing, eyeY + eyeRadius * 0.8, -eyeSpacing + eyeRadius, eyeY);
      final rightEyePath = Path()
        ..moveTo(eyeSpacing - eyeRadius, eyeY)
        ..quadraticBezierTo(eyeSpacing, eyeY + eyeRadius * 0.8, eyeSpacing + eyeRadius, eyeY);

      canvas.drawPath(leftEyePath, closedEyePaint);
      canvas.drawPath(rightEyePath, closedEyePaint);
      return;
    }

    // Gaze offset max translation
    final maxPupilOffset = eyeRadius * 0.55;
    final pupilShift = Offset(
      lookAt.dx.clamp(-1.0, 1.0) * maxPupilOffset,
      lookAt.dy.clamp(-1.0, 1.0) * maxPupilOffset,
    );

    // Left Eye Socket (White)
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(-eyeSpacing, eyeY), eyeRadius, whitePaint);
    // Right Eye Socket (White)
    canvas.drawCircle(Offset(eyeSpacing, eyeY), eyeRadius, whitePaint);

    // Iris / Pupils (Gaze tracking)
    final pupilPaint = Paint()..color = eyeColor;
    canvas.drawCircle(Offset(-eyeSpacing, eyeY) + pupilShift, eyeRadius * 0.72, pupilPaint);
    canvas.drawCircle(Offset(eyeSpacing, eyeY) + pupilShift, eyeRadius * 0.72, pupilPaint);

    // Highlights
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(-eyeSpacing - eyeRadius * 0.25, eyeY - eyeRadius * 0.25) + pupilShift * 0.5,
      eyeRadius * 0.28,
      highlightPaint,
    );
    canvas.drawCircle(
      Offset(eyeSpacing - eyeRadius * 0.25, eyeY - eyeRadius * 0.25) + pupilShift * 0.5,
      eyeRadius * 0.28,
      highlightPaint,
    );
  }

  void _drawFaceDetails(Canvas canvas, double radius, Color accent) {
    final noseY = radius * 0.12;

    if (definition.species.isAvian) {
      // Beak
      final beakPaint = Paint()..color = const Color(0xFFF39C12);
      final beakPath = Path()
        ..moveTo(-radius * 0.1, noseY - radius * 0.02)
        ..lineTo(0, noseY + radius * 0.12)
        ..lineTo(radius * 0.1, noseY - radius * 0.02)
        ..close();
      canvas.drawPath(beakPath, beakPaint);
      return;
    }

    final nosePaint = Paint()..color = const Color(0xFF222233);

    // Small nose
    final nosePath = Path()
      ..moveTo(0, noseY - radius * 0.04)
      ..lineTo(-radius * 0.06, noseY + radius * 0.03)
      ..lineTo(radius * 0.06, noseY + radius * 0.03)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // Mouth lines
    final mouthPaint = Paint()
      ..color = const Color(0xFF333344)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(-radius * 0.08, noseY + radius * 0.09)
      ..quadraticBezierTo(-radius * 0.04, noseY + radius * 0.14, 0, noseY + radius * 0.08)
      ..quadraticBezierTo(radius * 0.04, noseY + radius * 0.14, radius * 0.08, noseY + radius * 0.08);

    canvas.drawPath(mouthPath, mouthPaint);
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      } else if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF7E57C2);
  }

  @override
  bool shouldRepaint(covariant _AvatarVectorPainter oldDelegate) {
    return oldDelegate.definition != definition ||
        oldDelegate.lookAt != lookAt ||
        oldDelegate.yaw != yaw ||
        oldDelegate.clip != clip ||
        oldDelegate.animValue != animValue;
  }
}
