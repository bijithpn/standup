import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class WaveCalmTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const WaveCalmTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<WaveCalmTemplate> createState() => _WaveCalmTemplateState();
}

class _WaveCalmTemplateState extends State<WaveCalmTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _controller.repeatUnlessReducedMotion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => CustomPaint(
                painter: _WavePainter(phase: _controller.value * 2 * math.pi),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(widget.remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w200,
                    fontFamily: BreakOverlayTheme.fontFamily,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Relax',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: BreakOverlayTheme.labelFontSize,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.settings.strictMode && widget.onSkip != null)
            Positioned(
              bottom: BreakOverlayTheme.skipBottom,
              right: BreakOverlayTheme.skipRight,
              child: GestureDetector(
                onTap: widget.onSkip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: BreakOverlayTheme.textDim,
                      fontSize: BreakOverlayTheme.labelFontSize,
                      fontWeight: FontWeight.w400,
                      fontFamily: BreakOverlayTheme.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double phase;

  const _WavePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final opacities = [0.07, 0.11, 0.05];
    final cy = size.height / 2;

    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacities[i])
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(0, cy);
      for (double x = 0; x <= size.width; x += 2) {
        final y =
            cy +
            14 *
                math.sin(
                  (x / size.width) * 4 * math.pi + phase + i * math.pi / 3,
                );
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.phase != phase;
}
