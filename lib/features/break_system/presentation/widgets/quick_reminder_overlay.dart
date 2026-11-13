import 'dart:math';

import 'package:flutter/material.dart';
import 'package:breakmate/core/services/health_reminder_copy.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_start_warning_overlay.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_overlay.dart';

/// Renders short reminders and the pre-break warning: break-start card, full poster, or a minimal pill depending on type and context.
class QuickReminderOverlay extends StatefulWidget {
  final String? reminderType;
  final String overlayType;
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;
  final ValueNotifier<int>? remainingSecondsNotifier;
  final VoidCallback? onSkip;

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
  State<QuickReminderOverlay> createState() => _QuickReminderOverlayState();
}

class _QuickReminderOverlayState extends State<QuickReminderOverlay> {
  // Re-rolled per reminder type so the pill wording varies between reminders.
  int _wordingSeed = Random().nextInt(1 << 30);

  @override
  void didUpdateWidget(QuickReminderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reminderType != widget.reminderType) {
      _wordingSeed = Random().nextInt(1 << 30);
    }
  }

  String? get reminderType => widget.reminderType;
  String get overlayType => widget.overlayType;
  Animation<double> get fadeAnimation => widget.fadeAnimation;
  String get title => widget.title;
  int get durationSeconds => widget.durationSeconds;
  ValueNotifier<int>? get remainingSecondsNotifier =>
      widget.remainingSecondsNotifier;
  VoidCallback? get onSkip => widget.onSkip;
  bool get allowFullPoster => widget.allowFullPoster;

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
            'blink' => Icons.visibility_rounded,
            'posture' => Icons.accessibility_new_rounded,
            'hydration' => Icons.water_drop_rounded,
            'stretch' => Icons.self_improvement_rounded,
            'standup' => Icons.directions_walk_rounded,
            _ when HealthReminderCopy.isCustom(reminderType) =>
              Icons.notifications_active_rounded,
            _ => Icons.remove_red_eye_rounded,
          };
    final pillText = isMeetingBreak
        ? 'Break ready after your meeting'
        : HealthReminderCopy.pill(reminderType, Random(_wordingSeed));

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
