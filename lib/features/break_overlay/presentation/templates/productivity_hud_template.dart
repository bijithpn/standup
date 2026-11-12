import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _slate = Color(0xFF1E2A36);
const _coral = Color(0xFFFF6B57);

const _hudPalette = BreakPalette(
  canvas: _slate,
  canvasRaised: Color(0xFF2A3947),
  surface: Color(0xFF2A3947),
  border: Color(0x33FFFFFF),
  track: Color(0x2E1E2A36),
  textPrimary: Color(0xFFF6F1EA),
  textSecondary: Color(0xFFB4C0CC),
  textMuted: Color(0xFF8394A5),
  isDark: true,
);

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
    const palette = _hudPalette;
    final kind = BreakKind.of(breakInfo);
    final accent = BreakOverlayTheme.resolveAccent(
      settings.templateAccentOverrides,
      'hud',
      _coral,
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final showTip = settings.showExercisesInBreak && breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      palette: palette,
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: _slate,
      background: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.52,
          widthFactor: 1,
          child: ColoredBox(color: accent),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 88,
            top: 128,
            child: BreakEntrance(
              scale: false,
              child: Text(
                kind.label,
                style: BreakOverlayTheme.hero.copyWith(
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -3,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 92,
              top: 228,
              width: 520,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(1),
                scale: false,
                child: Text(
                  breakInfo.tip,
                  style: BreakOverlayTheme.serif.copyWith(
                    fontSize: 24,
                    height: 1.45,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 88,
            top: 112,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Text(
                '${(progress * 100).round()}%',
                style: BreakOverlayTheme.hero.copyWith(
                  fontSize: 96,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -4,
                  color: accent,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 384,
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
                      height: 16,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(color: palette.track),
                          ),
                          FractionallySizedBox(
                            widthFactor: anim.value.clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: const ColoredBox(color: _slate),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 72,
            bottom: 8,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(3),
              scale: false,
              child: BreakCompletionPulse(
                complete: complete,
                child: BreakCountdown(
                  seconds: remainingSeconds,
                  style: BreakOverlayTheme.hero.copyWith(
                    fontSize: 300,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -14,
                  ),
                  textAlign: TextAlign.left,
                  color: breakClockColor(settings, palette, fallback: _slate),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
