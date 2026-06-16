import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';

class WindDownTemplate extends StatelessWidget {
  const WindDownTemplate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sl<StatsService>(), sl<BreakController>()]),
      builder: (context, _) {
        final stats = sl<StatsService>().stats;
        final breakController = sl<BreakController>();

        return ColoredBox(
          color: const Color(0xFF0A0A0F),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: CustomPaint(painter: _WindDownPainter())),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.sunset,
                        size: 22,
                        color: Color(0xFFC49A4A),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Time to wind down',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          fontFamily: 'Inter',
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${stats.breaksCompleted} breaks today',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 180,
                        height: 42,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            backgroundColor: Colors.transparent,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Inter',
                            ),
                          ),
                          onPressed: () =>
                              breakController.completeCurrentBreak(),
                          child: const Text('Done for today'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WindDownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width * 0.5, size.height);
    final paint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFEA580C).withValues(alpha: 0.07),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.5),
          );
    canvas.drawCircle(center, size.shortestSide * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
