import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _paper = BreakPalette(
  canvas: Color(0xFFF4EFE6),
  canvasRaised: Color(0xFFFAF6EE),
  surface: Color(0xFFFAF6EE),
  border: Color(0x2E1F1B16),
  track: Color(0x2E1F1B16),
  textPrimary: Color(0xFF1F1B16),
  textSecondary: Color(0xFF4A423A),
  textMuted: Color(0xFF6B6157),
  isDark: false,
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
    final time = breakFormatTime(remainingSeconds);
    final numeral = BreakOverlayTheme.hero.copyWith(
      fontSize: 300,
      letterSpacing: -14,
      color: breakClockColor(settings, palette),
    );

    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      palette: palette,
      child: Stack(
        children: [
          Positioned(
            left: 96,
            right: 96,
            top: 84,
            child: BreakEntrance(
              scale: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        kind.label,
                        style: BreakOverlayTheme.title.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        breakDurationLabel(totalSeconds),
                        style: BreakOverlayTheme.body.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: palette.border),
                ],
              ),
            ),
          ),
          Positioned(
            left: 84,
            top: 170,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCompletionPulse(
                complete: complete,
                child: Semantics(
                  container: true,
                  label: '$remainingSeconds seconds remaining',
                  excludeSemantics: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: time.substring(0, 2)),
                        TextSpan(
                          text: ':',
                          style: TextStyle(color: accent),
                        ),
                        TextSpan(text: time.substring(3)),
                      ],
                    ),
                    maxLines: 1,
                    style: numeral,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 96,
            right: 96,
            top: 540,
            child: Semantics(
              label: 'Break progress',
              value: '${(progress * 100).round()}%',
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  color: accent,
                  backgroundColor: palette.border,
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 96,
              top: 580,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(2),
                scale: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    breakInfo.tip,
                    style: BreakOverlayTheme.serif.copyWith(
                      fontSize: 24,
                      height: 1.35,
                      color: palette.textSecondary,
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
