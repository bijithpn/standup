import 'dart:async';
import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/core/services/adaptive_break_service.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/smart_detection_service.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_repository.dart';

export 'package:standup/features/break_system/domain/break_model.dart' show BreakType;

enum TimerState { running, paused, idle, breakActive }

enum WorkMode { pomodoro, deepWork, flexible, strict }

class TimerEngine extends ChangeNotifier {
  final ActivityMonitor _activityMonitor;
  final NotificationService _notificationService;
  final SettingsRepository _settingsRepository;
  final AdaptiveBreakService? _adaptiveBreakService;
  final SmartDetectionService? _smartDetectionService;
  final AppLogger _logger = AppLogger();

  Timer? _tickTimer;
  Timer? _usageTrackerTimer;
  Timer? _pauseAutoResumeTimer;

  TimerState _state = TimerState.idle;
  WorkMode _mode = WorkMode.flexible;
  BreakModel? _activeBreak;
  int _countdownSeconds = 0;
  bool _isCompletionState = false;
  bool _isFlashing = false;
  bool _isPreBreak = false;
  bool _clockOutTriggered = false;

  Duration _workElapsed = Duration.zero;
  Duration _totalWorkToday = Duration.zero;
  DateTime? _lastTickTime;

  // Runtime-applied settings (updated by updateSettings)
  int _shortBreakIntervalMinutes = AppConstants.defaultShortBreakIntervalMinutes;
  int _shortBreakDurationSeconds = AppConstants.defaultShortBreakDurationSeconds;
  int _longBreakIntervalMinutes = AppConstants.defaultLongBreakIntervalMinutes;
  int _longBreakDurationMinutes = AppConstants.defaultLongBreakDurationMinutes;
  int _pauseTimerAfterMinutes = 5;
  int _resetTimerAfterMinutes = 15;
  DateTime? _longBreakWindowStartedAt;

  TimerEngine({
    required ActivityMonitor activityMonitor,
    required NotificationService notificationService,
    required SettingsRepository settingsRepository,
    AdaptiveBreakService? adaptiveBreakService,
    SmartDetectionService? smartDetectionService,
  })  : _activityMonitor = activityMonitor,
        _notificationService = notificationService,
        _settingsRepository = settingsRepository,
        _adaptiveBreakService = adaptiveBreakService,
        _smartDetectionService = smartDetectionService {
    _syncSettingsFromRepo();
  }

  void _syncSettingsFromRepo() {
    final s = _settingsRepository.currentSettings;
    _shortBreakIntervalMinutes = s.shortBreakIntervalMinutes;
    _shortBreakDurationSeconds = s.shortBreakDurationSeconds;
    _longBreakIntervalMinutes = s.longBreakIntervalMinutes;
    _longBreakDurationMinutes = s.longBreakDurationMinutes;
    _pauseTimerAfterMinutes = s.pauseTimerAfterMinutes;
    _resetTimerAfterMinutes = s.resetTimerAfterMinutes;
  }

  TimerState get state => _state;
  WorkMode get mode => _mode;
  BreakModel? get activeBreak => _activeBreak;
  int get countdownSeconds => _countdownSeconds;
  bool get isCompletionState => _isCompletionState;
  bool get isFlashing => _isFlashing;
  bool get isPreBreak => _isPreBreak;
  Duration get totalWorkToday => _totalWorkToday;

