import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class RingOnlyTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const RingOnlyTemplate({
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

  @override
  Widget build(BuildContext context) {
    final isShort = breakInfo.type == BreakType.short;
    final breakName = isShort ? 'Eye rest' : 'Long break';
    final progress = totalSeconds > 0
        ? (1 - remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final accent = settings.clockFaceTextColorHex != 0xFFFFFFFF
        ? Color(settings.clockFaceTextColorHex)
        : const Color(0xFF818CF8);

    return ColoredBox(
      color: const Color(0xFF0A0A0F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: RepaintBoundary(
              child: SizedBox(
                width: 300,
                height: 300,
                child: CustomPaint(
                  painter: _RingPainter(accent: accent, progress: progress),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.eye,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatTime(remainingSeconds),
                        style: TextStyle(
                          color: Color(settings.clockFaceTextColorHex),
                          fontSize: 56,
                          fontWeight: FontWeight.w200,
                          fontFamily: 'Inter',
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        breakName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

class _RingPainter extends CustomPainter {
  final Color accent;
  final double progress;

  const _RingPainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.accent != accent;
}
