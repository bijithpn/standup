import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_start_warning_overlay.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_overlay.dart';

class QuickReminderOverlay extends StatelessWidget {
  final String? reminderType;
  final String overlayType;
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;

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
    this.allowFullPoster = false,
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

    final icon = isMeetingBreak
        ? CupertinoIcons.videocam_fill
        : isPosture
        ? CupertinoIcons.person_crop_circle
        : CupertinoIcons.eye_fill;
    final text = isMeetingBreak
        ? 'Break ready after your meeting'
        : isPosture
        ? 'Posture check'
        : 'Rest your eyes';

    if (allowFullPoster) {
      final palette = isMeetingBreak
          ? const _PosterPalette(
              top: Color(0xFF2E1065),
              bottom: Color(0xFF130B2E),
              blobs: [Color(0xFFA855F7), Color(0xFF6366F1), Color(0xFFEC4899)],
            )
          : isPosture
          ? const _PosterPalette(
              top: Color(0xFF1E3A8A),
              bottom: Color(0xFF1E1B4B),
              blobs: [Color(0xFFF97316), Color(0xFF3B82F6), Color(0xFFFACC15)],
            )
          : const _PosterPalette(
              top: Color(0xFF064E3B),
              bottom: Color(0xFF022C22),
              blobs: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF6EE7B7)],
            );

      return PosterReminderOverlay(
        icon: icon,
        text: text,
        fadeAnimation: fadeAnimation,
        baseColorTop: palette.top,
        baseColorBottom: palette.bottom,
        blobColors: palette.blobs,
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
          child: _MinimalReminderPill(icon: icon, text: text),
        ),
      ),
    );
  }
}

class _PosterPalette {
  final Color top;
  final Color bottom;
  final List<Color> blobs;
  const _PosterPalette({
    required this.top,
    required this.bottom,
    required this.blobs,
  });
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