  Duration get timeUntilNextShortBreak {
    final interval = Duration(minutes: _shortBreakIntervalMinutes);
    final remaining = interval - _workElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canPostpone => true;

  void setWorkMode(WorkMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void startTimers() {
    _syncSettingsFromRepo();
    _state = TimerState.running;
    _isPreBreak = false;
    _workElapsed = Duration.zero;
    _lastTickTime = DateTime.now();
    _clockOutTriggered = false;

    _startTicking();
    _setupActivityMonitor();
    _startUsageTracking();

    _logger.info('Timers started in $_mode mode');
    notifyListeners();
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TimerState.paused || _state == TimerState.idle) return;

      final now = DateTime.now();
      final delta = now.difference(_lastTickTime ?? now);
      _lastTickTime = now;

      if (_state == TimerState.running) {
        if (_checkClockOut(now)) return;
        if (!_shouldRunWorkTimer()) {
          _updateTray();
          notifyListeners();
          return;
        }
        _workElapsed += delta;
        _totalWorkToday += delta;
        _checkBreakConditions();
      } else if (_state == TimerState.breakActive) {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) {
          finishBreak(skipped: false);
          return;
        }
      }

      _updateTray();
      notifyListeners();
    });
  }

  bool _isWithinWorkingHours() {
    final settings = _settingsRepository.currentSettings;
    if (!settings.workingHoursEnabled) return true;

    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon, 7=Sun

    // Check working days (default Mon-Fri)
    final workingDays = settings.workingDays;
    if (!workingDays.contains(weekday)) return false;

    // Parse start/end times
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

  bool _isSmartPauseActive() {
    final settings = _settingsRepository.currentSettings;
    final smartDetection = _smartDetectionService;
    if (smartDetection == null) return false;

    final pauseForVideoCall =
        settings.detectVideoCalls && smartDetection.isVideoCallActive;
    final pauseForFocus =
        settings.respectFocusMode && smartDetection.isFocusModeActive;
    return pauseForVideoCall || pauseForFocus;
  }

  bool _shouldRunWorkTimer() {
    return _isWithinWorkingHours() && !_isSmartPauseActive();
  }

  bool _checkClockOut(DateTime now) {
    final settings = _settingsRepository.currentSettings;
    if (!settings.enableClockOut || _clockOutTriggered) return false;

    final parts = settings.clockOutTime.split(':');
    if (parts.length != 2) return false;

    final clockOutHour = int.tryParse(parts[0]) ?? 17;
    final clockOutMin = int.tryParse(parts[1]) ?? 0;
    if (now.hour > clockOutHour ||
        (now.hour == clockOutHour && now.minute >= clockOutMin)) {
      _clockOutTriggered = true;
      _triggerClockOut();
      return true;
    }
    return false;
  }

  void _checkBreakConditions() {
    final interval = Duration(minutes: _shortBreakIntervalMinutes);
    final remaining = interval - _workElapsed;

    // 20-second pre-break warning
    if (remaining <= const Duration(seconds: 20) && !_isPreBreak) {
      _isPreBreak = true;
      notifyListeners();
    }

    if (_workElapsed >= interval) {
      _isPreBreak = false;
      _triggerBreak();
    }
  }

  void _triggerClockOut() {
    _state = TimerState.breakActive;
    _workElapsed = Duration.zero;
    _countdownSeconds = 60; // 1-minute clock-out reminder

    _activeBreak = BreakModel(
      type: BreakType.long,
      durationSeconds: _countdownSeconds,
      title: 'CLOCK OUT',
      tip: 'Your workday is over. Time to step away and live your life.',
    );

    _notificationService.showClockOutReminder();
    _logger.info('Clock out triggered');
    notifyListeners();
  }

  void setFocusMode(bool enabled) {
    notifyListeners();
  }

  void _triggerBreak() {
    _state = TimerState.breakActive;
    _workElapsed = Duration.zero;

    final isLongBreak = _isLongBreakDue();

    if (isLongBreak) {
      _countdownSeconds = _longBreakDurationMinutes * 60;
      _activeBreak = BreakModel(
        type: BreakType.long,
        durationSeconds: _countdownSeconds,
        title: 'LONG BREAK',
        tip: 'Time to stand, stretch, and mentally reset. Step away from your desk.',
      );
      _longBreakWindowStartedAt = DateTime.now();
    } else {
      final suggestedDuration = _adaptiveBreakService?.getSuggestedBreakDuration() ??
          _shortBreakDurationSeconds;
      _countdownSeconds = suggestedDuration;
      _activeBreak = BreakModel(
        type: BreakType.short,
        durationSeconds: _countdownSeconds,
        title: 'Eye Rest',
        tip: _randomTip(AppConstants.shortBreakTips),
      );
    }

    sl<TrayManagerService>().setBreakActive(true);
    
    _logger.info('Break triggered: ${_activeBreak!.title}');
    notifyListeners();
  }

  Future<void> finishBreak({required bool skipped}) async {
    if (_state != TimerState.breakActive) return;

    if (skipped) {
      sl<StatsService>().recordSkippedBreak();
    } else {
      _isCompletionState = true;
      notifyListeners();
      
      // Update overlay to show completion state if needed
      MacOSBridge.updateOverlayData({
        'title': 'Well Done!',
        'remainingSeconds': 0,
        'durationSeconds': _activeBreak?.durationSeconds ?? _shortBreakDurationSeconds,
        'strictMode': false, // Allow closing now
      });

      await Future.delayed(const Duration(seconds: 2));
      sl<StatsService>().recordCompletedBreak();
      
      if (!sl<OverlayWindowService>().isOverlayVisible) {
        await _notificationService.showBreakFinished();
      }
    }

    _activeBreak = null;
    _isCompletionState = false;
    _state = TimerState.running;
    _isPreBreak = false;
    _lastTickTime = DateTime.now();
    _workElapsed = Duration.zero;
    sl<TrayManagerService>().setBreakActive(false);

    notifyListeners();
  }

  bool _isLongBreakDue() {
    final now = DateTime.now();
    _longBreakWindowStartedAt ??= now;
    final elapsedSinceLong = now.difference(_longBreakWindowStartedAt!);
    return elapsedSinceLong >= Duration(minutes: _longBreakIntervalMinutes);
  }

  /// Apply new settings at runtime without restarting timers.
  void updateSettings({
    int? shortIntervalMinutes,
    int? shortDurationSeconds,
    int? longIntervalMinutes,
    int? longDurationSeconds,
    int? pauseAfterMinutes,
    int? resetAfterMinutes,
  }) {
    if (shortIntervalMinutes != null) _shortBreakIntervalMinutes = shortIntervalMinutes;
    if (shortDurationSeconds != null) _shortBreakDurationSeconds = shortDurationSeconds;
    if (longIntervalMinutes != null) _longBreakIntervalMinutes = longIntervalMinutes;
    if (longDurationSeconds != null) {
      _longBreakDurationMinutes = (longDurationSeconds / 60).ceil();
    }
    if (pauseAfterMinutes != null) _pauseTimerAfterMinutes = pauseAfterMinutes;
    if (resetAfterMinutes != null) _resetTimerAfterMinutes = resetAfterMinutes;

    // Update activity monitor idle threshold
    _activityMonitor.setIdleThreshold(_pauseTimerAfterMinutes);
    _notificationService
        .setNotificationsEnabled(_settingsRepository.currentSettings.notificationsEnabled);
    _notificationService.setSoundEnabled(_settingsRepository.currentSettings.soundEnabled);

    _logger.info('Settings updated at runtime: interval=$_shortBreakIntervalMinutes min, '
        'duration=$_shortBreakDurationSeconds s');
    notifyListeners();
  }

  void updateMenuStyle(String style) {
    sl<TrayManagerService>().setIconModeFromStyle(
      _settingsRepository.currentSettings.trayIconStyle,
    );
    _updateTray();
  }

  void _updateTray() {
    final settings = _settingsRepository.currentSettings;

    final remaining = _state == TimerState.breakActive
        ? Duration(seconds: _countdownSeconds)
        : timeUntilNextShortBreak;

    final mins = remaining.inMinutes;
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final title = settings.menuBarStyle == 'countdown' ||
            settings.trayIconStyle == 'countdown'
        ? '$mins:$secs'
        : '';
    sl<TrayManagerService>().setTrayTitle(title);

    final status = _state == TimerState.breakActive
        ? 'Break active'
        : _isSmartPauseActive()
            ? 'Paused for meeting or Focus'
            : !_isWithinWorkingHours()
                ? 'Paused outside working hours'
                : _state == TimerState.paused
                    ? 'Paused'
                    : 'Next break';
    sl<TrayManagerService>().setTooltip('$status in $mins:$secs');
  }

  void _setupActivityMonitor() {
    _activityMonitor.setIdleThreshold(_pauseTimerAfterMinutes);
    _activityMonitor.setActivityCallback((isActive) {
      if (isActive && _state == TimerState.paused) {
        // Check if we should reset or just resume
        resumeTimers();
      } else if (!isActive && _state == TimerState.running) {
        pauseTimers();
        // Schedule reset if idle too long
        _pauseAutoResumeTimer?.cancel();
        _pauseAutoResumeTimer = Timer(
          Duration(minutes: _resetTimerAfterMinutes),
          () {
            if (_state == TimerState.paused) {
              _workElapsed = Duration.zero;
              _logger.info('Timer reset after $_resetTimerAfterMinutes min idle');
            }
          },
        );
      }
    });
    _activityMonitor.start();
  }

  void pauseTimers() {
    if (_state == TimerState.breakActive) return;
    _state = TimerState.paused;
    notifyListeners();
  }

  void resumeTimers() {
    if (_state == TimerState.breakActive) return;
    _state = TimerState.running;
    _isPreBreak = false;
    _lastTickTime = DateTime.now();
    // Re-check working hours on resume
    if (!_isWithinWorkingHours()) {
      _state = TimerState.paused;
    }
    notifyListeners();
  }

  void resetTimers() {
    _workElapsed = Duration.zero;
    _state = TimerState.idle;
    _clockOutTriggered = false;
    notifyListeners();
  }

  void triggerBreakNow({bool isLong = false}) {
    if (isLong) {
      _longBreakWindowStartedAt = DateTime.now()
          .subtract(Duration(minutes: _longBreakIntervalMinutes));
    }
    _triggerBreak();
  }

  void skipNextBreak() {
    _workElapsed = Duration.zero;
    sl<StatsService>().recordSkippedBreak();
    notifyListeners();
  }

  void postponeBreak() {
    _countdownSeconds += 120;
    notifyListeners();
  }

  void saveState() {}

  void _startUsageTracking() {
    _usageTrackerTimer?.cancel();
    _usageTrackerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_state == TimerState.running) {
        sl<StatsService>().addUsageMinutes(1);
      }
    });
  }

  void triggerFlashDemo({
    required Color color,
    required String style,
    required String animation,
    required double intensity,
    required int durationMs,
  }) {
    _isFlashing = true;
    notifyListeners();
    Timer(Duration(milliseconds: durationMs), () {
      _isFlashing = false;
      notifyListeners();
    });
  }

  String _randomTip(List<String> tips) {
    final copy = List<String>.from(tips)..shuffle();
    return copy.first;
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _usageTrackerTimer?.cancel();
    _pauseAutoResumeTimer?.cancel();
    super.dispose();
  }
}
