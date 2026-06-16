import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';

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
    final whyNow = breakInfo.title.toUpperCase().contains('EYE')
        ? 'Why now: eye-rest interval reached'
        : breakInfo.title.toUpperCase().contains('LONG')
        ? 'Why now: long focus block completed'
        : 'Why now: scheduled recovery break';

    final action = exerciseTitle != null
        ? 'Do: $exerciseTitle'
        : breakInfo.durationSeconds <= 30
        ? 'Do: look away and reset your posture'
        : 'Do: stand, breathe, and move gently';

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontFamily: 'Inter',
          height: 1.35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text(whyNow), const SizedBox(height: 3), Text(action)],
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1115).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(
          isLocked
              ? 'Locked mode is active. Skip and postpone are unavailable until this break finishes.'
              : 'Strict mode is active. Skip is hidden for this break intensity.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class SwipeToDismissHint extends StatelessWidget {
  const SwipeToDismissHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.chevron_up,
          size: 20,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        Text(
          'Swipe up to dismiss',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class SkipBreakButton extends StatelessWidget {
  final VoidCallback onSkip;

  const SkipBreakButton({super.key, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSkip,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Opacity(
            opacity: 0.4,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
