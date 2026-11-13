import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _plum = Color(0xFF3B1F3E);

const _print = BreakPalette(
  canvas: Color(0xFFF7F0E1),
  canvasRaised: Color(0xFFEFE5D0),
  surface: Color(0xFFEFE5D0),
  border: Color(0x2E3B1F3E),
  track: Color(0x333B1F3E),
  textPrimary: _plum,
  textSecondary: Color(0xFF5E4361),
  textMuted: Color(0xFF9A8A99),
  isDark: false,
);

/// Break template: splits the tip into up to four steps and highlights each as progress advances.
class StepGuideTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const StepGuideTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  static const double _pitch = 128;
  static const double _left = 520;
  static const double _top = 150;

  // Splits the tip on sentence boundaries; previews use sample steps when the tip is too short.
  List<String> _steps(bool preview) {
    final parsed = breakInfo.tip
        .split('. ')
        .where((s) => s.trim().isNotEmpty)
        .take(4)
        .map((s) => s.trim())
        .map((s) => s.endsWith('.') ? s : '$s.')
        .toList();

    if (preview && parsed.length < 3) {
      return const [
        'Look away from the screen.',
        'Focus on something far away.',
        'Blink slowly and relax.',
      ];
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    const palette = _print;
    final accent = breakAccent(settings, 'step_guide', _plum);
    final kind = BreakKind.of(breakInfo);
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final steps = _steps(BreakPreviewScope.isPreview(context));
    final n = steps.length;

    final active = complete ? n : (progress * n).floor().clamp(0, n - 1);

    return BreakScaffold(
      palette: palette,
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: 88,
            top: 150,
            child: BreakEntrance(
              scale: false,
              child: Text(
                kind.label,
                style: BreakOverlayTheme.serif.copyWith(
                  fontSize: 28,
                  fontStyle: FontStyle.italic,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          Positioned(
            left: 80,
            top: 196,
            child: BreakEntrance(
              scale: false,
              child: BreakCountdown(
                seconds: remainingSeconds,
                textAlign: TextAlign.left,
                style: BreakOverlayTheme.serif.copyWith(
                  fontSize: 96,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -3,
                  fontFeatures: BreakOverlayTheme.tabular,
                ),
                color: breakClockColor(settings, palette),
              ),
            ),
          ),
          Positioned(
            left: _left - 40,
            top: _top - 20,
            width: 1,
            height: n * _pitch + 40,
            child: ColoredBox(color: palette.border),
          ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: _left,
              top: _top + i * _pitch,
              width: 660,
              height: _pitch,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(i + 1),
                scale: false,
                child: Semantics(
                  label:
                      'Step ${i + 1} of $n, ${i < active ? 'done' : (i == active ? 'active' : 'upcoming')}',
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: i == 0 ? _plum : palette.border,
                          width: i == 0 ? 2 : 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          child: AnimatedDefaultTextStyle(
                            duration: BreakMotion.medium,
                            style: BreakOverlayTheme.serif.copyWith(
                              fontSize: 64,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              color: i == active ? accent : palette.textMuted,
                            ),
                            child: Text('${i + 1}'),
                          ),
                        ),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: BreakMotion.medium,
                            style: BreakOverlayTheme.serif.copyWith(
                              fontSize: 28,
                              height: 1.3,
                              fontWeight: i == active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: i == active
                                  ? palette.textPrimary
                                  : palette.textMuted,
                              decoration: i < active
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: palette.textMuted,
                            ),
                            child: Text(steps[i]),
                          ),
                        ),
                      ],
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
