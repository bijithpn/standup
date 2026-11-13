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
import 'package:breakmate/core/services/health_reminder_copy.dart';
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

/// Core work/break state machine (idle, running, paused, breakActive, windDown) driven by a 1s tick; publishes changes via ChangeNotifier and the EventBus.
class TimerEngine extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final SmartDetectionService? _smartDetectionService;
  final EventBus _eventBus;
  final AppLogger _logger = AppLogger();

  // All mutable timer state lives here; times are absolute (workEndTime/breakEndTime) so UI countdowns survive missed ticks.
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

  // Eye/posture/hydration/etc. reminders are counted while work runs; the scheduler decides which one fires.
  final HealthReminderScheduler _healthScheduler;

  int _elapsedFor(HealthReminderKind kind) => switch (kind) {
    HealthReminderKind.eyeRest => _stateData.eyeBlinkElapsedSeconds,
    HealthReminderKind.blink => _stateData.blinkElapsedSeconds,
    HealthReminderKind.posture => _stateData.postureElapsedSeconds,
    HealthReminderKind.hydration => _stateData.hydrationElapsedSeconds,
    HealthReminderKind.stretch => _stateData.stretchElapsedSeconds,
    HealthReminderKind.standUp => _stateData.standUpElapsedSeconds,
  };

  void _resetElapsed(HealthReminderKind kind) {
    switch (kind) {
      case HealthReminderKind.eyeRest:
        _stateData.eyeBlinkElapsedSeconds = 0;
      case HealthReminderKind.blink:
        _stateData.blinkElapsedSeconds = 0;
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

  bool _reminderEnabled(HealthReminderKind kind, SettingsModel s) =>
      s.healthRemindersEnabled &&
      (kind != HealthReminderKind.blink || s.blinkRemindersEnabled);

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

  // Re-derive the countdown immediately so interval edits apply without waiting for the next tick.
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

  // Countdown is derived from workElapsed, not stored, so pauses and idle discards stay consistent.
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

  /// Starts the tick loop; from idle it enters running, and a resumed break keeps its remaining time.
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
      try {
        _tickOnce();
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
    });
  }

  /// One second of work: handles sleep gaps, smart pauses, elapsed accounting, break/reminder checks and break countdown.
  void _tickOnce() {
    {
      final now = clock.now();

      // Ticks are ignored while the system is asleep/locked; handleSystemWake resumes.
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

      final lastTick = _stateData.lastTickTime;
      // A >15s gap between ticks means the machine slept without a sleep event.
      if (lastTick != null &&
          now.difference(lastTick) > const Duration(seconds: 15)) {
        _logger.info('Tick gap detected: treating as system sleep');
        _stateData.systemSleepPaused = true;
        handleSystemWake();
        return;
      }

      final delta = now.difference(_stateData.lastTickTime ?? now);
      _stateData.lastTickTime = now;

      bool significantChange = false;

      if (state == TimerState.running) {
        if (_checkClockOut(now)) return;

        // manualOverride keeps the timer running after the user resumed it despite a smart pause, until the pause condition clears.
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
        _stateData.blinkElapsedSeconds += delta.inSeconds;
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
    }
  }

  bool _checkClockOut(DateTime now) {
    if (_contextManager.checkClockOut(now, _stateData.clockOutTriggered)) {
      _stateData.clockOutTriggered = true;
      _triggerClockOut();
      return true;
    }
    return false;
  }

  /// Toggles the pre-break warning window and triggers a break when the interval elapses (unless suppressed, deferred or in a meeting).
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

      final now = clock.now();
      if (_settingsRepository.currentSettings.avoidBreakHour == now.hour) {
        // Avoided hour: push the break to the start of the next hour.
        final delay = Duration(minutes: 60 - now.minute);
        _stateData.workElapsed =
            interval - (delay > interval ? interval : delay);
        notifyListeners();
        return;
      }

      // Async calendar check; the state is re-verified in the callback because the timer may have changed meanwhile.
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

  /// Asks the scheduler which health reminder is due (never during meetings/presentations) and fires at most one.
  void _checkHealthReminders() {
    final settings = _settingsRepository.currentSettings;
    if (settings.quietModeEnabled) {
      if (settings.quietModePreset == 'presenting' ||
          settings.quietModePreset == 'deep_work') {
        return;
      }
    }

    if (_checkCustomReminders(settings)) return;

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

  // Custom reminders are keyed by title|minutes and use a simple wall-clock interval.
  final Map<String, DateTime> _customLastFired = {};

  bool _checkCustomReminders(SettingsModel settings) {
    if (_contextManager.isMeetingActive() ||
        _contextManager.isPresentationActive()) {
      return false;
    }
    final now = clock.now();
    for (final r in settings.customReminders) {
      final key = '${r.title}|${r.minutes}';
      final last = _customLastFired.putIfAbsent(key, () => now);
      if (now.difference(last) < Duration(minutes: r.minutes)) continue;
      _customLastFired[key] = now;
      _triggerHealthReminder(
        '${HealthReminderCopy.customPrefix}${r.title}',
        'overlay',
      );
      return true;
    }
    return false;
  }

  /// Fed idle samples: lets health reminders count real rests and recovers from a stuck sleep flag when input resumes.
  void reportIdleSeconds(double idleSeconds) {
    final since = _stateData.lastTickTime;
    if (_stateData.systemSleepPaused &&
        idleSeconds < 3 &&
        since != null &&
        clock.now().difference(since) > const Duration(seconds: 15)) {
      _logger.warning('Input detected while sleep flag stuck: recovering');
      handleSystemWake();
    }
    final relieved = _healthScheduler.onIdleSample(idleSeconds, clock.now());
    relieved.forEach(_resetElapsed);
  }

  void _triggerHealthReminder(String reminderType, String displayType) {
    _logger.info('Triggering $reminderType reminder ($displayType)');
    _emit(
      HealthReminderEvent(reminderType: reminderType, displayType: displayType),
    );
  }

  // Clock-out starts a 60s wind-down "break" instead of a normal break.
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

  /// Enters breakActive: picks long vs short via the strategy, sets the end time and emits BreakStartedEvent (which shows the overlay).
  void _triggerBreak({int? durationOverride}) {
    _stateData.state = TimerState.breakActive;
    _stateData.workElapsed = Duration.zero;

    final isLongBreak = isLongBreakDue();

    final durationSeconds =
        durationOverride ??
        _breakDeterminationStrategy.determineBreakDurationSeconds(
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

  /// Ends the active break (completed or skipped), resets reminder counters on completion and returns to running.
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

  /// Delegates to the break strategy with the current cycle count and time since the last long break.
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

  /// Removes idle time from elapsed counters (the idle threshold had already been counted as work).
  void discardIdleTime(Duration idle) {
    if (idle <= Duration.zero) return;
    Duration back(Duration v) => v > idle ? v - idle : Duration.zero;
    _stateData.workElapsed = back(_stateData.workElapsed);
    _stateData.totalWorkToday = back(_stateData.totalWorkToday);
    workElapsedNotifier.value = _stateData.workElapsed;
    totalWorkTodayNotifier.value = _stateData.totalWorkToday;
  }

  /// Starts a fresh break cycle after a long idle period.
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

  /// Pauses work; [isManual] distinguishes a user pause (no auto-resume) from a smart pause (resumes when the condition clears).
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

  /// Daily reset hook for DailyResetService; returns false (deferred) while a break is active.
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

  // For a forced long break, backdate the window so the strategy sees the interval as elapsed.
  void triggerBreakNow({bool isLong = false, int? durationSeconds}) {
    if (isLong) {
      _stateData.longBreakWindowStartedAt = clock.now().subtract(
        Duration(minutes: _longBreakIntervalMinutes),
      );
    }
    _triggerBreak(durationOverride: durationSeconds);
  }

  void skipNextBreak() {
    _stateData.workElapsed = Duration.zero;
    _emit(BreakEndedEvent(skipped: true));
    notifyListeners();
  }

  // Adds 2 minutes to the active break end time.
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

  /// Set by the orchestrator; invoked after a long absence resets the session so timers can be restarted.
  VoidCallback? onNeedsRestart;

  /// Freezes ticking and persists the last tick time so wake can compute time away even after a restart.
  void handleSystemSleep({DateTime? at}) {
    _logger.info(
      'System sleep or screen lock detected: pausing break/work timers',
    );

    if (_stateData.systemSleepPaused) return;
    _stateData.systemSleepPaused = true;

    final now = at ?? clock.now();
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

  /// Reconciles after sleep: extends a running break by the time asleep, ends it if past due, or resets the session if away longer than one work interval.
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

    if (!wasAsleep && state != TimerState.breakActive) {
      syncNotifiersFromState();
      notifyListeners();
      return;
    }

    if (state == TimerState.breakActive) {
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
      onNeedsRestart?.call();
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
