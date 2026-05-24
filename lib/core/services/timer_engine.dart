import 'dart:async';
import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/core/services/adaptive_break_service.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/smart_detection_service.dart';
import 'package:standup/core/services/storage_service.dart';
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
  final StorageService _storageService;
  final AdaptiveBreakService? _adaptiveBreakService;
  final SmartDetectionService? _smartDetectionService;
  final EventBus _eventBus;
  final AppLogger _logger = AppLogger();

  Timer? _tickTimer;
  Timer? _usageTrackerTimer;
  Timer? _pauseAutoResumeTimer;

  TimerState _state = TimerState.idle;
  WorkMode _mode = WorkMode.flexible;
  BreakModel? _activeBreak;
  int _countdownSeconds = 0;
  bool _isCompletionState = false;
  int _postureElapsedSeconds = 0;
  int _eyeBlinkElapsedSeconds = 0;

  bool _isPreBreak = false;
  bool _clockOutTriggered = false;

  Duration _workElapsed = Duration.zero;
  Duration _totalWorkToday = Duration.zero;
  DateTime? _lastTickTime;
  DateTime? _lastBreakFinishedAt; // Added to track session duration accurately

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
    required StorageService storageService,
    AdaptiveBreakService? adaptiveBreakService,
    SmartDetectionService? smartDetectionService,
    EventBus? eventBus,
  })  : _activityMonitor = activityMonitor,
        _notificationService = notificationService,
        _settingsRepository = settingsRepository,
        _storageService = storageService,
        _adaptiveBreakService = adaptiveBreakService,
        _smartDetectionService = smartDetectionService,
        _eventBus = eventBus ?? EventBus.instance {
    _syncSettingsFromRepo();
  }

  void _emit(AppEvent event) => _eventBus.emit(event);

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
    
    // Attempt to restore state first
    restoreState();
    
    // If it was already running or break active, keep it that way
    if (_state == TimerState.idle) {
      _state = TimerState.running;
      _isPreBreak = false;
      _workElapsed = Duration.zero;
      _clockOutTriggered = false;
    } else if (_state == TimerState.breakActive && _activeBreak == null) {
      _activeBreak = BreakModel(
         type: BreakType.short,
         durationSeconds: _countdownSeconds > 0 ? _countdownSeconds : _shortBreakDurationSeconds,
         title: 'Break Resumed',
         tip: 'Take a breather.',
       );
    }
    
    _lastTickTime = DateTime.now();

    _startTicking();
    _setupActivityMonitor();
    _startUsageTracking();

    _emit(TimerStateChangedEvent(
      state: _state == TimerState.breakActive ? TimerStateEvent.breakActive : TimerStateEvent.running,
      countdownSeconds: _countdownSeconds,
      workElapsedSeconds: _workElapsed.inSeconds,
    ));

    _logger.info('Timers started (State: $_state) in $_mode mode');
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
        _postureElapsedSeconds += delta.inSeconds;
        _eyeBlinkElapsedSeconds += delta.inSeconds;
        _checkBreakConditions();
        _checkHealthReminders();
      } else if (_state == TimerState.breakActive) {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) {
          finishBreak(skipped: false);
          return;
        }
      }

      _emit(TimerStateChangedEvent(
        state: _state == TimerState.breakActive
            ? TimerStateEvent.breakActive
            : TimerStateEvent.running,
        countdownSeconds: _countdownSeconds,
        workElapsedSeconds: _workElapsed.inSeconds,
      ));

      // Auto-save state every 30 seconds or on significant changes
      if (_workElapsed.inSeconds % 30 == 0) {
        saveState();
      }

      _updateTray();
      notifyListeners();
    });
  }

  bool _isWithinWorkingHours() {
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

    if (remaining <= const Duration(seconds: 20)) {
      if (!_isPreBreak) {
        _isPreBreak = true;
        notifyListeners();
      }
    } else {
      if (_isPreBreak) {
        _isPreBreak = false;
        notifyListeners();
      }
    }

    if (_workElapsed >= interval) {
      _isPreBreak = false;
      _triggerBreak();
    }
  }

  void _checkHealthReminders() {
    final settings = _settingsRepository.currentSettings;

    if (settings.postureReminderEnabled && settings.postureReminderIntervalMinutes > 0) {
      if (_postureElapsedSeconds >= settings.postureReminderIntervalMinutes * 60) {
        _postureElapsedSeconds = 0;
        _triggerHealthReminder('posture', settings.postureReminderType);
      }
    }

    if (settings.eyeBlinkReminderEnabled && settings.eyeBlinkReminderIntervalMinutes > 0) {
      if (_eyeBlinkElapsedSeconds >= settings.eyeBlinkReminderIntervalMinutes * 60) {
        _eyeBlinkElapsedSeconds = 0;
        _triggerHealthReminder('eyeblink', settings.eyeBlinkReminderType);
      }
    }
  }

  void _triggerHealthReminder(String reminderType, String displayType) {
    _logger.info('Triggering $reminderType reminder ($displayType)');
    if (displayType == 'native') {
      if (reminderType == 'posture') {
        _notificationService.showPostureReminder();
      } else {
        _notificationService.showEyeRestReminder();
      }
    } else {
      sl<OverlayWindowService>().showOverlay(
        type: OverlayType.quickReminder,
        builder: (_) => const SizedBox.shrink(), // handeled directly in standalone overlay
        reminderType: reminderType,
      );
      
      // Auto dismiss after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (sl<OverlayWindowService>().currentOverlayType == OverlayType.quickReminder) {
          sl<OverlayWindowService>().hideOverlay();
        }
      });
    }
  }

  void _triggerClockOut() {
    _state = TimerState.breakActive;
    _workElapsed = Duration.zero;
    _countdownSeconds = 60;

    _activeBreak = BreakModel(
      type: BreakType.long,
      durationSeconds: _countdownSeconds,
      title: 'CLOCK OUT',
      tip: 'Your workday is over. Time to step away and live your life.',
    );

    _emit(BreakStartedEvent(
      isLongBreak: true,
      durationSeconds: _countdownSeconds,
      title: _activeBreak!.title,
    ));

    _notificationService.showClockOutReminder();
    _logger.info('Clock out triggered');
    notifyListeners();
  }

  void setFocusMode(bool enabled) {
    _emit(FocusModeEvent(isActive: enabled));
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

    _emit(BreakStartedEvent(
      isLongBreak: isLongBreak,
      durationSeconds: _countdownSeconds,
      title: _activeBreak!.title,
    ));

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
      
      MacOSBridge.updateOverlayData({
        'title': 'Well Done!',
        'remainingSeconds': 0,
        'durationSeconds': _activeBreak?.durationSeconds ?? _shortBreakDurationSeconds,
        'strictMode': false,
      });

      await Future.delayed(const Duration(seconds: 2));
      sl<StatsService>().recordCompletedBreak();
      
      if (!sl<OverlayWindowService>().isOverlayVisible) {
        await _notificationService.showBreakFinished();
      }

      // Record actual session duration (time since last break)
      final now = DateTime.now();
      final sessionDuration = _lastBreakFinishedAt != null 
          ? now.difference(_lastBreakFinishedAt!) 
          : _workElapsed;
      
      final sessionMinutes = sessionDuration.inMinutes;
      final activityLevel = sessionMinutes > 45 ? 'high' : sessionMinutes > 20 ? 'medium' : 'low';
      
      _adaptiveBreakService?.recordWorkSession(
        duration: sessionDuration,
        hourOfDay: now.hour,
        activityLevel: activityLevel,
      );
      
      // Update interval for the next work session based on history
      final suggestedInterval = _adaptiveBreakService?.getSuggestedBreakInterval();
      if (suggestedInterval != null && suggestedInterval > 0) {
        _shortBreakIntervalMinutes = suggestedInterval;
        _logger.info('Adaptive: Next break interval set to $suggestedInterval min');
      }
      
      _lastBreakFinishedAt = now;
    }

    _emit(BreakEndedEvent(skipped: skipped));

    _activeBreak = null;
    _isCompletionState = false;
    _state = TimerState.running;
    _isPreBreak = false;
    _lastTickTime = DateTime.now();
    _workElapsed = Duration.zero;
    sl<TrayManagerService>().setBreakActive(false);

    _emit(TimerStateChangedEvent(
      state: TimerStateEvent.running,
      countdownSeconds: 0,
      workElapsedSeconds: 0,
    ));

    notifyListeners();
  }

  bool _isLongBreakDue() {
    final now = DateTime.now();
    _longBreakWindowStartedAt ??= now;
    final elapsedSinceLong = now.difference(_longBreakWindowStartedAt!);
    return elapsedSinceLong >= Duration(minutes: _longBreakIntervalMinutes);
  }

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
        resumeTimers();
      } else if (!isActive && _state == TimerState.running) {
        pauseTimers();
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
      _emit(IdleDetectedEvent(isIdle: !isActive));
    });
    _activityMonitor.start();
  }

  void pauseTimers() {
    if (_state == TimerState.breakActive) return;
    _state = TimerState.paused;
    saveState();
    _emit(TimerStateChangedEvent(
      state: TimerStateEvent.paused,
      countdownSeconds: _countdownSeconds,
      workElapsedSeconds: _workElapsed.inSeconds,
    ));
    notifyListeners();
  }

  void resumeTimers() {
    if (_state == TimerState.breakActive) return;
    _state = TimerState.running;
    _isPreBreak = false;
    _lastTickTime = DateTime.now();
    if (!_isWithinWorkingHours()) {
      _state = TimerState.paused;
    }
    saveState();
    _emit(TimerStateChangedEvent(
      state: _state == TimerState.running
          ? TimerStateEvent.running
          : TimerStateEvent.paused,
      countdownSeconds: _countdownSeconds,
      workElapsedSeconds: _workElapsed.inSeconds,
    ));
    notifyListeners();
  }

  void resetTimers() {
    _workElapsed = Duration.zero;
    _postureElapsedSeconds = 0;
    _eyeBlinkElapsedSeconds = 0;
    _state = TimerState.idle;
    _clockOutTriggered = false;
    _emit(TimerStateChangedEvent(
      state: TimerStateEvent.idle,
      countdownSeconds: 0,
      workElapsedSeconds: 0,
    ));
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
    _emit(BreakPostponedEvent(additionalSeconds: 120));
    notifyListeners();
  }

  void saveState() {
    try {
      _storageService.setString('timer_state', _state.name);
      _storageService.setString('timer_mode', _mode.name);
      _storageService.setInt('timer_work_elapsed', _workElapsed.inSeconds);
      _storageService.setInt('timer_total_work_today', _totalWorkToday.inSeconds);
      _storageService.setInt('timer_countdown', _countdownSeconds);
      _storageService.setInt('timer_short_break_interval', _shortBreakIntervalMinutes);
      _storageService.setInt('timer_short_break_duration', _shortBreakDurationSeconds);
      _storageService.setInt('timer_long_break_interval', _longBreakIntervalMinutes);
      _storageService.setInt('timer_long_break_duration', _longBreakDurationMinutes);
      _storageService.setInt('timer_pause_after', _pauseTimerAfterMinutes);
      _storageService.setInt('timer_reset_after', _resetTimerAfterMinutes);
      _storageService.setBool('timer_is_completion', _isCompletionState);

      _storageService.setBool('timer_is_pre_break', _isPreBreak);
      _storageService.setBool('timer_clock_out_triggered', _clockOutTriggered);
      _storageService.setInt('timer_posture_elapsed', _postureElapsedSeconds);
      _storageService.setInt('timer_eye_blink_elapsed', _eyeBlinkElapsedSeconds);
      if (_longBreakWindowStartedAt != null) {
        _storageService.setInt('timer_long_break_window', _longBreakWindowStartedAt!.millisecondsSinceEpoch);
      }
      if (_lastBreakFinishedAt != null) {
        _storageService.setInt('timer_last_break_finished', _lastBreakFinishedAt!.millisecondsSinceEpoch);
      }
      _logger.info('Timer state saved');
    } catch (e) {
      _logger.error('Failed to save timer state: $e');
    }
  }

  void restoreState() {
    try {
      final stateStr = _storageService.getString('timer_state', defaultValue: 'idle');
      _state = TimerState.values.firstWhere((s) => s.name == stateStr, orElse: () => TimerState.idle);

      // Prevent break screen from showing immediately on application launch
      if (_state == TimerState.breakActive) {
        _state = TimerState.running;
        _workElapsed = Duration.zero;
        _countdownSeconds = 0;
      }

      final modeStr = _storageService.getString('timer_mode', defaultValue: 'flexible');
      _mode = WorkMode.values.firstWhere((m) => m.name == modeStr, orElse: () => WorkMode.flexible);

      _workElapsed = Duration(seconds: _storageService.getInt('timer_work_elapsed'));
      _totalWorkToday = Duration(seconds: _storageService.getInt('timer_total_work_today'));
      _countdownSeconds = _storageService.getInt('timer_countdown');
      _shortBreakIntervalMinutes = _storageService.getInt('timer_short_break_interval', defaultValue: _shortBreakIntervalMinutes);
      _shortBreakDurationSeconds = _storageService.getInt('timer_short_break_duration', defaultValue: _shortBreakDurationSeconds);
      _longBreakIntervalMinutes = _storageService.getInt('timer_long_break_interval', defaultValue: _longBreakIntervalMinutes);
      _longBreakDurationMinutes = _storageService.getInt('timer_long_break_duration', defaultValue: _longBreakDurationMinutes);
      _pauseTimerAfterMinutes = _storageService.getInt('timer_pause_after', defaultValue: _pauseTimerAfterMinutes);
      _resetTimerAfterMinutes = _storageService.getInt('timer_reset_after', defaultValue: _resetTimerAfterMinutes);
      _isCompletionState = _storageService.getBool('timer_is_completion');

      // Prevent pre-break warnings from showing immediately on application launch
      _isPreBreak = false;
      _clockOutTriggered = _storageService.getBool('timer_clock_out_triggered');
      _postureElapsedSeconds = _storageService.getInt('timer_posture_elapsed', defaultValue: 0);
      _eyeBlinkElapsedSeconds = _storageService.getInt('timer_eye_blink_elapsed', defaultValue: 0);

      final longBreakWindowMs = _storageService.getInt('timer_long_break_window', defaultValue: 0);
      if (longBreakWindowMs > 0) {
        _longBreakWindowStartedAt = DateTime.fromMillisecondsSinceEpoch(longBreakWindowMs);
      }
      
      final lastBreakMs = _storageService.getInt('timer_last_break_finished', defaultValue: 0);
      if (lastBreakMs > 0) {
        _lastBreakFinishedAt = DateTime.fromMillisecondsSinceEpoch(lastBreakMs);
      }

      _logger.info('Timer state restored: $_state, elapsed=${_workElapsed.inSeconds}s');
    } catch (e) {
      _logger.error('Failed to restore timer state: $e');
    }
  }

  void _startUsageTracking() {
    _usageTrackerTimer?.cancel();
    _usageTrackerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_state == TimerState.running) {
        sl<StatsService>().addUsageMinutes(1);
      }
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
