import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_start_warning_overlay.dart';

class QuickReminderOverlay extends StatelessWidget {
  final String? reminderType;
  final String overlayType;
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;

  const QuickReminderOverlay({
    super.key,
    required this.reminderType,
    required this.overlayType,
    required this.fadeAnimation,
    required this.title,
    required this.durationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final isPosture = reminderType == 'posture';
    final isMeetingBreak = reminderType == 'meetingBreak';
    final isBreakStart =
        reminderType == 'breakStart' || overlayType == 'preBreakWarning';

    if (isBreakStart) {
      return BreakStartWarningOverlay(
        fadeAnimation: fadeAnimation,
        title: title,
        durationSeconds: durationSeconds,
        isPreBreak: overlayType == 'preBreakWarning',
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
          child: _MinimalReminderPill(
            icon: isMeetingBreak
                ? CupertinoIcons.videocam_fill
                : isPosture
                ? CupertinoIcons.person_crop_circle
                : CupertinoIcons.eye_fill,
            text: isMeetingBreak
                ? 'Break ready after your meeting'
                : isPosture
                ? 'Posture check'
                : 'Rest your eyes',
          ),
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
