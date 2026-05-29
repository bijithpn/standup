import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Context manager class responsible for evaluating environmental triggers (work hours, DND, active calls, clock-out).
class TimerContextManager {
  final SettingsRepository _settingsRepository;
  final SmartDetectionService? _smartDetectionService;

  TimerContextManager({
    required SettingsRepository settingsRepository,
    SmartDetectionService? smartDetectionService,
  }) : _settingsRepository = settingsRepository,
       _smartDetectionService = smartDetectionService;

  bool isWithinWorkingHours() {
    final settings = _settingsRepository.currentSettings;
    if (!settings.workingHoursEnabled) return true;

    final now = DateTime.now();
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
}
