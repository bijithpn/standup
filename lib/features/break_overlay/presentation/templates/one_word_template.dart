import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _sand = BreakPalette(
  canvas: Color(0xFF26221F),
  canvasRaised: Color(0xFF302A26),
  surface: Color(0xFF302A26),
  border: Color(0x426B746B),
  track: Color(0x426B746B),
  textPrimary: Color(0xFFE4DCD2),
  textSecondary: Color(0xFFC7B9AB),
  textMuted: Color(0xFFB3A596),
  isDark: true,
);
const _clay = Color(0xFFC0623B);

/// Break template: one giant word (Rest or Pause) while a color fill rises with progress.
class OneWordTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const OneWordTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    const palette = _sand;
    final accent = breakAccent(settings, 'one_word', _clay);
    final word = breakInfo.type == BreakType.long ? 'Pause' : 'Rest';
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final showTip = settings.showExercisesInBreak && breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      palette: palette,
      background: Align(
        alignment: Alignment.bottomCenter,
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          color: accent,
          backgroundColor: palette.track,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 60,
            left: 88,
            child: BreakEntrance(
              scale: false,
              child: BreakCountdown(
                seconds: remainingSeconds,
                textAlign: TextAlign.left,
                style: BreakOverlayTheme.title.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                color: breakClockColor(settings, palette),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: 60,
            right: 60,
            height: 300,
            child: BreakEntrance(
              scale: false,
              duration: const Duration(milliseconds: 1200),
              child: AnimatedOpacity(
                opacity: complete ? 0 : 1,
                duration: BreakMotion.slow,
                child: Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      word,
                      maxLines: 1,
                      style: BreakOverlayTheme.serif.copyWith(
                        fontSize: 200,
                        height: 1.0,
                        letterSpacing: -5,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 88,
              bottom: 72,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(2),
                scale: false,
                child: BreakTip(
                  breakInfo.tip,
                  maxWidth: 520,
                  textAlign: TextAlign.left,
                  color: palette.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
