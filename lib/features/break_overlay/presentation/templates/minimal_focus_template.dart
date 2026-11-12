import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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
    final palette = BreakPalette.of(context);
    final kind = BreakKind.of(breakInfo);
    final accent = palette.accentOn(
      breakAccent(settings, 'minimal', kind.accent),
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final showTip = settings.showExercisesInBreak && breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 290,
            child: BreakEntrance(
              scale: false,
              child: BreakCompletionPulse(
                complete: complete,
                child: BreakCountdown(
                  seconds: remainingSeconds,
                  style: BreakOverlayTheme.hero.copyWith(
                    fontSize: 148,
                    letterSpacing: -6,
                  ),
                  color: breakClockColor(settings, palette),
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - 90,
            top: 482,
            width: 180,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Semantics(
                label: 'Break progress',
                value: '${(progress * 100).round()}%',
                child: ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    color: accent,
                    backgroundColor: palette.border,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 512,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(2),
              scale: false,
              child: Text(
                '${kind.label}, ${breakDurationLabel(totalSeconds)}',
                textAlign: TextAlign.center,
                style: BreakOverlayTheme.body.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: Center(
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(3),
                  scale: false,
                  child: BreakTip(
                    breakInfo.tip,
                    maxWidth: 520,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
