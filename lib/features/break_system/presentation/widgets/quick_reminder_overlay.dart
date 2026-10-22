import 'package:flutter/material.dart';
import 'package:breakmate/core/services/health_reminder_copy.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_start_warning_overlay.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_overlay.dart';

class QuickReminderOverlay extends StatelessWidget {
  final String? reminderType;
  final String overlayType;
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;
  final ValueNotifier<int>? remainingSecondsNotifier;
  final VoidCallback? onSkip;

  /// Whether it's safe to show the full-screen [PosterReminderOverlay]
  /// instead of the small translucent pill. Defaults to `false` so every
  /// existing caller keeps today's pill-only behavior unless it explicitly
  /// opts in after checking meeting/presentation state (see
  /// `poster_reminder_gate.dart`).
  final bool allowFullPoster;

  const QuickReminderOverlay({
    super.key,
    required this.reminderType,
    required this.overlayType,
    required this.fadeAnimation,
    required this.title,
    required this.durationSeconds,
    this.remainingSecondsNotifier,
    this.onSkip,
    this.allowFullPoster = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMeetingBreak = reminderType == 'meetingBreak';
    final isBreakStart =
        reminderType == 'breakStart' || overlayType == 'preBreakWarning';

    if (isBreakStart) {
      return BreakStartWarningOverlay(
        fadeAnimation: fadeAnimation,
        title: title,
        durationSeconds: durationSeconds,
        isPreBreak: overlayType == 'preBreakWarning',
        remainingSecondsNotifier: remainingSecondsNotifier,
        onSkip: onSkip,
      );
    }

    final icon = isMeetingBreak
        ? Icons.videocam_rounded
        : switch (reminderType) {
            'posture' => Icons.accessibility_new_rounded,
            'hydration' => Icons.water_drop_rounded,
            'stretch' => Icons.self_improvement_rounded,
            'standup' => Icons.directions_walk_rounded,
            _ => Icons.remove_red_eye_rounded,
          };
    final pillText = isMeetingBreak
        ? 'Break ready after your meeting'
        : HealthReminderCopy.pill(reminderType);

    if (allowFullPoster) {
      final posterText = isMeetingBreak
          ? 'Break ready after your meeting!'
          : HealthReminderCopy.poster(reminderType);

      return PosterReminderOverlay(
        icon: icon,
        text: posterText,
        fadeAnimation: fadeAnimation,
      );
    }

    return Center(
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: fadeAnimation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(
              parent: fadeAnimation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeIn,
            ),
          ),
          child: _MinimalReminderPill(icon: icon, text: pillText),
        ),
      ),
    );
  }
}

class _MinimalReminderPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MinimalReminderPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.86), size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
