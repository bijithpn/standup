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
import 'package:breakmate/features/settings/settings_repository.dart';

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
  final Random _healthReminderRandom = Random();
  int? _postureTargetSeconds;
  int? _eyeBlinkTargetSeconds;

  // Evidence-based baseline cadences — see `_checkHealthReminders`.
  static const int _eyeRestBaselineMinutes = 20; // the 20-20-20 rule
  static const int _postureBaselineMinutes = 30; // common ergonomic guidance

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
  }) : _settingsRepository = settingsRepository,
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
      _stateData.breakEndTime = clock.now().add(
        Duration(seconds: countdownSeconds),
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

      if (state == TimerState.paused || state == TimerState.idle) {
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
        _stateData.countdownSeconds--;
        countdownNotifier.value = _stateData.countdownSeconds;

        if (countdownSeconds <= 0) {
          finishBreak(skipped: false);
          return;
        }
      }

      final prevWorkEndTime = _stateData.workEndTime;
      final prevBreakEndTime = _stateData.breakEndTime;

      if (state == TimerState.breakActive) {
        _stateData.breakEndTime ??= clock.now().add(
          Duration(seconds: countdownSeconds),
        );
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

    // Health reminders are enable/disable only now — no manual interval —
    // and are timed off evidence-based cadences, not an arbitrary fraction
    // of whatever the (adaptive, sometimes very long) break interval
    // happens to be:
    //  - Eye rest follows the well-known 20-20-20 rule: roughly every 20
    //    minutes, look at something 20 feet away for 20 seconds.
    //  - Posture checks follow common ergonomic guidance: change position
    //    and sit up straight roughly every 30 minutes.
    // Tying these directly to `shortBreakIntervalMinutes` (which
    // AdaptiveBreakService can stretch up to 90 minutes on a
    // light-activity day) would let eye strain build for over an hour —
    // the opposite of "helpful for a healthy body". Instead, that same
    // adaptive signal only nudges the baseline by up to ±20% (busier/more
    // active right now → nudged more frequent, matching the same
    // usage-driven signal the break timer itself responds to), and a
    // little jitter keeps the cadence from feeling mechanically fixed
    // while staying inside a sensible range. This piggybacks on the tick
    // this method is already called from every second — no extra timers,
    // no added CPU cost.
    final activityRatio = (_shortBreakIntervalMinutes /
            AppConstants.defaultShortBreakIntervalMinutes)
        .clamp(0.8, 1.2);
    final slowdown =
        settings.quietModeEnabled && settings.quietModePreset == 'low_battery'
        ? 2
        : 1;

    if (settings.postureReminderEnabled) {
      _postureTargetSeconds ??= _healthReminderTargetSeconds(
        baselineMinutes: _postureBaselineMinutes,
        activityRatio: activityRatio,
        slowdown: slowdown,
      );
      if (_stateData.postureElapsedSeconds >= _postureTargetSeconds!) {
        _stateData.postureElapsedSeconds = 0;
        _postureTargetSeconds = null;
        _triggerHealthReminder('posture', 'overlay');
      }
    }

    if (settings.eyeBlinkReminderEnabled) {
      _eyeBlinkTargetSeconds ??= _healthReminderTargetSeconds(
        baselineMinutes: _eyeRestBaselineMinutes,
        activityRatio: activityRatio,
        slowdown: slowdown,
      );
      if (_stateData.eyeBlinkElapsedSeconds >= _eyeBlinkTargetSeconds!) {
        _stateData.eyeBlinkElapsedSeconds = 0;
        _eyeBlinkTargetSeconds = null;
        _triggerHealthReminder('eyeblink', 'overlay');
      }
    }
  }

  int _healthReminderTargetSeconds({
    required int baselineMinutes,
    required double activityRatio,
    required int slowdown,
  }) {
    // ±15% jitter around the (activity-adjusted) baseline.
    final jitter = 0.85 + _healthReminderRandom.nextDouble() * 0.3;
    final minutes = baselineMinutes * activityRatio * jitter * slowdown;
    return (minutes * 60).round().clamp(60, 24 * 60 * 60);
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

  void setFocusMode(bool enabled) {
    _emit(FocusModeEvent(isActive: enabled));
    notifyListeners();
  }

  void _triggerBreak() {
    _stateData.state = TimerState.breakActive;
    _stateData.workElapsed = Duration.zero;

    final isLongBreak = isLongBreakDue();

    final durationSeconds =
        _breakDeterminationStrategy.determineBreakDurationSeconds(
      isLongBreak: isLongBreak,
      shortBreakDurationSeconds: _shortBreakDurationSeconds,
      longBreakDurationMinutes: _longBreakDurationMinutes,
    );
    _stateData.countdownSeconds = durationSeconds;

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
      tray.setIconModeFromStyle(style);
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
    _stateData.postureElapsedSeconds = 0;
    _stateData.eyeBlinkElapsedSeconds = 0;
    _postureTargetSeconds = null;
    _eyeBlinkTargetSeconds = null;
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
    _stateData.countdownSeconds += 120;
    _stateData.breakEndTime =
        _stateData.breakEndTime?.add(const Duration(seconds: 120)) ??
        clock.now().add(Duration(seconds: countdownSeconds));
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

  /// Handles recovery upon system wake or screen unlock.
  /// If the duration away exceeds the short break interval, we assume the user took an offline break
  /// and reset the focus session. Otherwise, we resume the timer.
  void handleSystemWake() {
    _logger.info(
      'System wake or screen unlock detected: checking recovery flow',
    );
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

    final lastTick = _stateData.lastTickTime ?? clock.now();
    final durationAway = clock.now().difference(lastTick);

    if (durationAway.inMinutes >= _shortBreakIntervalMinutes) {
      _logger.info(
        'Away for ${durationAway.inMinutes}m. Resetting focus session.',
      );
      resetTimers();
    } else {
      _stateData.lastTickTime = clock.now();
      resumeTimers();
    }

    try {
      sl<StorageService>().setInt('timer_last_tick_time', 0);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

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
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }
}
