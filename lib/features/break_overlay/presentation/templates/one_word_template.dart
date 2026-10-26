import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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
    final palette = BreakPalette.of(context);
    final kind = BreakKind.of(breakInfo);
    final accent = palette.accentOn(
      breakAccent(settings, 'one_word', kind.accent),
    );
    final word = breakInfo.type == BreakType.long ? 'Pause' : 'Rest';
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final reduced = BreakMotion.reduced(context);
    final showTip = settings.showExercisesInBreak && breakInfo.tip.isNotEmpty;
    final base = palette.textSecondary.withValues(alpha: 0.5);

    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            top: 270,
            left: 128,
            right: 128,
            height: 180,
            child: BreakEntrance(
              scale: false,
              duration: const Duration(milliseconds: 1200),
              child: AnimatedOpacity(
                opacity: complete ? 0 : 1,
                duration: BreakMotion.slow,
                child: Semantics(
                  header: true,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TweenAnimationBuilder<double>(
                        // Glide between per-second updates.
                        tween: Tween(end: progress),
                        duration: const Duration(seconds: 1),
                        curve: Curves.linear,
                        builder: (context, p, _) => ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            // Accent above the drain line, base colour below.
                            stops: [p, p],
                            colors: [accent, base],
                          ).createShader(bounds),
                          child: Text(
                            word.toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: BreakOverlayTheme.fontFamily,
                              fontSize: 140,
                              fontWeight: FontWeight.w200,
                              height: 1.0,
                              color: Colors.white,
                              letterSpacing: reduced ? 6 : 12 * p,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 454,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCountdown(
                seconds: remainingSeconds,
                style: BreakOverlayTheme.title,
                color: breakClockColor(
                  settings,
                  palette,
                  fallback: palette.textMuted,
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Center(
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(2),
                  scale: false,
                  child: BreakTip(breakInfo.tip),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
