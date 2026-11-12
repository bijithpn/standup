import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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

  static const double _pitch = 64;
  static const double _left = 400;

  /// Steps are the sentences of the break's tip (up to four).
  List<String> _steps(bool preview) {
    final parsed = breakInfo.tip
        .split('. ')
        .where((s) => s.trim().isNotEmpty)
        .take(4)
        .map((s) => s.trim())
        .map((s) => s.endsWith('.') ? s : '$s.')
        .toList();
    // A one-line tip has no list to show in a thumbnail.
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
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      breakAccent(settings, 'step_guide', BreakOverlayTheme.mint),
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final steps = _steps(BreakPreviewScope.isPreview(context));
    final n = steps.length;
    // The active step follows elapsed time; every step is done at the end.
    final active = complete ? n : (progress * n).floor().clamp(0, n - 1);

    return BreakScaffold(
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: _left,
            top: 150,
            child: BreakEntrance(
              scale: false,
              child: BreakCountdown(
                seconds: remainingSeconds,
                textAlign: TextAlign.left,
                color: breakClockColor(settings, palette),
              ),
            ),
          ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: _left,
              top: 300 + i * _pitch,
              width: 480,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(i + 1),
                scale: false,
                child: Semantics(
                  label:
                      'Step ${i + 1} of $n, ${i < active ? 'done' : (i == active ? 'active' : 'upcoming')}',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: BreakMotion.medium,
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == active
                              ? accent
                              : (i < active ? palette.textMuted : null),
                          border: i > active
                              ? Border.all(color: palette.track, width: 1.5)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: BreakMotion.medium,
                          style: BreakOverlayTheme.serif.copyWith(
                            fontSize: 22,
                            height: 1.35,
                            color: i == active
                                ? palette.textPrimary
                                : palette.textMuted,
                          ),
                          child: Text(steps[i]),
                        ),
                      ),
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
