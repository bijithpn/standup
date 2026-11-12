import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final kind = BreakKind.of(breakInfo);
    final accent = palette.accentOn(
      BreakOverlayTheme.resolveAccent(
        settings.templateAccentOverrides,
        'split_view',
        kind.accent,
      ),
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final reason = breakInfo.triggerReason;

    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      background: Row(
        children: [
          Expanded(child: ColoredBox(color: palette.canvas)),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(left: BorderSide(color: palette.border)),
              ),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 640,
            height: 800,
            child: Center(
              child: BreakEntrance(
                child: BreakCompletionPulse(
                  complete: complete,
                  child: BreakProgressRing(
                    size: 240,
                    strokeWidth: 2,
                    progress: progress,
                    color: accent,
                    trackColor: palette.track,
                    flash: complete ? 0.5 : 0,
                    child: BreakCountdown(
                      seconds: remainingSeconds,
                      color: breakClockColor(settings, palette),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 + 80,
            right: 80,
            top: 0,
            height: 800,
            child: Center(
              child: BreakEntrance(
                delay: BreakEntrance.stagger(1),
                scale: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: BreakOverlayTheme.body.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                    if (breakInfo.tip.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Text(
                          breakInfo.tip,
                          style: BreakOverlayTheme.serif.copyWith(
                            fontSize: 28,
                            height: 1.4,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                    if (settings.showExercisesInBreak &&
                        reason != null &&
                        reason.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      BreakTip(reason, textAlign: TextAlign.left),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
