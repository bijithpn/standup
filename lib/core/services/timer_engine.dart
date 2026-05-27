import 'dart:async';
import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/native/macos_bridge.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/core/services/timer_repository.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';

export 'package:breakmate/features/break_system/domain/break_model.dart' show BreakType;
export 'package:breakmate/core/services/timer_state.dart' show TimerState, WorkMode;

class TimerEngine extends ChangeNotifier {
  final ActivityMonitor _activityMonitor;
  final NotificationService _notificationService;
  final SettingsRepository _settingsRepository;
  final StorageService _storageService;
  final AdaptiveBreakService? _adaptiveBreakService;
  final SmartDetectionService? _smartDetectionService;
  final EventBus _eventBus;
  final AppLogger _logger = AppLogger();

  final TimerStateData _stateData = TimerStateData();
  late final TimerRepository _timerRepository;
  late final TimerContextManager _contextManager;

  Timer? _tickTimer;
  Timer? _usageTrackerTimer;
  Timer? _pauseAutoResumeTimer;

  int _shortBreakIntervalMinutes = AppConstants.defaultShortBreakIntervalMinutes;
  int _shortBreakDurationSeconds = AppConstants.defaultShortBreakDurationSeconds;
  int _preBreakWarningSeconds = AppConstants.defaultPreBreakWarningSeconds;
  int _longBreakIntervalMinutes = AppConstants.defaultLongBreakIntervalMinutes;
  int _longBreakDurationMinutes = AppConstants.defaultLongBreakDurationMinutes;
  int _pauseTimerAfterMinutes = 5;
  int _resetTimerAfterMinutes = 15;

  TimerState? _lastIpcState;
  DateTime? _lastIpcTargetEndTime;

  TimerEngine({
    required ActivityMonitor activityMonitor,
    required NotificationService notificationService,
    required SettingsRepository settingsRepository,
    required StorageService storageService,
    AdaptiveBreakService? adaptiveBreakService,
    SmartDetectionService? smartDetectionService,
    EventBus? eventBus,
  }) : _activityMonitor = activityMonitor,
       _notificationService = notificationService,
       _settingsRepository = settingsRepository,
       _storageService = storageService,
       _adaptiveBreakService = adaptiveBreakService,
       _smartDetectionService = smartDetectionService,
       _eventBus = eventBus ?? EventBus.instance {
    _timerRepository = TimerRepository(_storageService);
    _contextManager = TimerContextManager(
      settingsRepository: _settingsRepository,
      smartDetectionService: _smartDetectionService,
    );
    _syncSettingsFromRepo();
  }

  void _emit(AppEvent event) {
    _eventBus.emit(event);

    // Synchronize state across isolates via IPC Bridge
    if (event is TimerStateChangedEvent) {
      final targetEndTime = event.targetEndTime;
      final stateChanged = _lastIpcState != state;
      final targetEndTimeChanged = _lastIpcTargetEndTime == null && targetEndTime != null ||
          _lastIpcTargetEndTime != null && targetEndTime == null ||
          (_lastIpcTargetEndTime != null && targetEndTime != null &&
              (_lastIpcTargetEndTime!.difference(targetEndTime).abs().inSeconds > 1));

      if (stateChanged || targetEndTimeChanged) {
        _lastIpcState = state;
        _lastIpcTargetEndTime = targetEndTime;

        IpcBridge.instance.notifyTimerStateChanged(
          event.state.name,
          countdownSeconds: event.countdownSeconds,
          workElapsedSeconds: event.workElapsedSeconds,
          targetEndTime: targetEndTime?.millisecondsSinceEpoch,
          totalWorkTodaySeconds: _stateData.totalWorkToday.inSeconds,
        );
      }
    } else if (event is BreakStartedEvent) {
      IpcBridge.instance.sendEvent('timer.breakStarted', {
        'isLongBreak': event.isLongBreak,
        'durationSeconds': event.durationSeconds,
        'title': event.title,
      });
    } else if (event is BreakEndedEvent) {
      IpcBridge.instance.sendEvent('timer.breakEnded', {
        'skipped': event.skipped,
      });
    }
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

  // Delegate getters/setters to _stateData and _contextManager
  TimerState get state => _stateData.state;
  WorkMode get mode => _stateData.mode;
  BreakModel? get activeBreak => _stateData.activeBreak;
  int get countdownSeconds => _stateData.countdownSeconds;
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

    // Attempt to restore state first
    restoreState();

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
      _stateData.breakEndTime = DateTime.now().add(Duration(seconds: countdownSeconds));
      _stateData.workEndTime = null;
    } else if (state == TimerState.running) {
      _stateData.workEndTime = DateTime.now().add(timeUntilNextShortBreak);
      _stateData.breakEndTime = null;
    } else {
      _stateData.breakEndTime = null;
      _stateData.workEndTime = null;
    }

