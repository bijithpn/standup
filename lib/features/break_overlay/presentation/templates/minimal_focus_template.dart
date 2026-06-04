import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class MinimalFocusTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const MinimalFocusTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _durationLabel() {
    final isShort = breakInfo.type == BreakType.short;
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    final dur = mins > 0
        ? (secs > 0 ? '$mins min $secs sec' : '$mins min')
        : '$totalSeconds sec';
    return isShort ? 'Eye rest · $dur' : 'Pause · $dur';
  }

  @override
  Widget build(BuildContext context) {
    final isShort = breakInfo.type == BreakType.short;
    final accent = isShort
        ? const Color(0xFF7EC8E3)
        : const Color(0xFF86EFAC);
    final progress = totalSeconds > 0
        ? (1 - remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return ColoredBox(
      color: const Color(0xFF0A0A0F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isShort ? LucideIcons.eye : LucideIcons.leaf,
                  size: 20,
                  color: accent.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 20),
                RepaintBoundary(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: CustomPaint(
                      painter: _ArcPainter(accent: accent, progress: progress),
                      child: Center(
                        child: Text(
                          _formatTime(remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 54,
                            fontWeight: FontWeight.w200,
                            fontFamily: 'Inter',
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _durationLabel(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
                if (settings.showExercisesInBreak && breakInfo.tip.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 320,
                    child: Text(
                      breakInfo.tip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!settings.strictMode && onSkip != null)
            Positioned(
              bottom: 36,
              right: 40,
              child: GestureDetector(
                onTap: onSkip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
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

class _ArcPainter extends CustomPainter {
  final Color accent;
  final double progress;

  const _ArcPainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.55);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.accent != accent;
}
