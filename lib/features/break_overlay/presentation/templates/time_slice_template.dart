import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class TimeSliceTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const TimeSliceTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  String _shortRemaining() {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    if (m > 0) return '$m:${s.toString().padLeft(2, '0')} left';
    return '${s}s left';
  }

  @override
  Widget build(BuildContext context) {
    final isLong = breakInfo.type == BreakType.long;
    final breakName = isLong ? 'Long break' : 'Eye rest';
    final progress = totalSeconds > 0
        ? (1 - remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    const accent = Color(0xFF5BB898);

    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 48),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  breakName,
                  style: TextStyle(
                    color: BreakOverlayTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
                const Spacer(),
                Text(
                  _shortRemaining(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.33),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(accent),
            ),
            const Spacer(),
            Text(
              isLong ? 'Pause' : 'Rest',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w200,
                fontFamily: BreakOverlayTheme.fontFamily,
                letterSpacing: -2,
                height: 1.0,
              ),
            ),
            if (settings.showExercisesInBreak && breakInfo.tip.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 400,
                child: Text(
                  breakInfo.tip,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BreakOverlayTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Text(
                  DateFormat('HH:mm').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
                const Spacer(),
                if (!settings.strictMode && onSkip != null)
                  GestureDetector(
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
