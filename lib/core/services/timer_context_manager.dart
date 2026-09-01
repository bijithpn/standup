import 'package:clock/clock.dart';

import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class TimerContextManager {
  final SettingsRepository _settingsRepository;
  final SmartDetectionService? _smartDetectionService;
  final CalendarService? _calendarService;
  final PresentationDetectionService? _presentationDetectionService;
  final MeetingDetectionService? _meetingDetectionService;

  TimerContextManager({
    required SettingsRepository settingsRepository,
    SmartDetectionService? smartDetectionService,
    CalendarService? calendarService,
    PresentationDetectionService? presentationDetectionService,
    MeetingDetectionService? meetingDetectionService,
  }) : _settingsRepository = settingsRepository,
       _smartDetectionService = smartDetectionService,
       _calendarService = calendarService,
       _presentationDetectionService = presentationDetectionService,
       _meetingDetectionService = meetingDetectionService;

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

  bool isSmartPauseActive() {
    final settings = _settingsRepository.currentSettings;
    final smartDetection = _smartDetectionService;
    if (smartDetection == null) return false;

    final pauseForVideoCall =
        settings.detectVideoCalls && smartDetection.isVideoCallActive;
    final pauseForFocus =
        settings.respectFocusMode && smartDetection.isFocusModeActive;
    final pauseForPresentation =
        settings.presentationPauseEnabled &&
        (_presentationDetectionService?.isPresenting ?? false);
    final pauseForMeeting =
        settings.detectMeetings &&
        (_meetingDetectionService?.isMeetingActive ?? false);
    return pauseForVideoCall ||
        pauseForFocus ||
        pauseForPresentation ||
        pauseForMeeting;
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

    final busy =
        events.where((e) => !e.isAllDay && e.end.isAfter(now)).toList()
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
