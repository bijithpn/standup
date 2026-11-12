import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class ProductivityHudTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ProductivityHudTemplate({
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
        'hud',
        kind.accent,
      ),
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
            left: 160,
            top: 250,
            child: BreakEntrance(
              scale: false,
              child: Text(
                kind.label,
                style: BreakOverlayTheme.body.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          Positioned(
            left: 160,
            top: 280,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCompletionPulse(
                complete: complete,
                child: BreakCountdown(
                  seconds: remainingSeconds,
                  style: BreakOverlayTheme.hero.copyWith(fontSize: 112),
                  textAlign: TextAlign.left,
                  color: breakClockColor(settings, palette),
                ),
              ),
            ),
          ),
          Positioned(
            left: 160,
            right: 160,
            top: 430,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(2),
              scale: false,
              child: Semantics(
                label: '${kind.label} progress',
                value: '${(progress * 100).round()}%',
                child: BreakSmoothProgress(
                  progress: progress,
                  builder: (context, anim) => AnimatedBuilder(
                    animation: anim,
                    builder: (context, _) => SizedBox(
                      height: 2,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(color: palette.track),
                          ),
                          FractionallySizedBox(
                            widthFactor: anim.value.clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: ColoredBox(color: accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 160,
              top: 470,
              width: 560,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(3),
                scale: false,
                child: Text(
                  breakInfo.tip,
                  style: BreakOverlayTheme.serif.copyWith(
                    fontSize: 20,
                    height: 1.5,
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
