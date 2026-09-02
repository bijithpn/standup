import 'package:clock/clock.dart';

import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

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

  /// Number of app switches observed in the last hour — a soft fragmented-
  /// attention signal, purely informational (see [isHighContextSwitchRate]).
  int recentContextSwitchCount({DateTime? now}) {
    final tracker = _contextSwitchTracker;
    if (tracker == null) return 0;
    return tracker.switchesInWindow(now ?? clock.now());
  }

  /// Whether app-switching has been frequent enough recently to suggest
  /// fragmented focus. Deliberately never consulted by [shouldRunWorkTimer]
  /// or any break-timing decision — it's surfaced to the user (dashboard
  /// nudge), never used to silently change scheduling.
  bool isHighContextSwitchRate({DateTime? now}) {
    final tracker = _contextSwitchTracker;
    if (tracker == null) return false;
    return tracker.isHighSwitchRate(now ?? clock.now());
  }

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

  /// Whether the work timer should be auto-paused right now. Deliberately
  /// limited to reasons the user can see and control directly — being in a
  /// meeting or video call is never one of them; see [isMeetingActive],
  /// which only affects how break reminders are displayed.
  bool isSmartPauseActive() {
    final settings = _settingsRepository.currentSettings;
    final pauseForFocus =
        settings.respectFocusMode &&
        (_smartDetectionService?.isFocusModeActive ?? false);
    final pauseForPresentation =
        settings.presentationPauseEnabled &&
        (_presentationDetectionService?.isPresenting ?? false);
    return pauseForFocus || pauseForPresentation;
  }

  /// Whether the user currently appears to be in a meeting or video call —
  /// covers both calendar-synced meeting detection and frontmost-app video
  /// call detection (Zoom/Meet/Teams/etc). Never consulted by
  /// [isSmartPauseActive]/[shouldRunWorkTimer]: it only steers how break
  /// reminders are shown (a quiet notification instead of the full overlay).
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

  bool shouldRunWorkTimer() {
    return isWithinWorkingHours() && !isSmartPauseActive();
  }

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

  Future<bool> isMeetingUpcoming() async {
    final settings = _settingsRepository.currentSettings;
    if (!settings.calendarEnabled || _calendarService == null) return false;

    final events = await _calendarService.getUpcomingEvents(
      window: const Duration(minutes: 10),
    );
    return events.any((e) => !e.isAllDay);
  }

  /// Scans the calendar over [lookahead] and returns how many minutes from
  /// now the next gap of at least the configured break duration begins, or
  /// `null` if now is already clear (no calendar, or no imminent conflict).
  ///
  /// This lets a delayed break jump straight to an actual free slot between
  /// back-to-back meetings, instead of retrying on a fixed timer.
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