    _startTicking();
    _setupActivityMonitor();
    _startUsageTracking();

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

      // Auto-resume if conditions met and not manually paused
      if (state == TimerState.paused &&
          !_stateData.isManuallyPaused &&
          _contextManager.shouldRunWorkTimer()) {
        _logger.info('Auto-resuming timer: conditions met');
        resumeTimers();
      }

      if (state == TimerState.paused || state == TimerState.idle) {
        _updateTray();
        notifyListeners();
        return;
      }

      final delta = now.difference(_stateData.lastTickTime ?? now);
      _stateData.lastTickTime = now;

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
        _checkBreakConditions();
        _checkHealthReminders();
      } else if (state == TimerState.breakActive) {
        _stateData.countdownSeconds--;
        if (countdownSeconds <= 0) {
          finishBreak(skipped: false);
          return;
        }
      }

      if (state == TimerState.breakActive) {
        _stateData.breakEndTime ??= DateTime.now().add(Duration(seconds: countdownSeconds));
        _stateData.workEndTime = null;
      } else if (state == TimerState.running) {
        _stateData.workEndTime ??= DateTime.now().add(timeUntilNextShortBreak);
        _stateData.breakEndTime = null;
      }

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

      // Auto-save state every 30 seconds or on significant changes
      if (_stateData.workElapsed.inSeconds % 30 == 0) {
        saveState();
      }

      _updateTray();
      notifyListeners();
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
      _triggerBreak();
    }
  }

  void _checkHealthReminders() {
    final settings = _settingsRepository.currentSettings;

    if (settings.postureReminderEnabled &&
        settings.postureReminderIntervalMinutes > 0) {
      if (_stateData.postureElapsedSeconds >=
          settings.postureReminderIntervalMinutes * 60) {
        _stateData.postureElapsedSeconds = 0;
        _triggerHealthReminder('posture', settings.postureReminderType);
      }
    }

    if (settings.eyeBlinkReminderEnabled &&
        settings.eyeBlinkReminderIntervalMinutes > 0) {
      if (_stateData.eyeBlinkElapsedSeconds >=
          settings.eyeBlinkReminderIntervalMinutes * 60) {
        _stateData.eyeBlinkElapsedSeconds = 0;
        _triggerHealthReminder('eyeblink', settings.eyeBlinkReminderType);
      }
    }
  }

  void _triggerHealthReminder(String reminderType, String displayType) {
    _logger.info('Triggering $reminderType reminder ($displayType)');

    final settings = _settingsRepository.currentSettings;
    if (settings.companionEnabled) {
      // Phase 3.4: Map micro-breaks to Companion animations instead of OS popups
      final interactionType = reminderType == 'posture' ? 'stretch' : 'blink';
      _eventBus.emit(CompanionInteractionEvent(interactionType: interactionType));
      
      // Also notify other isolates via IPC
      IpcBridge.instance.sendEvent('companion.interaction', {
        'interactionType': interactionType,
      });
      
      return;
    }

    if (displayType == 'native') {
      if (reminderType == 'posture') {
        _notificationService.showPostureReminder();
      } else {
        _notificationService.showEyeRestReminder();
      }
    } else {
      sl<OverlayWindowService>().showOverlay(
        type: OverlayType.quickReminder,
        builder: (_) => const SizedBox.shrink(),
        reminderType: reminderType,
      );

      // Auto dismiss after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (sl<OverlayWindowService>().currentOverlayType ==
            OverlayType.quickReminder) {
          sl<OverlayWindowService>().hideOverlay();
        }
      });
    }
  }

  void _triggerClockOut() {
    _stateData.state = TimerState.breakActive;
    _stateData.workElapsed = Duration.zero;
    _stateData.countdownSeconds = 60;
    _stateData.breakEndTime = DateTime.now().add(Duration(seconds: countdownSeconds));
    _stateData.workEndTime = null;

    _stateData.activeBreak = BreakModel(
      type: BreakType.long,
      durationSeconds: countdownSeconds,
      title: 'CLOCK OUT',
      tip: 'Your workday is over. Time to step away and live your life.',
    );

    _emit(
      BreakStartedEvent(
        isLongBreak: true,
        durationSeconds: countdownSeconds,
        title: activeBreak!.title,
      ),
    );

    _notificationService.showClockOutReminder();
    _logger.info('Clock out triggered');
    notifyListeners();
  }

  void setFocusMode(bool enabled) {
    _emit(FocusModeEvent(isActive: enabled));
    notifyListeners();
  }

  void _triggerBreak() {
    _stateData.state = TimerState.breakActive;
    _stateData.workElapsed = Duration.zero;

    final isLongBreak = _isLongBreakDue();

    if (isLongBreak) {
      _stateData.countdownSeconds = _longBreakDurationMinutes * 60;
      _stateData.activeBreak = BreakModel(
        type: BreakType.long,
        durationSeconds: countdownSeconds,
        title: 'LONG BREAK',
        tip: 'Time to stand, stretch, and mentally reset. Step away from your desk.',
      );
      _stateData.longBreakWindowStartedAt = DateTime.now();
    } else {
      final suggestedDuration =
          _adaptiveBreakService?.getSuggestedBreakDuration() ??
          _shortBreakDurationSeconds;
      _stateData.countdownSeconds = suggestedDuration;
      _stateData.activeBreak = BreakModel(
        type: BreakType.short,
        durationSeconds: countdownSeconds,
        title: 'Eye Rest',
        tip: _randomTip(AppConstants.shortBreakTips),
      );
    }

    _stateData.breakEndTime = DateTime.now().add(Duration(seconds: countdownSeconds));
    _stateData.workEndTime = null;

    _emit(
      BreakStartedEvent(
        isLongBreak: isLongBreak,
        durationSeconds: countdownSeconds,
        title: activeBreak!.title,
      ),
    );

    sl<TrayManagerService>().setBreakActive(true);

    _logger.info('Break triggered: ${activeBreak!.title}');
    notifyListeners();
  }

  Future<void> finishBreak({required bool skipped}) async {
    if (state != TimerState.breakActive) return;

    if (skipped) {
      sl<StatsService>().recordSkippedBreak();
    } else {
      _stateData.isCompletionState = true;
      notifyListeners();

      MacOSBridge.updateOverlayData({
        'title': 'Well Done!',
        'remainingSeconds': 0,
        'durationSeconds':
            activeBreak?.durationSeconds ?? _shortBreakDurationSeconds,
        'strictMode': false,
      });

      await Future.delayed(const Duration(seconds: 2));
      sl<StatsService>().recordCompletedBreak();

      if (!sl<OverlayWindowService>().isOverlayVisible) {
        await _notificationService.showBreakFinished();
      }

      // Record actual session duration (time since last break)
      final now = DateTime.now();
      final sessionDuration = _stateData.lastBreakFinishedAt != null
          ? now.difference(_stateData.lastBreakFinishedAt!)
          : _stateData.workElapsed;

      final sessionMinutes = sessionDuration.inMinutes;
      final activityLevel = sessionMinutes > 45
          ? 'high'
          : sessionMinutes > 20
          ? 'medium'
          : 'low';

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

      _stateData.lastBreakFinishedAt = now;
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
    sl<TrayManagerService>().setBreakActive(false);

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

  bool _isLongBreakDue() {
    final now = DateTime.now();
    _stateData.longBreakWindowStartedAt ??= now;
    final elapsedSinceLong = now.difference(_stateData.longBreakWindowStartedAt!);
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

    _activityMonitor.setIdleThreshold(_pauseTimerAfterMinutes);
    _notificationService.setNotificationsEnabled(
      _settingsRepository.currentSettings.notificationsEnabled,
    );
    _notificationService.setSoundEnabled(
      _settingsRepository.currentSettings.soundEnabled,
    );

    _logger.info(
      'Settings updated at runtime: interval=$_shortBreakIntervalMinutes min, '
      'duration=$_shortBreakDurationSeconds s',
    );
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

    final remaining = state == TimerState.breakActive
        ? Duration(seconds: countdownSeconds)
        : timeUntilNextShortBreak;

    final mins = remaining.inMinutes;
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final title =
        settings.menuBarStyle == 'countdown' || settings.trayIconStyle == 'countdown'
        ? '$mins:$secs'
        : '';
    sl<TrayManagerService>().setTrayTitle(title);

    final status = state == TimerState.breakActive
        ? 'Break active'
        : _contextManager.isSmartPauseActive()
        ? 'Paused for meeting or Focus'
        : !_contextManager.isWithinWorkingHours()
        ? 'Paused outside working hours'
        : state == TimerState.paused
        ? 'Paused'
        : 'Next break';
    sl<TrayManagerService>().setTooltip('$status in $mins:$secs');
  }

  void _setupActivityMonitor() {
    _activityMonitor.setIdleThreshold(_pauseTimerAfterMinutes);
    _activityMonitor.setActivityCallback((isActive) {
      if (isActive && state == TimerState.paused && !_stateData.isManuallyPaused) {
        resumeTimers();
      } else if (!isActive && state == TimerState.running) {
        pauseTimers();
        _pauseAutoResumeTimer?.cancel();
        _pauseAutoResumeTimer = Timer(
          Duration(minutes: _resetTimerAfterMinutes),
          () {
            if (state == TimerState.paused) {
              _stateData.workElapsed = Duration.zero;
              _logger.info('Timer reset after $_resetTimerAfterMinutes min idle');
            }
          },
        );
      }
      _emit(IdleDetectedEvent(isIdle: !isActive));
    });
    _activityMonitor.start();
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
    saveState();
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
    saveState();
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
    sl<StatsService>().recordSkippedBreak();
    notifyListeners();
  }

  void postponeBreak() {
    _stateData.countdownSeconds += 120;
    _stateData.breakEndTime = _stateData.breakEndTime?.add(const Duration(seconds: 120)) ??
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
    _logger.info('System sleep or screen lock detected: pausing break/work timers');
    _stateData.systemSleepPaused = true;
    _stateData.lastTickTime = DateTime.now();
    saveState();
    notifyListeners();
  }

  void handleSystemWake() {
    _logger.info('System wake or screen unlock detected: resuming break/work timers');
    _stateData.systemSleepPaused = false;
    _stateData.lastTickTime = DateTime.now();
    saveState();
    notifyListeners();
  }

  void saveState() {
    _timerRepository.save(
      _stateData,
      shortBreakIntervalMinutes: _shortBreakIntervalMinutes,
      shortBreakDurationSeconds: _shortBreakDurationSeconds,
      preBreakWarningSeconds: _preBreakWarningSeconds,
      longBreakIntervalMinutes: _longBreakIntervalMinutes,
      longBreakDurationMinutes: _longBreakDurationMinutes,
      pauseTimerAfterMinutes: _pauseTimerAfterMinutes,
      resetTimerAfterMinutes: _resetTimerAfterMinutes,
    );
  }

  void restoreState() {
    _timerRepository.restore(
      _stateData,
      defaultShortBreakIntervalMinutes: _shortBreakIntervalMinutes,
      defaultShortBreakDurationSeconds: _shortBreakDurationSeconds,
      defaultPreBreakWarningSeconds: _preBreakWarningSeconds,
      defaultLongBreakIntervalMinutes: _longBreakIntervalMinutes,
      defaultLongBreakDurationMinutes: _longBreakDurationMinutes,
      defaultPauseTimerAfterMinutes: _pauseTimerAfterMinutes,
      defaultResetTimerAfterMinutes: _resetTimerAfterMinutes,
      onSettingsRestored: (
        shortInterval,
        shortDuration,
        preWarning,
        longInterval,
        longDuration,
        pauseAfter,
        resetAfter,
      ) {
        _shortBreakIntervalMinutes = shortInterval;
        _shortBreakDurationSeconds = shortDuration;
        _preBreakWarningSeconds = preWarning;
        _longBreakIntervalMinutes = longInterval;
        _longBreakDurationMinutes = longDuration;
        _pauseTimerAfterMinutes = pauseAfter;
        _resetTimerAfterMinutes = resetAfter;
      },
    );
  }

  void _startUsageTracking() {
    _usageTrackerTimer?.cancel();
    _usageTrackerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state == TimerState.running) {
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
