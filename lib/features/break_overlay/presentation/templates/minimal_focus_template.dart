import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _paper = BreakPalette(
  canvas: Color(0xFF242320),
  canvasRaised: Color(0xFF2D2C28),
  surface: Color(0xFF2D2C28),
  border: Color(0x426B746B),
  track: Color(0x426B746B),
  textPrimary: Color(0xFFE2DED4),
  textSecondary: Color(0xFFC2BDB2),
  textMuted: Color(0xFFABA69B),
  isDark: true,
);
const _terracotta = Color(0xFFC4572F);

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

  @override
  Widget build(BuildContext context) {
    const palette = _paper;
    final kind = BreakKind.of(breakInfo);
    final accent = breakAccent(settings, 'minimal', _terracotta);
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final showTip = settings.showExercisesInBreak && breakInfo.tip.isNotEmpty;
    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      palette: palette,
      child: Center(
        child: BreakEntrance(
          scale: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BreakLabel(kind.label),
              const SizedBox(height: 40),
              BreakCompletionPulse(
                complete: complete,
                child: BreakProgressRing(
                  size: 320,
                  strokeWidth: 3,
                  progress: progress,
                  color: accent,
                  trackColor: palette.track,
                  child: BreakCountdown(
                    seconds: remainingSeconds,
                    style: BreakOverlayTheme.hero.copyWith(
                      fontSize: 88,
                      letterSpacing: -3,
                    ),
                    color: breakClockColor(settings, palette),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              if (showTip) BreakTip(breakInfo.tip, maxWidth: 460),
              const SizedBox(height: 20),
              Text(
                breakDurationLabel(totalSeconds),
                style: BreakOverlayTheme.micro.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
