import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/application/skip_policy.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class BreakStartWarningOverlay extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;
  final bool isPreBreak;
  final ValueNotifier<int>? remainingSecondsNotifier;
  final VoidCallback? onSkip;
  final VoidCallback? onSnooze;
  final VoidCallback? onClose;
  final VoidCallback? onDragStart;

  const BreakStartWarningOverlay({
    super.key,
    required this.fadeAnimation,
    required this.title,
    required this.durationSeconds,
    this.isPreBreak = false,
    this.remainingSecondsNotifier,
    this.onSkip,
    this.onSnooze,
    this.onClose,
    this.onDragStart,
  });

  Widget _action(Widget child, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style:
        TextButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: AppTheme.textSecondary,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: AppTheme.accent, width: 2)
                : null,
          ),
        ),
    child: child,
  );

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
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(
              CurvedAnimation(
                parent: fadeAnimation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeIn,
              ),
            ),
            child: GestureDetector(
              onPanStart: onDragStart == null ? null : (_) => onDragStart!(),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.scrim,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Icon(
                      CupertinoIcons.timer,
                      color: AppTheme.accent,
                      size: 16,
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable:
                          remainingSecondsNotifier ??
                          ValueNotifier<int>(durationSeconds),
                      builder: (context, remaining, _) {
                        final displaySec = remaining > 0 ? remaining : 1;
                        return Text.rich(
                          TextSpan(
                            text: 'Break starting in ',
                            children: [
                              TextSpan(
                                text: '${displaySec}s',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontFeatures: AppTheme.tabular,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        );
                      },
                    ),
                    if (onSnooze != null)
                      _action(
                        Text('Snooze ${SkipPolicy.snoozeMinutes} min'),
                        onSnooze!,
                      ),
                    if (onSkip != null) _action(const Text('Skip'), onSkip!),
                    if (onClose != null)
                      _action(
                        const Icon(
                          CupertinoIcons.xmark,
                          size: 16,
                          semanticLabel: 'Dismiss',
                        ),
                        onClose!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isPosture = title.toUpperCase().contains('POSTURE');
    final isEye = title.toUpperCase().contains('EYE');

    final IconData mainIcon = isPosture
        ? CupertinoIcons.person
        : isEye
        ? CupertinoIcons.eye
        : CupertinoIcons.timer;

    final String timeLabel = durationSeconds >= 60
        ? '${(durationSeconds / 60).round()} minute${(durationSeconds / 60).round() > 1 ? 's' : ''}'
        : '$durationSeconds seconds';

    final String dynamicMessage = isPosture
        ? 'Stand up in $timeLabel.'
        : isEye
        ? 'Look away from the screen in $timeLabel.'
        : 'Step away and rest in $timeLabel.';

    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(
          CurvedAnimation(
            parent: fadeAnimation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.scrim,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mainIcon, color: AppTheme.accent, size: 24),
              const SizedBox(height: 16),
              Text(
                'Break starts soon',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
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
