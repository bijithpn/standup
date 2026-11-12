import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _sand = BreakPalette(
  canvas: Color(0xFFEBDCC0),
  canvasRaised: Color(0xFFF3E8D2),
  surface: Color(0xFFF3E8D2),
  border: Color(0x403B2314),
  track: Color(0x403B2314),
  textPrimary: Color(0xFF3B2314),
  textSecondary: Color(0xFF4F3322),
  textMuted: Color(0xFF5E4331),
  isDark: false,
);
const _clay = Color(0xFFC0623B);

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
        child: TweenAnimationBuilder<double>(
          // Glide between per-second updates.
          tween: Tween(end: progress),
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
          builder: (context, p, _) => FractionallySizedBox(
            heightFactor: p,
            widthFactor: 1,
            child: ColoredBox(color: accent, child: const SizedBox.expand()),
          ),
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
            top: 130,
            left: 60,
            right: 60,
            height: 440,
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
                        fontSize: 400,
                        height: 1.0,
                        letterSpacing: -12,
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
