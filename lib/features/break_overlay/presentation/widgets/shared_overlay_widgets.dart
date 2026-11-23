import 'package:flutter/widgets.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class BreakContextPill extends StatelessWidget {
  final BreakModel breakInfo;
  final String? exerciseTitle;

  const BreakContextPill({
    super.key,
    required this.breakInfo,
    this.exerciseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final headline = switch (breakInfo.type) {
      BreakType.short => 'Eye break',
      BreakType.long => 'Long break',
      BreakType.windDown => 'Wind-down break',
    };
    final action = exerciseTitle != null
        ? exerciseTitle!
        : breakInfo.durationSeconds <= 30
        ? 'Look away and reset your posture'
        : 'Stand, breathe, and move gently';

    final palette = BreakPalette.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.canvasRaised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: BreakOverlayTheme.fontFamily,
          height: 1.35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text(headline), const SizedBox(height: 4), Text(action)],
        ),
      ),
    );
  }
}

class StrictModeNote extends StatelessWidget {
  final String intensityLevel;

  const StrictModeNote({super.key, required this.intensityLevel});

  @override
  Widget build(BuildContext context) {
    final isLocked = intensityLevel == 'locked';
    final palette = BreakPalette.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.canvasRaised.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          isLocked
              ? 'Locked mode is active. Skip and postpone are unavailable until this break finishes.'
              : 'Strict mode is on. Skip is off for this break.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: BreakOverlayTheme.fontFamily,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
