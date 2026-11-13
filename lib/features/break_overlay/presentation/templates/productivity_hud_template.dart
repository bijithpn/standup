import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _slate = Color(0xFF161C24);
const _coral = Color(0xFF94B8AD);

const _hudPalette = BreakPalette(
  canvas: _slate,
  canvasRaised: Color(0xFF1E2630),
  surface: Color(0xFF1E2630),
  border: Color(0x18FFFFFF),
  track: Color(0x20FFFFFF),
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
      accent: accent,
      child: Center(
        child: BreakEntrance(
          scale: false,
          child: Container(
            width: 760,
            padding: const EdgeInsets.all(56),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                const SizedBox(height: 48),
                BreakCompletionPulse(
                  complete: complete,
                  child: BreakCountdown(
                    seconds: remainingSeconds,
                    textAlign: TextAlign.left,
                    style: BreakOverlayTheme.hero.copyWith(
                      fontSize: 144,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -6,
                    ),
                    color: breakClockColor(settings, palette),
                  ),
                ),
                const SizedBox(height: 32),
                Semantics(
                  label: '${kind.label} progress',
                  value: '${(progress * 100).round()}%',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: accent,
                      backgroundColor: palette.track,
                    ),
                  ),
                ),
                if (showTip) ...[
                  const SizedBox(height: 28),
                  Text(
                    breakInfo.tip,
                    style: BreakOverlayTheme.body.copyWith(
                      fontSize: 18,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
