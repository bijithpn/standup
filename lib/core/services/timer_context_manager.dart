import 'package:clock/clock.dart';

import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class TimerContextManager {
  final SettingsRepository _settingsRepository;
  final SmartDetectionService? _smartDetectionService;
  final CalendarService? _calendarService;

  TimerContextManager({
    required SettingsRepository settingsRepository,
    SmartDetectionService? smartDetectionService,
    CalendarService? calendarService,
  }) : _settingsRepository = settingsRepository,
       _smartDetectionService = smartDetectionService,
       _calendarService = calendarService;

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
    return pauseForVideoCall || pauseForFocus;
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
}
