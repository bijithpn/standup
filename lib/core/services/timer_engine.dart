import 'package:clock/clock.dart';

import 'dart:async';
import 'dart:math';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import 'package:breakmate/core/services/health_reminder_scheduler.dart';
import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/core/services/break_determination_strategy.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/errors/error_handler.dart';

export 'package:breakmate/features/break_system/domain/break_model.dart'
    show BreakType;
export 'package:breakmate/core/services/timer_state.dart'
    show TimerState, WorkMode;

/// The central state machine governing focus sessions, break countdowns,
/// and wellness micro-reminders (posture, eye blinking). It handles the tick loop,
/// settings synchronization, and system sleep/wake event handling.
class TimerEngine extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final SmartDetectionService? _smartDetectionService;
  final EventBus _eventBus;
  final AppLogger _logger = AppLogger();

  final TimerStateData _stateData = TimerStateData();
  late final TimerContextManager _contextManager;

  Timer? _tickTimer;
  bool _isDisposed = false;

  int _shortBreakIntervalMinutes =
      AppConstants.defaultShortBreakIntervalMinutes;
  int _shortBreakDurationSeconds =
      AppConstants.defaultShortBreakDurationSeconds;
  int _preBreakWarningSeconds = AppConstants.defaultPreBreakWarningSeconds;
  int _longBreakIntervalMinutes = AppConstants.defaultLongBreakIntervalMinutes;
  int _longBreakDurationMinutes = AppConstants.defaultLongBreakDurationMinutes;
  int _pauseTimerAfterMinutes = 5;
  int _resetTimerAfterMinutes = 15;
  BreakDeterminationStrategy _breakDeterminationStrategy =
      const IdleTimeBreakStrategy(innerStrategy: RepeatCycleBreakStrategy());

  // Health reminders (posture/eye rest) no longer run on a fixed,
  // user-set countdown — each fires once at a randomized point within the
  // current work cycle (see `_checkHealthReminders`). These hold that
  // cycle's chosen target in seconds; null means "not yet picked for this
  // cycle". Not part of TimerStateData because they're never persisted —
  // a fresh random target is fine after every app restart.
  final HealthReminderScheduler _healthScheduler;

  // Active-work seconds since each reminder was last satisfied. They live in
  // [TimerStateData] so all of them survive a restart.
  int _elapsedFor(HealthReminderKind kind) => switch (kind) {
    HealthReminderKind.eyeRest => _stateData.eyeBlinkElapsedSeconds,
    HealthReminderKind.posture => _stateData.postureElapsedSeconds,
    HealthReminderKind.hydration => _stateData.hydrationElapsedSeconds,
    HealthReminderKind.stretch => _stateData.stretchElapsedSeconds,
    HealthReminderKind.standUp => _stateData.standUpElapsedSeconds,
  };

  void _resetElapsed(HealthReminderKind kind) {
    switch (kind) {
      case HealthReminderKind.eyeRest:
        _stateData.eyeBlinkElapsedSeconds = 0;
      case HealthReminderKind.posture:
        _stateData.postureElapsedSeconds = 0;
      case HealthReminderKind.hydration:
        _stateData.hydrationElapsedSeconds = 0;
      case HealthReminderKind.stretch:
        _stateData.stretchElapsedSeconds = 0;
      case HealthReminderKind.standUp:
        _stateData.standUpElapsedSeconds = 0;
    }
  }

  /// One switch controls them all; the scheduler picks which one to show.
  bool _reminderEnabled(HealthReminderKind kind, SettingsModel s) =>
      s.healthRemindersEnabled;

  void _resetAllReminderCounters() {
    for (final kind in HealthReminderKind.values) {
      _resetElapsed(kind);
      _healthScheduler.clearTarget(kind);
    }
  }

  final ValueNotifier<int> countdownNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Duration> workElapsedNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> totalWorkTodayNotifier =
      ValueNotifier<Duration>(Duration.zero);

  TimerEngine({
    required SettingsRepository settingsRepository,
    SmartDetectionService? smartDetectionService,
    CalendarService? calendarService,
    PresentationDetectionService? presentationDetectionService,
    MeetingDetectionService? meetingDetectionService,
    ContextSwitchTracker? contextSwitchTracker,
    EventBus? eventBus,
    HealthReminderScheduler? healthScheduler,
  }) : _settingsRepository = settingsRepository,
       _healthScheduler = healthScheduler ?? HealthReminderScheduler(),
       _smartDetectionService = smartDetectionService,
       _eventBus = eventBus ?? EventBus.instance {
    _contextManager = TimerContextManager(
      settingsRepository: _settingsRepository,
      smartDetectionService: _smartDetectionService,
      calendarService: calendarService,
      presentationDetectionService: presentationDetectionService,
      meetingDetectionService: meetingDetectionService,
      contextSwitchTracker: contextSwitchTracker,
    );
    _syncSettingsFromRepo();
    _settingsRepository.addListener(_onSettingsChanged);

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

  void _onSettingsChanged() {
    _syncSettingsFromRepo();
    if (state == TimerState.running) {
      _stateData.workEndTime = clock.now().add(timeUntilNextShortBreak);
      final remaining = timeUntilNextShortBreak.inSeconds;
      _stateData.countdownSeconds = remaining;
      countdownNotifier.value = remaining;
      notifyListeners();
    } else if (state == TimerState.paused && !_stateData.isManuallyPaused) {
      final remaining = timeUntilNextShortBreak.inSeconds;
      _stateData.countdownSeconds = remaining;
      countdownNotifier.value = remaining;
      notifyListeners();
    }
  }

  TimerStateData get stateData => _stateData;
  TimerContextManager get contextManager => _contextManager;
  bool get systemSleepPaused => _stateData.systemSleepPaused;

  void syncNotifiersFromState() {
    if (state == TimerState.running ||
        state == TimerState.paused ||
        state == TimerState.idle) {
      _stateData.countdownSeconds = timeUntilNextShortBreak.inSeconds;
    }
    countdownNotifier.value = _stateData.countdownSeconds;
    workElapsedNotifier.value = _stateData.workElapsed;
    totalWorkTodayNotifier.value = _stateData.totalWorkToday;
  }

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

  BreakDeterminationStrategy get breakDeterminationStrategy =>
      _breakDeterminationStrategy;
  set breakDeterminationStrategy(BreakDeterminationStrategy strategy) {
    _breakDeterminationStrategy = strategy;
    notifyListeners();
  }

  int get completedShortBreaksInCycle => _stateData.completedShortBreaksInCycle;
  set completedShortBreaksInCycle(int val) {
    _stateData.completedShortBreaksInCycle = val;
    notifyListeners();
  }

  int get repeatCycle => (_shortBreakIntervalMinutes > 0)
      ? max(1, (_longBreakIntervalMinutes / _shortBreakIntervalMinutes).round())
      : 4;

  TimerState get state => _stateData.state;
  WorkMode get mode => _stateData.mode;
  BreakModel? get activeBreak => _stateData.activeBreak;
  int get countdownSeconds {
    if (state == TimerState.running ||
        state == TimerState.paused ||
        state == TimerState.idle) {
      return timeUntilNextShortBreak.inSeconds;
    }
    if (state == TimerState.breakActive) {
      return _remainingUntilBreakEnd()?.inSeconds ??
          _stateData.countdownSeconds;
    }
    return _stateData.countdownSeconds;
  }

  /// Remaining time to the absolute break deadline, rounded up to whole
  /// seconds so the display never shows 0 before the deadline. Null when no
  /// deadline is set.
  Duration? _remainingUntilBreakEnd() {
    final end = _stateData.breakEndTime;
    if (end == null) return null;
    final ms = end.difference(clock.now()).inMilliseconds;
    if (ms <= 0) return Duration.zero;
    return Duration(seconds: (ms + 999) ~/ 1000);
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

    _stateData.lastTickTime = clock.now();

    // Recalculate target end times based on the current system clock to prevent drift after suspension.
    if (state == TimerState.breakActive) {
      _stateData.breakEndTime ??= clock.now().add(
        Duration(seconds: _stateData.countdownSeconds),
      );
      _stateData.workEndTime = null;
    } else if (state == TimerState.running) {
      _stateData.workEndTime = clock.now().add(timeUntilNextShortBreak);
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
      final now = clock.now();

      // Skip processing while the system is asleep to avoid state corruption from stale deltas.
      if (_stateData.systemSleepPaused) {
        return;
      }

      if (state == TimerState.paused) {
        if (!_stateData.isManuallyPaused &&
            _contextManager.shouldRunWorkTimer()) {
          _logger.info(
            'Auto-resuming work timer: smart pause condition cleared',
          );
          resumeTimers();
        }
        return;
      }

      if (state == TimerState.idle) {
        return;
      }

      final delta = now.difference(_stateData.lastTickTime ?? now);
      _stateData.lastTickTime = now;

      bool significantChange = false;

      if (state == TimerState.running) {
        if (_checkClockOut(now)) return;

        // Context-aware pausing (e.g., active meeting detection).
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
        _stateData.hydrationElapsedSeconds += delta.inSeconds;
        _stateData.stretchElapsedSeconds += delta.inSeconds;
        _stateData.standUpElapsedSeconds += delta.inSeconds;

        final wasPreBreak = isPreBreak;
        _checkBreakConditions();
        if (wasPreBreak != isPreBreak) significantChange = true;

        _checkHealthReminders();

        workElapsedNotifier.value = _stateData.workElapsed;
        totalWorkTodayNotifier.value = _stateData.totalWorkToday;
        final remainingSeconds = timeUntilNextShortBreak.inSeconds;
        _stateData.countdownSeconds = remainingSeconds;
        countdownNotifier.value = remainingSeconds;
      } else if (state == TimerState.breakActive) {
        _stateData.breakEndTime ??= now.add(
          Duration(seconds: _stateData.countdownSeconds),
        );
        _stateData.countdownSeconds = countdownSeconds;
        countdownNotifier.value = _stateData.countdownSeconds;

        if (_stateData.countdownSeconds <= 0) {
          finishBreak(skipped: false);
          return;
        }
      }

      final prevWorkEndTime = _stateData.workEndTime;
      final prevBreakEndTime = _stateData.breakEndTime;

      if (state == TimerState.breakActive) {
        _stateData.workEndTime = null;
      } else if (state == TimerState.running) {
        _stateData.workEndTime ??= clock.now().add(timeUntilNextShortBreak);
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

      _contextManager.isMeetingUpcoming().then((isMeeting) {
        if (state != TimerState.running) {
          _logger.info(
            'Aborting break trigger: timer is no longer running (current state: $state)',
          );
          return;
        }
        if (isMeeting) {
          _contextManager.minutesUntilNextFreeGap().then((gapMinutes) {
            if (state != TimerState.running) return;
            final rawDelay = (gapMinutes != null && gapMinutes > 0)
                ? Duration(minutes: gapMinutes)
                : const Duration(minutes: 5);
            // Cap the delay to one interval — if the calendar is packed
            // further out than that, defer by a full cycle and re-check
            // rather than pushing workElapsed deeply negative.
            final delay = rawDelay > interval ? interval : rawDelay;
            _logger.info(
              'Delaying break by ${delay.inMinutes}min to land in the next calendar gap',
            );
            _stateData.workElapsed = interval - delay;
            notifyListeners();
          });
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

    // Cadence follows evidence-based baselines (eye rest: the 20-20-20 rule,
    // posture: roughly every 30 minutes); the break interval only nudges it by
    // up to ±20%. All timing decisions — real relief from idle time, holding
    // off when a break is imminent, deferring during meetings, spacing,
    // backing off when ignored — live in HealthReminderScheduler.
    final activityRatio =
        _shortBreakIntervalMinutes /
        AppConstants.defaultShortBreakIntervalMinutes;
    final lowBattery =
        settings.quietModeEnabled && settings.quietModePreset == 'low_battery';

    final elapsed = <HealthReminderKind, int>{
      for (final kind in HealthReminderKind.values)
        if (_reminderEnabled(kind, settings)) kind: _elapsedFor(kind),
    };
    if (elapsed.isEmpty) return;

    final now = clock.now();
    final due = _healthScheduler.nextDue(
      now: now,
      elapsedSeconds: elapsed,
      untilNextBreak: timeUntilNextShortBreak,
      blockedByContext:
          _contextManager.isMeetingActive() ||
          _contextManager.isPresentationActive(),
      activityRatio: activityRatio,
      cadenceMultiplier: lowBattery ? 2.0 : 1.0,
      workloadFactor: WorkloadEstimator.factor(
        workedToday: _stateData.totalWorkToday,
        highContextSwitching: _contextManager.isHighContextSwitchRate(),
      ),
    );
    if (due == null) return;

    final covered = _healthScheduler.markFired(due, now);
    _resetElapsed(due);
    covered.forEach(_resetElapsed);
    _triggerHealthReminder(due.typeName, 'overlay');
  }

  /// Feed of how long the user has been without keyboard/mouse input
  /// (seconds), sampled every few seconds. Stepping away is real relief: it
  /// resets the matching reminder instead of nagging right after.
  void reportIdleSeconds(double idleSeconds) {
    final relieved = _healthScheduler.onIdleSample(idleSeconds, clock.now());
    relieved.forEach(_resetElapsed);
  }

  void _triggerHealthReminder(String reminderType, String displayType) {
    _logger.info('Triggering $reminderType reminder ($displayType)');
    _emit(
      HealthReminderEvent(reminderType: reminderType, displayType: displayType),
    );
  }

  void _triggerClockOut() {
    _stateData.state = TimerState.windDown;
    _stateData.workElapsed = Duration.zero;
    _stateData.countdownSeconds = 60;
    _stateData.breakEndTime = clock.now().add(
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

  void _triggerBreak() {
    _stateData.state = TimerState.breakActive;
    _stateData.workElapsed = Duration.zero;

    final isLongBreak = isLongBreakDue();

    final durationSeconds = _breakDeterminationStrategy
        .determineBreakDurationSeconds(
          isLongBreak: isLongBreak,
          shortBreakDurationSeconds: _shortBreakDurationSeconds,
          longBreakDurationMinutes: _longBreakDurationMinutes,
        );
    _stateData.countdownSeconds = durationSeconds;
    _stateData.breakEndTime = clock.now().add(
      Duration(seconds: durationSeconds),
    );

    if (isLongBreak) {
      _stateData.activeBreak = BreakModel(
        type: BreakType.long,
        durationSeconds: countdownSeconds,
        title: 'LONG BREAK',
        tip:
            'Time to stand, stretch, and mentally reset. Step away from your desk.',
        triggerReason: 'Long focus session completed (cycle reached)',
      );
      _stateData.longBreakWindowStartedAt = clock.now();
      _stateData.completedShortBreaksInCycle = 0;
    } else {
      _stateData.activeBreak = BreakModel(
        type: BreakType.short,
        durationSeconds: countdownSeconds,
        title: 'Eye Rest',
        tip: _randomTip(AppConstants.shortBreakTips),
        triggerReason: 'Short break interval reached',
      );
      _stateData.completedShortBreaksInCycle++;
    }

    _stateData.breakEndTime = clock.now().add(
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

      NativeBridge.updateOverlayData(
        OverlayData(<String, dynamic>{
          'title': 'Well Done!',
          'remainingSeconds': 0,
          'durationSeconds':
              activeBreak?.durationSeconds ?? _shortBreakDurationSeconds,
          'strictMode': false,
        }),
      );
    }

    _emit(BreakEndedEvent(skipped: skipped));

    if (!skipped) {
      // A completed break rests the eyes and changes position, so those
      // reminders are not due right after it (a long one also covers a drink);
      // a skipped break does none of that.
      final isLong = activeBreak?.type == BreakType.long;
      for (final kind in HealthReminderKind.values) {
        if (kind == HealthReminderKind.hydration && !isLong) continue;
        _resetElapsed(kind);
      }
      _healthScheduler.onBreakCompleted(clock.now(), long: isLong);
    }

    _stateData.activeBreak = null;
    _stateData.isCompletionState = false;
    _stateData.state = TimerState.running;
    _stateData.isPreBreak = false;
    _stateData.lastTickTime = clock.now();
    _stateData.workElapsed = Duration.zero;
    _stateData.breakEndTime = null;
    _stateData.workEndTime = clock.now().add(timeUntilNextShortBreak);

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
      tray.setMenuStyle(style);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
    notifyListeners();
  }

  bool isLongBreakDue() {
    final now = clock.now();
    _stateData.longBreakWindowStartedAt ??= now;
    final elapsedSinceLong = now.difference(
      _stateData.longBreakWindowStartedAt!,
    );
    return _breakDeterminationStrategy.isLongBreakDue(
      completedShortBreaksInCycle: _stateData.completedShortBreaksInCycle,
      workElapsed: _stateData.workElapsed,
      elapsedSinceLastLongBreak: elapsedSinceLong,
      repeatCycle: repeatCycle,
      longBreakIntervalMinutes: _longBreakIntervalMinutes,
    );
  }

  void resetCycleOnIdle() {
    _stateData.workElapsed = Duration.zero;
    _stateData.completedShortBreaksInCycle = 0;
    _stateData.longBreakWindowStartedAt = clock.now();
    _logger.info('Reset break cycle after user idle timeout');
    notifyListeners();
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
    _stateData.countdownSeconds = timeUntilNextShortBreak.inSeconds;
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
    _stateData.lastTickTime = clock.now();
    _stateData.breakEndTime = null;
    _stateData.workEndTime = clock.now().add(timeUntilNextShortBreak);
    _stateData.countdownSeconds = timeUntilNextShortBreak.inSeconds;
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
    _resetAllReminderCounters();
    _stateData.state = TimerState.idle;
    _stateData.completedShortBreaksInCycle = 0;
    _stateData.longBreakWindowStartedAt = clock.now();
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

  /// Starts a fresh logical day: clears the day's accumulated work, the clock-out
  /// latch and the in-progress focus cycle so no countdown from the previous
  /// day survives. The timer's mode is preserved (a manual pause stays paused;
  /// a running timer keeps running with a freshly computed deadline).
  ///
  /// An active break is never touched — the caller defers the reset until the
  /// break ends so it cannot be completed twice or restarted.
  /// Returns false when the reset was deferred.
  bool resetForNewDay() {
    if (state == TimerState.breakActive) return false;
    _stateData.totalWorkToday = Duration.zero;
    _stateData.workElapsed = Duration.zero;
    _resetAllReminderCounters();
    _stateData.isPreBreak = false;
    _stateData.completedShortBreaksInCycle = 0;
    _stateData.clockOutTriggered = false;
    _stateData.longBreakWindowStartedAt = clock.now();
    _stateData.lastTickTime = clock.now();
    if (state == TimerState.running) {
      _stateData.workEndTime = clock.now().add(timeUntilNextShortBreak);
    } else {
      _stateData.workEndTime = null;
    }
    _stateData.countdownSeconds = timeUntilNextShortBreak.inSeconds;
    syncNotifiersFromState();
    _emit(
      TimerStateChangedEvent(
        state: state == TimerState.running
            ? TimerStateEvent.running
            : state == TimerState.idle
            ? TimerStateEvent.idle
            : TimerStateEvent.paused,
        countdownSeconds: _stateData.countdownSeconds,
        workElapsedSeconds: 0,
        targetEndTime: targetEndTime,
      ),
    );
    notifyListeners();
    return true;
  }

  void triggerBreakNow({bool isLong = false}) {
    if (isLong) {
      _stateData.longBreakWindowStartedAt = clock.now().subtract(
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
    final base = _stateData.breakEndTime ?? clock.now();
    _stateData.breakEndTime = base.add(const Duration(seconds: 120));
    _stateData.countdownSeconds = countdownSeconds;
    countdownNotifier.value = _stateData.countdownSeconds;
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

  /// Handles the transition when the system goes to sleep or the screen locks.
  /// We persist the current timestamp to storage to calculate elapsed sleep time on wake.
  void handleSystemSleep() {
    _logger.info(
      'System sleep or screen lock detected: pausing break/work timers',
    );
    // Lock then sleep fire back to back; keep the first timestamp so the
    // whole away period is measured.
    if (_stateData.systemSleepPaused) return;
    _stateData.systemSleepPaused = true;
    final now = clock.now();
    _stateData.lastTickTime = now;
    try {
      sl<StorageService>().setInt(
        'timer_last_tick_time',
        now.millisecondsSinceEpoch,
      );
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
    notifyListeners();
  }

  /// Handles recovery upon system wake or screen unlock by reconciling against
  /// the authoritative deadlines rather than any per-tick counter:
  ///  - Active break: remaining time is recomputed from `breakEndTime`. If the
  ///    deadline passed while asleep the break completes exactly once (the
  ///    `breakActive` guard in `finishBreak` makes repeated wakes a no-op).
  ///  - Manually paused: stays paused; the paused remaining time is untouched.
  ///  - Work timer: if the user was away at least one break interval we assume
  ///    they took an offline break and reset; otherwise work resumes with the
  ///    time that was left (sleep is not counted as work).
  ///
  /// Limitation: deadlines are wall-clock `DateTime`s, so a manual clock change
  /// or DST shift while a break is active moves the deadline by the same
  /// amount. Breaks are short (minutes) so the effect is bounded.
  void handleSystemWake() {
    _logger.info(
      'System wake or screen unlock detected: checking recovery flow',
    );
    final wasAsleep = _stateData.systemSleepPaused;
    _stateData.systemSleepPaused = false;

    if (_stateData.lastTickTime == null) {
      try {
        final lastTickMs = sl<StorageService>().getInt(
          'timer_last_tick_time',
          defaultValue: 0,
        );
        if (lastTickMs > 0) {
          _stateData.lastTickTime = DateTime.fromMillisecondsSinceEpoch(
            lastTickMs,
          );
        }
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
    }

    try {
      sl<StorageService>().setInt('timer_last_tick_time', 0);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    // Duplicate wake/unlock notifications (lock + wake fire back to back).
    if (!wasAsleep && state != TimerState.breakActive) {
      syncNotifiersFromState();
      notifyListeners();
      return;
    }

    if (state == TimerState.breakActive) {
      // The break deadline is wall-clock, so push it out by the time spent
      // asleep/locked: the break countdown pauses while the user is away.
      final end = _stateData.breakEndTime;
      final slept = _stateData.lastTickTime;
      if (wasAsleep && end != null && slept != null) {
        final away = clock.now().difference(slept);
        if (!away.isNegative) _stateData.breakEndTime = end.add(away);
      }
      final remaining = _remainingUntilBreakEnd();
      if (remaining != null && remaining <= Duration.zero) {
        _logger.info('Break deadline passed: completing break');
        finishBreak(skipped: false);
      } else {
        _emit(
          TimerStateChangedEvent(
            state: TimerStateEvent.breakActive,
            countdownSeconds: countdownSeconds,
            workElapsedSeconds: _stateData.workElapsed.inSeconds,
            targetEndTime: targetEndTime,
          ),
        );
        _stateData.lastTickTime = clock.now();
        _stateData.countdownSeconds = countdownSeconds;
        syncNotifiersFromState();
        notifyListeners();
      }
      return;
    }

    if (state == TimerState.paused && _stateData.isManuallyPaused) {
      _stateData.lastTickTime = clock.now();
      syncNotifiersFromState();
      notifyListeners();
      return;
    }

    final lastTick = _stateData.lastTickTime ?? clock.now();
    final durationAway = clock.now().difference(lastTick);

    if (state != TimerState.windDown &&
        durationAway.inMinutes >= _shortBreakIntervalMinutes) {
      _logger.info(
        'Away for ${durationAway.inMinutes}m. Resetting focus session.',
      );
      resetTimers();
    } else if (state == TimerState.running || state == TimerState.paused) {
      _stateData.lastTickTime = clock.now();
      resumeTimers();
    }

    syncNotifiersFromState();
    notifyListeners();
  }

  String _randomTip(List<String> tips) {
    final copy = List<String>.from(tips)..shuffle();
    return copy.first;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tickTimer?.cancel();
    _settingsRepository.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
