import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class SplitViewTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SplitViewTemplate({
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
    final breakTitle = isShort ? 'Eye rest' : 'Long break';
    final progress = totalSeconds > 0
        ? (1 - remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    const accent = BreakOverlayTheme.accentLong;

    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              Expanded(
                flex: 55,
                child: Padding(
                  padding: const EdgeInsets.all(52),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        breakTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w300,
                          fontFamily: BreakOverlayTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 320,
                        child: Text(
                          breakInfo.tip,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.43),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            fontFamily: BreakOverlayTheme.fontFamily,
                            height: 1.75,
                          ),
                        ),
                      ),
                      if (settings.showExercisesInBreak &&
                          breakInfo.triggerReason != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          breakInfo.triggerReason!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.52),
                            fontSize: BreakOverlayTheme.labelFontSize,
                            fontWeight: FontWeight.w400,
                            fontFamily: BreakOverlayTheme.fontFamily,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 45,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 80,
                      bottom: 80,
                      child: Container(
                        width: 0.5,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(remainingSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 80,
                              fontWeight: FontWeight.w200,
                              fontFamily: BreakOverlayTheme.fontFamily,
                              fontFeatures: [FontFeature.tabularFigures()],
                              letterSpacing: -3,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            breakTitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              fontFamily: BreakOverlayTheme.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 20),
                          RepaintBoundary(
                            child: SizedBox(
                              width: 130,
                              height: 130,
                              child: CustomPaint(
                                painter: _ArcPainter(
                                  accent: accent,
                                  progress: progress,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!settings.strictMode && onSkip != null)
            Positioned(
              bottom: BreakOverlayTheme.skipBottom,
              right: BreakOverlayTheme.skipRight,
              child: GestureDetector(
                onTap: onSkip,
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

class _ArcPainter extends CustomPainter {
  final Color accent;
  final double progress;

  const _ArcPainter({required this.accent, required this.progress});

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
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.12),
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
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.accent != accent;
}
