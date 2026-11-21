import 'dart:math';

import 'package:flutter/material.dart';
import 'package:breakmate/core/services/health_reminder_messages.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_registry.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_start_warning_overlay.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_overlay.dart';

/// Renders short reminders and the pre-break warning: break-start card, full poster, or a compact template-styled card depending on type and context.
class QuickReminderOverlay extends StatefulWidget {
  final String? reminderType;
  final String overlayType;
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;
  final ValueNotifier<int>? remainingSecondsNotifier;
  final VoidCallback? onSkip;
  final VoidCallback? onSnooze;

  final bool allowFullPoster;
  final String templateId;

  const QuickReminderOverlay({
    super.key,
    required this.reminderType,
    required this.overlayType,
    required this.fadeAnimation,
    required this.title,
    required this.durationSeconds,
    this.remainingSecondsNotifier,
    this.onSkip,
    this.onSnooze,
    this.allowFullPoster = false,
    this.templateId = defaultWellnessTemplateId,
  });

  @override
  State<QuickReminderOverlay> createState() => _QuickReminderOverlayState();
}

class _QuickReminderOverlayState extends State<QuickReminderOverlay> {
  // Re-rolled per reminder type so the pill wording varies between reminders.
  int _wordingSeed = Random().nextInt(1 << 30);
  final int _startedAtMs = DateTime.now().millisecondsSinceEpoch;

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
  VoidCallback? get onSnooze => widget.onSnooze;
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
        onSnooze: onSnooze,
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
            _ when HealthReminderMessages.isCustom(reminderType) =>
              Icons.notifications_active_rounded,
            _ => Icons.remove_red_eye_rounded,
          };
    final pillText = isMeetingBreak
        ? 'Break ready after your meeting'
        : HealthReminderMessages.pill(reminderType, Random(_wordingSeed));

    if (allowFullPoster) {
      final posterText = isMeetingBreak
          ? 'Break ready after your meeting!'
          : HealthReminderMessages.poster(reminderType);

      return PosterReminderOverlay(
        icon: icon,
        text: posterText,
        fadeAnimation: fadeAnimation,
      );
    }

    final kind = switch (reminderType) {
      'blink' => ReminderKind.eyes,
      'posture' => ReminderKind.posture,
      'hydration' => ReminderKind.hydration,
      'stretch' => ReminderKind.stretch,
      'standup' => ReminderKind.standup,
      'meetingBreak' => ReminderKind.mindful,
      _ when HealthReminderMessages.isCustom(reminderType) =>
        ReminderKind.mindful,
      _ => ReminderKind.eyes,
    };
    final template = wellnessTemplateById(widget.templateId);
    final tier = resolveTier(
      animationsEnabled: true,
      reduceMotionPref: false,
      osReduce: MediaQuery.disableAnimationsOf(context),
    );
    final eased = CurvedAnimation(
      parent: fadeAnimation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: eased,
          builder: (_, child) => Opacity(
            opacity: eased.value,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - eased.value)),
              child: child,
            ),
          ),
          child: MotionScope(
            startedAtMs: _startedAtMs,
            tier: tier,
            builder: (context, clock) => _ReminderCard(
              palette: template.palette,
              text: pillText,
              art: template.reminderArt(context, kind, clock),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final BreakPalette palette;
  final String text;
  final Widget art;

  const _ReminderCard({
    required this.palette,
    required this.text,
    required this.art,
  });

  @override
  Widget build(BuildContext context) {
    final contrast = MediaQuery.highContrastOf(context);
    final dark = palette.isDark;
    final surface = contrast
        ? (dark ? Colors.black : Colors.white)
        : palette.surface;
    final foreground = contrast
        ? (dark ? Colors.white : Colors.black)
        : palette.textPrimary;
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: contrast ? foreground : palette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: RepaintBoundary(child: art),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
