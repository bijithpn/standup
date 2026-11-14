import 'package:intl/intl.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';
import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/features/settings/settings_model.dart';

/// Human-readable answer to "why is my timer in this state?", shown by TimerExplanationOverlayService.
class TimerExplanation {
  final String stateSummary;
  final List<String> reasons;
  final List<String> activeSmartFeatures;

  const TimerExplanation({
    required this.stateSummary,
    required this.reasons,
    required this.activeSmartFeatures,
  });
}

/// Builds the explanation from current timer state and the context manager's smart-detection signals.
TimerExplanation buildTimerExplanation({
  required TimerState timerState,
  required TimerContextManager contextManager,
  required SettingsModel settings,
  DateTime? snoozeResumeAt,
  bool? isManualPause,
}) {
  final smartPauseActive = contextManager.isSmartPauseActive();
  final withinWorkingHours = contextManager.isWithinWorkingHours();
  final presenting = contextManager.isPresentationActive();
  final inMeeting = contextManager.isMeetingActive();
  final highSwitchRate = contextManager.isHighContextSwitchRate();

  final reasons = <String>[];

  if (!withinWorkingHours) {
    reasons.add("You're outside your configured working hours.");
  }
  if (smartPauseActive) {
    if (presenting && settings.presentationPauseEnabled) {
      reasons.add(
        'A presentation or screen share is active, so the timer is paused.',
      );
    }
  }
  if (inMeeting) {
    reasons.add(
      "You're in a meeting or video call — break reminders stay quiet "
      'instead of showing the full overlay.',
    );
  }
  if (highSwitchRate) {
    final count = contextManager.recentContextSwitchCount();
    reasons.add(
      "You've switched apps $count times in the last hour — shown for "
      'awareness only, this never changes break timing.',
    );
  }

  final stateSummary = switch (timerState) {
    TimerState.breakActive => 'A break is active right now.',
    TimerState.paused when snoozeResumeAt != null =>
      'Snoozed until ${DateFormat.jm().format(snoozeResumeAt)}. Your focus countdown resumes when your schedule and detection allow.',
    TimerState.paused when isManualPause == true => 'Timer is manually paused.',
    TimerState.paused when !withinWorkingHours =>
      'Timer is paused outside working hours or during lunch.',
    TimerState.paused when smartPauseActive =>
      'Timer is paused by a smart-detection rule.',
    TimerState.paused => 'Timer is manually paused.',
    TimerState.windDown => 'Timer is winding down for the day.',
    TimerState.idle => 'Timer is idle.',
    TimerState.running => 'Timer is running normally.',
  };

  final activeFeatures = <String>[
    if (settings.presentationPauseEnabled) 'Presentation pause',
    if (settings.detectMeetings) 'Meeting detection',
    if (settings.detectVideoCalls) 'Video call detection',
    if (settings.calendarEnabled) 'Calendar-aware scheduling',
    if (settings.appUsageTrackingEnabled) 'App usage tracking',
  ];

  return TimerExplanation(
    stateSummary: stateSummary,
    reasons: reasons,
    activeSmartFeatures: activeFeatures,
  );
}
