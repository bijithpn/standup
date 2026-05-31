import 'dart:async';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';

export 'package:breakmate/features/break_system/domain/break_model.dart'
    show BreakType;
export 'package:breakmate/core/services/timer_state.dart'
    show TimerState, WorkMode;

class TimerEngine extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final SmartDetectionService? _smartDetectionService;
  final EventBus _eventBus;
  final AppLogger _logger = AppLogger();

  final TimerStateData _stateData = TimerStateData();
  late final TimerContextManager _contextManager;

  Timer? _tickTimer;

  int _shortBreakIntervalMinutes =
      AppConstants.defaultShortBreakIntervalMinutes;
  int _shortBreakDurationSeconds =
      AppConstants.defaultShortBreakDurationSeconds;
  int _preBreakWarningSeconds = AppConstants.defaultPreBreakWarningSeconds;
  int _longBreakIntervalMinutes = AppConstants.defaultLongBreakIntervalMinutes;
  int _longBreakDurationMinutes = AppConstants.defaultLongBreakDurationMinutes;
  int _pauseTimerAfterMinutes = 5;
  int _resetTimerAfterMinutes = 15;

  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Duration> workElapsedNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> totalWorkTodayNotifier =
      ValueNotifier<Duration>(Duration.zero);

  TimerEngine({
    required SettingsRepository settingsRepository,
    SmartDetectionService? smartDetectionService,
    CalendarService? calendarService,
    EventBus? eventBus,
  }) : _settingsRepository = settingsRepository,
       _smartDetectionService = smartDetectionService,
       _eventBus = eventBus ?? EventBus.instance {
    _contextManager = TimerContextManager(
      settingsRepository: _settingsRepository,
      smartDetectionService: _smartDetectionService,
      calendarService: calendarService,
    );
    _syncSettingsFromRepo();
    
    // Initialize notifiers
    countdownNotifier.value = _stateData.countdownSeconds;
    workElapsedNotifier.value = _stateData.workElapsed;
    totalWorkTodayNotifier.value = _stateData.totalWorkToday;
  }

  void _emit(AppEvent event) {
    _eventBus.emit(event);
  }

  void _syncSettingsFromRepo() {
    final s = _settingsRepository.currentSettings;
    _shortBreakIntervalMinutes = s.shortBreakIntervalMinutes;
    _shortBreakDurationSeconds = s.shortBreakDurationSeconds;
    _preBreakWarningSeconds = s.preBreakWarningSeconds;
    _longBreakIntervalMinutes = s.longBreakIntervalMinutes;
    _longBreakDurationMinutes = s.longBreakDurationMinutes;
    _pauseTimerAfterMinutes = s.pauseTimerAfterMinutes;
    _resetTimerAfterMinutes = s.resetTimerAfterMinutes;
  }

  // Exposed getters and setters for the coordinator/orchestrator
  TimerStateData get stateData => _stateData;
  TimerContextManager get contextManager => _contextManager;

  int get shortBreakIntervalMinutes => _shortBreakIntervalMinutes;
  set shortBreakIntervalMinutes(int val) {
    _shortBreakIntervalMinutes = val;
    notifyListeners();
  }

  int get shortBreakDurationSeconds => _shortBreakDurationSeconds;
  set shortBreakDurationSeconds(int val) {
    _shortBreakDurationSeconds = val;
    notifyListeners();
  }

  int get preBreakWarningSeconds => _preBreakWarningSeconds;
  set preBreakWarningSeconds(int val) {
    _preBreakWarningSeconds = val;
    notifyListeners();
  }

  int get longBreakIntervalMinutes => _longBreakIntervalMinutes;
  set longBreakIntervalMinutes(int val) {
    _longBreakIntervalMinutes = val;
    notifyListeners();
  }

  int get longBreakDurationMinutes => _longBreakDurationMinutes;
  set longBreakDurationMinutes(int val) {
    _longBreakDurationMinutes = val;
    notifyListeners();
  }

  int get pauseTimerAfterMinutes => _pauseTimerAfterMinutes;
  set pauseTimerAfterMinutes(int val) {
    _pauseTimerAfterMinutes = val;
    notifyListeners();
  }

  int get resetTimerAfterMinutes => _resetTimerAfterMinutes;
  set resetTimerAfterMinutes(int val) {
    _resetTimerAfterMinutes = val;
    notifyListeners();
  }

  // Delegate getters/setters to _stateData and _contextManager
  TimerState get state => _stateData.state;
  WorkMode get mode => _stateData.mode;
  BreakModel? get activeBreak => _stateData.activeBreak;
  int get countdownSeconds {
    if (state == TimerState.running) {
      return timeUntilNextShortBreak.inSeconds;
    }
    return _stateData.countdownSeconds;
  }
  bool get isCompletionState => _stateData.isCompletionState;
  bool get isPreBreak => _stateData.isPreBreak;
  Duration get totalWorkToday => _stateData.totalWorkToday;
  Duration get workElapsed => _stateData.workElapsed;

  DateTime? get targetEndTime {
    if (state == TimerState.breakActive) {
      return _stateData.breakEndTime;
    } else if (state == TimerState.running) {
      return _stateData.workEndTime;
    }
    return null;
  }

  Duration get timeUntilNextShortBreak {
    final interval = Duration(minutes: _shortBreakIntervalMinutes);
    final remaining = interval - _stateData.workElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canPostpone => true;

  void setWorkMode(WorkMode mode) {
    _stateData.mode = mode;
    notifyListeners();
  }

  void startTimers() {
    _syncSettingsFromRepo();

    // If it was already running or break active, keep it that way
    if (state == TimerState.idle) {
      _stateData.state = TimerState.running;
      _stateData.isPreBreak = false;
      _stateData.workElapsed = Duration.zero;
      _stateData.clockOutTriggered = false;
    } else if (state == TimerState.breakActive && activeBreak == null) {
      _stateData.activeBreak = BreakModel(
        type: BreakType.short,
        durationSeconds: countdownSeconds > 0
            ? countdownSeconds
            : _shortBreakDurationSeconds,
        title: 'Break Resumed',
        tip: 'Take a breather.',
      );
    }

    _stateData.lastTickTime = DateTime.now();

    if (state == TimerState.breakActive) {
      _stateData.breakEndTime = DateTime.now().add(
        Duration(seconds: countdownSeconds),
      );
      _stateData.workEndTime = null;
    } else if (state == TimerState.running) {
      _stateData.workEndTime = DateTime.now().add(timeUntilNextShortBreak);
      _stateData.breakEndTime = null;
    } else {
      _stateData.breakEndTime = null;
      _stateData.workEndTime = null;
    }

    _startTicking();

    _emit(
      TimerStateChangedEvent(
        state: state == TimerState.breakActive
            ? TimerStateEvent.breakActive
            : TimerStateEvent.running,
        countdownSeconds: countdownSeconds,
        workElapsedSeconds: _stateData.workElapsed.inSeconds,
        targetEndTime: targetEndTime,
      ),
    );

    _logger.info('Timers started (State: $state) in $mode mode');
    notifyListeners();
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();

      if (_stateData.systemSleepPaused) {
        _stateData.lastTickTime = now;
        return;
      }

      if (state == TimerState.paused || state == TimerState.idle) {
        // notifyListeners(); // REMOVED: redundant as state is stable
        return;
      }

      final delta = now.difference(_stateData.lastTickTime ?? now);
      _stateData.lastTickTime = now;

      bool significantChange = false;

      if (state == TimerState.running) {
        if (_checkClockOut(now)) return;
        if (_contextManager.shouldRunWorkTimer()) {
          _stateData.manualOverride = false;
        } else {
          if (!_stateData.manualOverride) {
            pauseTimers(isManual: false);
            return;
          }
        }
        _stateData.workElapsed += delta;
        _stateData.totalWorkToday += delta;
        _stateData.postureElapsedSeconds += delta.inSeconds;
        _stateData.eyeBlinkElapsedSeconds += delta.inSeconds;
        
        final wasPreBreak = isPreBreak;
        _checkBreakConditions();
        if (wasPreBreak != isPreBreak) significantChange = true;
        
        _checkHealthReminders();
        
        workElapsedNotifier.value = _stateData.workElapsed;
        totalWorkTodayNotifier.value = _stateData.totalWorkToday;
        countdownNotifier.value = timeUntilNextShortBreak.inSeconds;
      } else if (state == TimerState.breakActive) {
        _stateData.countdownSeconds--;
        countdownNotifier.value = _stateData.countdownSeconds;
        
        if (countdownSeconds <= 0) {
          finishBreak(skipped: false);
          return;
        }
      }

      // Update target times if they changed
      final prevWorkEndTime = _stateData.workEndTime;
      final prevBreakEndTime = _stateData.breakEndTime;

      if (state == TimerState.breakActive) {
        _stateData.breakEndTime ??= DateTime.now().add(
          Duration(seconds: countdownSeconds),
        );
        _stateData.workEndTime = null;
      } else if (state == TimerState.running) {
        _stateData.workEndTime ??= DateTime.now().add(timeUntilNextShortBreak);
        _stateData.breakEndTime = null;
      }

      if (_stateData.workEndTime != prevWorkEndTime || 
          _stateData.breakEndTime != prevBreakEndTime) {
        significantChange = true;
      }

      if (significantChange) {
        _emit(
          TimerStateChangedEvent(
            state: state == TimerState.breakActive
                ? TimerStateEvent.breakActive
                : TimerStateEvent.running,
            countdownSeconds: countdownSeconds,
            workElapsedSeconds: _stateData.workElapsed.inSeconds,
            targetEndTime: targetEndTime,
          ),
        );
        notifyListeners();
      }
    });
  }


  bool _checkClockOut(DateTime now) {
    if (_contextManager.checkClockOut(now, _stateData.clockOutTriggered)) {
      _stateData.clockOutTriggered = true;
      _triggerClockOut();
      return true;
    }
    return false;
  }

  void _checkBreakConditions() {
    final settings = _settingsRepository.currentSettings;
    if (settings.quietModeEnabled) {
      if (settings.quietModePreset == 'presenting' ||
          settings.quietModePreset == 'deep_work') {
        _logger.info(
          'Break suppressed by quiet mode preset: ${settings.quietModePreset}',
        );
        return;
      }
    }

    final interval = Duration(minutes: _shortBreakIntervalMinutes);
    final remaining = interval - _stateData.workElapsed;

    final warningWindow = Duration(
      seconds: _preBreakWarningSeconds.clamp(0, 300).toInt(),
    );
    if (warningWindow > Duration.zero && remaining <= warningWindow) {
      if (!isPreBreak) {
        _stateData.isPreBreak = true;
        notifyListeners();
      }
    } else {
      if (isPreBreak) {
        _stateData.isPreBreak = false;
        notifyListeners();
      }
    }

    if (_stateData.workElapsed >= interval) {
      _stateData.isPreBreak = false;
      
      // Calendar awareness
      _contextManager.isMeetingUpcoming().then((isMeeting) {
        if (isMeeting) {
          _logger.info('Delaying break due to imminent meeting');
          _stateData.workElapsed = interval - const Duration(minutes: 5);
          notifyListeners();
        } else {
          _triggerBreak();
        }
      });
    }
  }

  void _checkHealthReminders() {
    final settings = _settingsRepository.currentSettings;
    if (settings.quietModeEnabled) {
      if (settings.quietModePreset == 'presenting' ||
          settings.quietModePreset == 'deep_work') {
        return;
      }
    }

    int postureInterval = settings.postureReminderIntervalMinutes;
    int eyeblinkInterval = settings.eyeBlinkReminderIntervalMinutes;

    if (settings.quietModeEnabled &&
        settings.quietModePreset == 'low_battery') {
      postureInterval *= 2;
      eyeblinkInterval *= 2;
    }

    if (settings.postureReminderEnabled && postureInterval > 0) {
      if (_stateData.postureElapsedSeconds >= postureInterval * 60) {
        _stateData.postureElapsedSeconds = 0;
        _triggerHealthReminder('posture', settings.postureReminderType);
      }
    }

    if (settings.eyeBlinkReminderEnabled && eyeblinkInterval > 0) {
      if (_stateData.eyeBlinkElapsedSeconds >= eyeblinkInterval * 60) {
        _stateData.eyeBlinkElapsedSeconds = 0;
        _triggerHealthReminder('eyeblink', settings.eyeBlinkReminderType);
      }
    }
  }

  void _triggerHealthReminder(String reminderType, String displayType) {
    _logger.info('Triggering $reminderType reminder ($displayType)');
    _emit(
      HealthReminderEvent(
        reminderType: reminderType,
        displayType: displayType,
      ),
    );
  }

  void _triggerClockOut() {
    _stateData.state = TimerState.windDown;
    _stateData.workElapsed = Duration.zero;
    _stateData.countdownSeconds = 300; // 5 minutes wind down
    _stateData.breakEndTime = DateTime.now().add(
      Duration(seconds: countdownSeconds),
    );
    _stateData.workEndTime = null;

    _stateData.activeBreak = BreakModel(
      type: BreakType.windDown,
      durationSeconds: countdownSeconds,
      title: 'Workday Wrap-up',
      tip:
          'Great job today! Let\'s wind down and review your highlights before you head out.',
      triggerReason: 'Clock-out time reached',
    );

    _emit(
      BreakStartedEvent(
        isLongBreak: true,
        durationSeconds: countdownSeconds,
        title: activeBreak!.title,
      ),
    );

    _logger.info('Wind-down triggered');
    notifyListeners();
  }

  void setFocusMode(bool enabled) {
    _emit(FocusModeEvent(isActive: enabled));
    notifyListeners();
  }

  void _triggerBreak() {
    _stateData.state = TimerState.breakActive;
    _stateData.workElapsed = Duration.zero;

    final isLongBreak = isLongBreakDue();

    if (isLongBreak) {
      _stateData.countdownSeconds = _longBreakDurationMinutes * 60;
      _stateData.activeBreak = BreakModel(
        type: BreakType.long,
        durationSeconds: countdownSeconds,
        title: 'LONG BREAK',
        tip:
            'Time to stand, stretch, and mentally reset. Step away from your desk.',
        triggerReason: 'Long focus session completed',
      );
      _stateData.longBreakWindowStartedAt = DateTime.now();
    } else {
      _stateData.countdownSeconds = _shortBreakDurationSeconds;
      _stateData.activeBreak = BreakModel(
        type: BreakType.short,
        durationSeconds: countdownSeconds,
        title: 'Eye Rest',
        tip: _randomTip(AppConstants.shortBreakTips),
        triggerReason: '20-minute interval reached',
      );
    }

    _stateData.breakEndTime = DateTime.now().add(
      Duration(seconds: countdownSeconds),
    );
    _stateData.workEndTime = null;

    _emit(
      BreakStartedEvent(
        isLongBreak: isLongBreak,
        durationSeconds: countdownSeconds,
        title: activeBreak!.title,
      ),
    );

    _logger.info('Break triggered: ${activeBreak!.title}');
    notifyListeners();
  }

  Future<void> finishBreak({required bool skipped}) async {
    if (state != TimerState.breakActive) return;

    if (!skipped) {
      _stateData.isCompletionState = true;
      notifyListeners();

      NativeBridge.updateOverlayData({
        'title': 'Well Done!',
        'remainingSeconds': 0,
        'durationSeconds':
            activeBreak?.durationSeconds ?? _shortBreakDurationSeconds,
        'strictMode': false,
      });
    }

    _emit(BreakEndedEvent(skipped: skipped));

    _stateData.activeBreak = null;
    _stateData.isCompletionState = false;
    _stateData.state = TimerState.running;
    _stateData.isPreBreak = false;
    _stateData.lastTickTime = DateTime.now();
    _stateData.workElapsed = Duration.zero;
    _stateData.breakEndTime = null;
    _stateData.workEndTime = DateTime.now().add(timeUntilNextShortBreak);

    _emit(
      TimerStateChangedEvent(
        state: TimerStateEvent.running,
        countdownSeconds: 0,
        workElapsedSeconds: 0,
        targetEndTime: targetEndTime,
      ),
    );

    notifyListeners();
  }

  void updateMenuStyle(String style) {
    try {
      final tray = sl<TrayManagerService>();
      tray.setIconModeFromStyle(style);
    } catch (_) {
      // Guard in case sl<TrayManagerService> is not registered in tests
    }
    notifyListeners();
  }

  bool isLongBreakDue() {
    final now = DateTime.now();
    _stateData.longBreakWindowStartedAt ??= now;
    final elapsedSinceLong = now.difference(
      _stateData.longBreakWindowStartedAt!,
    );
    return elapsedSinceLong >= Duration(minutes: _longBreakIntervalMinutes);
  }

  void updateSettings({
    int? shortIntervalMinutes,
    int? shortDurationSeconds,
    int? preBreakWarningSeconds,
    int? longIntervalMinutes,
    int? longDurationSeconds,
    int? pauseAfterMinutes,
    int? resetAfterMinutes,
  }) {
    if (shortIntervalMinutes != null) {
      _shortBreakIntervalMinutes = shortIntervalMinutes;
    }
    if (shortDurationSeconds != null) {
      _shortBreakDurationSeconds = shortDurationSeconds;
    }
    if (preBreakWarningSeconds != null) {
      _preBreakWarningSeconds = preBreakWarningSeconds;
    }
    if (longIntervalMinutes != null) {
      _longBreakIntervalMinutes = longIntervalMinutes;
    }
    if (longDurationSeconds != null) {
      _longBreakDurationMinutes = (longDurationSeconds / 60).ceil();
    }
    if (pauseAfterMinutes != null) _pauseTimerAfterMinutes = pauseAfterMinutes;
    if (resetAfterMinutes != null) _resetTimerAfterMinutes = resetAfterMinutes;

    _logger.info(
      'Settings updated at runtime in TimerEngine: interval=$_shortBreakIntervalMinutes min, '
      'duration=$_shortBreakDurationSeconds s',
    );
    notifyListeners();
  }

  void pauseTimers({bool isManual = false}) {
    if (state == TimerState.breakActive) return;
    _stateData.state = TimerState.paused;
    if (isManual) {
      _stateData.isManuallyPaused = true;
    }
    _stateData.manualOverride = false;
    _stateData.breakEndTime = null;
    _stateData.workEndTime = null;
    _emit(
      TimerStateChangedEvent(
        state: TimerStateEvent.paused,
        countdownSeconds: countdownSeconds,
        workElapsedSeconds: _stateData.workElapsed.inSeconds,
        targetEndTime: targetEndTime,
      ),
    );
    notifyListeners();
  }

  void resumeTimers() {
    if (state == TimerState.breakActive) return;
    _stateData.state = TimerState.running;
    _stateData.isManuallyPaused = false;
    _stateData.manualOverride = true;
    _stateData.isPreBreak = false;
    _stateData.lastTickTime = DateTime.now();
    _stateData.breakEndTime = null;
    _stateData.workEndTime = DateTime.now().add(timeUntilNextShortBreak);
    _emit(
      TimerStateChangedEvent(
        state: state == TimerState.running
            ? TimerStateEvent.running
            : TimerStateEvent.paused,
        countdownSeconds: countdownSeconds,
        workElapsedSeconds: _stateData.workElapsed.inSeconds,
        targetEndTime: targetEndTime,
      ),
    );
    notifyListeners();
  }

  void resetTimers() {
    _stateData.workElapsed = Duration.zero;
    _stateData.postureElapsedSeconds = 0;
    _stateData.eyeBlinkElapsedSeconds = 0;
    _stateData.state = TimerState.idle;
    _stateData.isManuallyPaused = false;
    _stateData.manualOverride = false;
    _stateData.clockOutTriggered = false;
    _stateData.breakEndTime = null;
    _stateData.workEndTime = null;
    _emit(
      TimerStateChangedEvent(
        state: TimerStateEvent.idle,
        countdownSeconds: 0,
        workElapsedSeconds: 0,
        targetEndTime: targetEndTime,
      ),
    );
    notifyListeners();
  }

  void triggerBreakNow({bool isLong = false}) {
    if (isLong) {
      _stateData.longBreakWindowStartedAt = DateTime.now().subtract(
        Duration(minutes: _longBreakIntervalMinutes),
      );
    }
    _triggerBreak();
  }

  void skipNextBreak() {
    _stateData.workElapsed = Duration.zero;
    _emit(BreakEndedEvent(skipped: true));
    notifyListeners();
  }

  void postponeBreak() {
    _stateData.countdownSeconds += 120;
    _stateData.breakEndTime =
        _stateData.breakEndTime?.add(const Duration(seconds: 120)) ??
        DateTime.now().add(Duration(seconds: countdownSeconds));
    _emit(BreakPostponedEvent(additionalSeconds: 120));
    _emit(
      TimerStateChangedEvent(
        state: TimerStateEvent.breakActive,
        countdownSeconds: countdownSeconds,
        workElapsedSeconds: _stateData.workElapsed.inSeconds,
        targetEndTime: targetEndTime,
      ),
    );
    notifyListeners();
  }

  void handleSystemSleep() {
    _logger.info(
      'System sleep or screen lock detected: pausing break/work timers',
    );
    _stateData.systemSleepPaused = true;
    _stateData.lastTickTime = DateTime.now();
    notifyListeners();
  }

  void handleSystemWake() {
    _logger.info(
      'System wake or screen unlock detected: checking recovery flow',
    );
    _stateData.systemSleepPaused = false;

    final lastTick = _stateData.lastTickTime ?? DateTime.now();
    final durationAway = DateTime.now().difference(lastTick);

    if (durationAway.inMinutes >= _shortBreakIntervalMinutes) {
      _logger.info(
        'Away for ${durationAway.inMinutes}m. Resetting focus session.',
      );
      resetTimers();
    } else {
      _stateData.lastTickTime = DateTime.now();
      resumeTimers();
    }

    notifyListeners();
  }

  String _randomTip(List<String> tips) {
    final copy = List<String>.from(tips)..shuffle();
    return copy.first;
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
