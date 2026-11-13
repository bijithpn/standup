import 'package:clock/clock.dart';

import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Answers "should the timer run right now?" from working hours, presentations, video, meetings, calendar and context-switch data.
class TimerContextManager {
  final SettingsRepository _settingsRepository;
  final SmartDetectionService? _smartDetectionService;
  final CalendarService? _calendarService;
  final PresentationDetectionService? _presentationDetectionService;
  final MeetingDetectionService? _meetingDetectionService;
  final ContextSwitchTracker? _contextSwitchTracker;

  TimerContextManager({
    required SettingsRepository settingsRepository,
    SmartDetectionService? smartDetectionService,
    CalendarService? calendarService,
    PresentationDetectionService? presentationDetectionService,
    MeetingDetectionService? meetingDetectionService,
    ContextSwitchTracker? contextSwitchTracker,
  }) : _settingsRepository = settingsRepository,
       _smartDetectionService = smartDetectionService,
       _calendarService = calendarService,
       _presentationDetectionService = presentationDetectionService,
       _meetingDetectionService = meetingDetectionService,
       _contextSwitchTracker = contextSwitchTracker;

  int recentContextSwitchCount({DateTime? now}) {
    final tracker = _contextSwitchTracker;
    if (tracker == null) return 0;
    return tracker.switchesInWindow(now ?? clock.now());
  }

  bool isHighContextSwitchRate({DateTime? now}) {
    final tracker = _contextSwitchTracker;
    if (tracker == null) return false;
    return tracker.isHighSwitchRate(now ?? clock.now());
  }

  // Malformed times fall back to permissive/default values rather than blocking the timer.
  bool isWithinWorkingHours() {
    final settings = _settingsRepository.currentSettings;
    if (!settings.workingHoursEnabled) return true;

    final now = clock.now();
    final weekday = now.weekday;

    final workingDays = settings.workingDays;
    if (!workingDays.contains(weekday)) return false;

    final startParts = settings.workStartTime.split(':');
    final endParts = settings.workEndTime.split(':');
    if (startParts.length != 2 || endParts.length != 2) return true;

    final startH = int.tryParse(startParts[0]) ?? 9;
    final startM = int.tryParse(startParts[1]) ?? 0;
    final endH = int.tryParse(endParts[0]) ?? 18;
    final endM = int.tryParse(endParts[1]) ?? 0;

    final startMinutes = startH * 60 + startM;
    final endMinutes = endH * 60 + endM;
    final nowMinutes = now.hour * 60 + now.minute;

    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  /// Pauses the work timer (presenting or watching video); meetings are handled separately via [isMeetingActive].
  bool isSmartPauseActive() {
    final settings = _settingsRepository.currentSettings;
    final pauseForPresentation =
        settings.presentationPauseEnabled &&
        (_presentationDetectionService?.isPresenting ?? false);
    final pauseForVideo =
        settings.detectVideoCalls &&
        (_smartDetectionService?.isVideoPlaying ?? false);
    return pauseForPresentation || pauseForVideo;
  }

  /// Calendar meeting or video call; the timer keeps running but breaks use the quiet reminder instead of the full overlay.
  bool isMeetingActive() {
    final settings = _settingsRepository.currentSettings;
    final inCalendarMeeting =
        settings.detectMeetings &&
        (_meetingDetectionService?.isMeetingActive ?? false);
    final inVideoCall =
        settings.detectVideoCalls &&
        (_smartDetectionService?.isVideoCallActive ?? false);
    return inCalendarMeeting || inVideoCall;
  }

  bool isPresentationActive() {
    return _presentationDetectionService?.isPresenting ?? false;
  }

  DateTime? _healthReminderResumeAt;

  bool get shouldSuppressHealthReminders {
    final settings = _settingsRepository.currentSettings;
    final blocked =
        isMeetingActive() ||
        isPresentationActive() ||
        (settings.quietModeEnabled &&
            (settings.quietModePreset == 'presenting' ||
                settings.quietModePreset == 'deep_work'));
    final now = clock.now();
    if (blocked) {
      _healthReminderResumeAt = now.add(const Duration(seconds: 30));
      return true;
    }
    return _healthReminderResumeAt?.isAfter(now) ?? false;
  }

  bool shouldRunWorkTimer() {
    return isWithinWorkingHours() && !isSmartPauseActive();
  }

  /// True once the clock-out time passes; [clockOutTriggered] prevents firing more than once per day.
  bool checkClockOut(DateTime now, bool clockOutTriggered) {
    final settings = _settingsRepository.currentSettings;
    if (!settings.enableClockOut || clockOutTriggered) return false;

    final parts = settings.clockOutTime.split(':');
    if (parts.length != 2) return false;

    final clockOutHour = int.tryParse(parts[0]) ?? 17;
    final clockOutMin = int.tryParse(parts[1]) ?? 0;
    if (now.hour > clockOutHour ||
        (now.hour == clockOutHour && now.minute >= clockOutMin)) {
      return true;
    }
    return false;
  }

  /// True if a timed calendar event starts within 10 minutes.
  Future<bool> isMeetingUpcoming() async {
    final settings = _settingsRepository.currentSettings;
    if (!settings.calendarEnabled || _calendarService == null) return false;

    final events = await _calendarService.getUpcomingEvents(
      window: const Duration(minutes: 10),
    );
    return events.any((e) => !e.isAllDay);
  }

  /// Minutes until the calendar has a gap long enough for a break, or null if free now or calendar is unavailable.
  Future<int?> minutesUntilNextFreeGap({
    Duration lookahead = const Duration(hours: 2),
  }) async {
    final settings = _settingsRepository.currentSettings;
    if (!settings.calendarEnabled || _calendarService == null) return null;

    final requiredGapMinutes = (settings.shortBreakDurationSeconds / 60)
        .ceil()
        .clamp(1, 30);

    final now = clock.now();
    List<CalendarEvent> events;
    try {
      events = await _calendarService.getEvents(now, now.add(lookahead));
    } catch (_) {
      return null;
    }

    final busy = events.where((e) => !e.isAllDay && e.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    var cursor = now;
    for (final event in busy) {
      if (event.start.isAfter(cursor)) {
        final gapMinutes = event.start.difference(cursor).inMinutes;
        if (gapMinutes >= requiredGapMinutes) {
          return cursor == now ? null : cursor.difference(now).inMinutes;
        }
      }
      if (event.end.isAfter(cursor)) cursor = event.end;
    }

    return cursor == now ? null : cursor.difference(now).inMinutes;
  }
}
