import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// A softly drifting, blurred multi-blob gradient backdrop — a lightweight,
/// asset-free stand-in for a blurred photo/video background. Shared by any
/// full-screen surface that wants that "out-of-focus scene" look (the
/// eye-break template, the poster-style quick reminders), each supplying
/// its own [blobColors] palette.
class AnimatedNatureBackdrop extends StatefulWidget {
  final Color baseColorTop;
  final Color baseColorBottom;
  final List<Color> blobColors;

  const AnimatedNatureBackdrop({
    super.key,
    required this.baseColorTop,
    required this.baseColorBottom,
    required this.blobColors,
  });

  @override
  State<AnimatedNatureBackdrop> createState() =>
      _AnimatedNatureBackdropState();
}

class _AnimatedNatureBackdropState extends State<AnimatedNatureBackdrop>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.blobColors.length, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(seconds: 14 + i * 3),
      )..repeat();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [widget.baseColorTop, widget.baseColorBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.blobColors.length; i++)
            AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, _) {
                final t = _controllers[i].value * 2 * math.pi;
                final dx = 0.6 * math.cos(t + i * 1.7);
                final dy = 0.5 * math.sin(t * 0.8 + i * 2.1);
                return Align(
                  alignment: Alignment(dx, dy),
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.blobColors[i].withValues(alpha: 0.55),
                          widget.blobColors[i].withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          RepaintBoundary(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}
