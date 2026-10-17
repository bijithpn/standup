import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class BreakStartWarningOverlay extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;
  final bool isPreBreak;
  final ValueNotifier<int>? remainingSecondsNotifier;
  final VoidCallback? onSkip;

  const BreakStartWarningOverlay({
    super.key,
    required this.fadeAnimation,
    required this.title,
    required this.durationSeconds,
    this.isPreBreak = false,
    this.remainingSecondsNotifier,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (isPreBreak) {
      return Center(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: fadeAnimation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: fadeAnimation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.timer,
                    color: AppTheme.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: remainingSecondsNotifier ??
                        ValueNotifier<int>(durationSeconds),
                    builder: (context, remaining, _) {
                      final displaySec = remaining > 0 ? remaining : 1;
                      return Text(
                        'Break starting in ${displaySec}s...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      );
                    },
                  ),
                  if (onSkip != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onSkip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

    final isPosture = title.toUpperCase().contains('POSTURE');
    final isEye = title.toUpperCase().contains('EYE');

    final String labelText = isPosture
        ? 'POSTURE BREAK'
        : isEye
        ? 'EYE BREAK'
        : 'UPCOMING BREAK';

    final IconData mainIcon = isPosture
        ? CupertinoIcons.person_fill
        : isEye
        ? CupertinoIcons.eye_fill
        : CupertinoIcons.timer;

    final String timeLabel = durationSeconds >= 60
        ? '${(durationSeconds / 60).round()} minute${(durationSeconds / 60).round() > 1 ? 's' : ''}'
        : '$durationSeconds seconds';

    final String dynamicMessage = isPosture
        ? 'A posture break will start in $timeLabel. Prepare to stand up.'
        : isEye
        ? 'An eye break will start in $timeLabel. Prepare to look away.'
        : 'A break will start in $timeLabel. Prepare to step away and rest.';

    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: fadeAnimation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceCard,
                AppTheme.surfaceCard.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  labelText,
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(mainIcon, color: AppTheme.accent, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                'Break Starts Soon',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dynamicMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
