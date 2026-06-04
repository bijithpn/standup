import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class SoftArcTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SoftArcTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _label() {
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
    final accent = isShort ? const Color(0xFF7EC8E3) : const Color(0xFF86EFAC);
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
                  color: accent.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 20),
                RepaintBoundary(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      painter: _SoftArcPainter(
                          accent: accent, progress: progress),
                      child: Center(
                        child: Text(
                          _formatTime(remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
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
                const SizedBox(height: 16),
                Text(
                  _label(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
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

class _SoftArcPainter extends CustomPainter {
  final Color accent;
  final double progress;

  const _SoftArcPainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.1),
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoftArcPainter old) =>
      old.progress != progress || old.accent != accent;
}
