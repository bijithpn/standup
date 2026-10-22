import 'dart:math' as math;
import 'dart:async';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/health_reminder_copy.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/timer_repository.dart';

import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/native_enhancements_service.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_gate.dart';

/// Coordinates cross-service actions driven by the state updates of TimerEngine.
/// It bridges the core timer system with activity tracking, user alerts, stats logging,
/// settings changes, and secondary engine UI updates via native IPC.
class TimerOrchestrator {
  final TimerEngine timerEngine;
  final TimerRepository timerRepository;
  final SessionStateRepository sessionStateRepository;
  final ActivityMonitor activityMonitor;
  final NotificationService notificationService;
  final StatsService statsService;
  final TrayManagerService trayManagerService;
  final AdaptiveBreakService? adaptiveBreakService;
  final SettingsRepository settingsRepository;
  final EventBus eventBus;

  final AppLogger _logger = AppLogger();
  StreamSubscription? _eventSubscription;
  Timer? _usageTrackerTimer;
  Timer? _pauseAutoResumeTimer;
  Timer? _autoSaveTimer;

  String? _lastTrayTitle;
  String? _lastTrayTooltip;

  TimerOrchestrator({
    required this.timerEngine,
    required this.timerRepository,
    required this.sessionStateRepository,
    required this.activityMonitor,
    required this.notificationService,
    required this.statsService,
    required this.trayManagerService,
    this.adaptiveBreakService,
    required this.settingsRepository,
    required this.eventBus,
  });

  void initialize() {
    _logger.info('Initializing TimerOrchestrator...');

    _restoreState();

    if (timerEngine.state == TimerState.running &&
        timerEngine.stateData.lastTickTime != null) {
      final lastTick = timerEngine.stateData.lastTickTime!;
      final durationAway = DateTime.now().difference(lastTick);
      if (durationAway.inMinutes >= timerEngine.shortBreakIntervalMinutes) {
        _logger.info(
          'Cold boot recovery: Away for ${durationAway.inMinutes}m. Resetting focus session.',
        );
        timerEngine.resetTimers();
      } else {
        _logger.info(
          'Cold boot recovery: Resuming focus session after ${durationAway.inSeconds}s away.',
        );
        timerEngine.stateData.lastTickTime = DateTime.now();
        timerEngine.startTimers();
      }
      sl<StorageService>().setInt('timer_last_tick_time', 0);
    }

    _eventSubscription = eventBus.stream.listen(_handleEvent);

    timerEngine.countdownNotifier.addListener(_onCountdownTick);
    timerEngine.workElapsedNotifier.addListener(_updateTray);

    timerEngine.addListener(_onTimerEngineChanged);

    _setupActivityMonitor();

    _startUsageTracking();

    _updateTray();

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (timerEngine.state == TimerState.running ||
          timerEngine.state == TimerState.breakActive) {
        saveState();
      }
    });
  }

  void _onCountdownTick() {
    _updateTray();
    final remaining = timerEngine.countdownNotifier.value;
    if (timerEngine.state == TimerState.running && remaining == 15) {
      NativeEnhancementsService.instance.showCursorCountdown(seconds: 15);
    } else if (remaining <= 0 || timerEngine.state != TimerState.running) {
      NativeEnhancementsService.instance.hideCursorCountdown();
    }
  }

  void _onTimerEngineChanged() {
    _updateTray();
  }

  /// Routes global application events. High-priority state events (like breaks starting/ending)
  /// are serialized and dispatched over the IPC channel so secondary window processes stay synchronized.
  void _handleEvent(AppEvent event) {
    _logger.info('Received event in Orchestrator: $event');

    if (event is TimerStateChangedEvent) {
      _dispatchTimerStateIpc(event);
      saveState(); // Immediately save state on pause/resume transitions
    } else if (event is BreakStartedEvent) {
      _handleBreakStarted(event);
    } else if (event is BreakEndedEvent) {
      _handleBreakEnded(event);
    } else if (event is HealthReminderEvent) {
      _handleHealthReminder(event);
    } else if (event is BreakPostponedEvent) {
      _handleBreakPostponed(event);
    }
  }

  void _dispatchTimerStateIpc(TimerStateChangedEvent event) {
    final targetEndTime = event.targetEndTime;
    IpcBridge.instance.dispatch(
      TimerStateChangedIpcEvent(
        stateName: event.state.name,
        countdownSeconds: event.countdownSeconds,
        workElapsedSeconds: event.workElapsedSeconds,
        targetEndTime: targetEndTime?.millisecondsSinceEpoch,
        totalWorkTodaySeconds: timerEngine.totalWorkToday.inSeconds,
      ),
    );
  }

  void _handleBreakStarted(BreakStartedEvent event) {
    NativeEnhancementsService.instance.hideCursorCountdown();
    NativeEnhancementsService.instance.preventDisplaySleep(
      reason: event.isLongBreak ? 'Long Break Active' : 'Short Break Active',
    );

    IpcBridge.instance.dispatch(
      BreakStartedIpcEvent(
        isLongBreak: event.isLongBreak,
        durationSeconds: event.durationSeconds,
        title: event.title,
      ),
    );

    trayManagerService.setBreakActive(true);

    if (event.isLongBreak) {
      notificationService.showClockOutReminder();
    } else {
      notificationService.showBreakStarted(breakTitle: event.title);
    }

    saveState();
  }

  Future<void> _handleBreakEnded(BreakEndedEvent event) async {
    NativeEnhancementsService.instance.releaseDisplaySleep();
    IpcBridge.instance.dispatch(BreakEndedIpcEvent(skipped: event.skipped));

    trayManagerService.setBreakActive(false);

    sl<BreakHistoryService>().recordBreak(
      time: DateTime.now(),
      completed: !event.skipped,
    );

    if (event.skipped) {
      statsService.recordSkippedBreak();
    } else {
      await Future.delayed(const Duration(seconds: 2));
      statsService.recordCompletedBreak();

      if (!sl<OverlayWindowService>().isOverlayVisible) {
        await notificationService.showBreakFinished();
      }

      final now = DateTime.now();
      final lastBreakFinishedAt = timerEngine.stateData.lastBreakFinishedAt;
      final sessionDuration = lastBreakFinishedAt != null
          ? now.difference(lastBreakFinishedAt)
          : timerEngine.workElapsed;

      final sessionMinutes = sessionDuration.inMinutes;
      final activityLevel = sessionMinutes > 45
          ? 'high'
          : sessionMinutes > 20
          ? 'medium'
          : 'low';

      adaptiveBreakService?.recordWorkSession(
        duration: sessionDuration,
        hourOfDay: now.hour,
        activityLevel: activityLevel,
      );

      final suggestedInterval = adaptiveBreakService
          ?.getSuggestedBreakInterval();
      if (suggestedInterval != null && suggestedInterval > 0) {
        timerEngine.shortBreakIntervalMinutes = suggestedInterval;
        _logger.info(
          'Adaptive: Next break interval updated to $suggestedInterval min',
        );
      }

      timerEngine.stateData.lastBreakFinishedAt = now;
    }

    saveState();
  }

  void _handleHealthReminder(HealthReminderEvent event) {
    final settings = settingsRepository.currentSettings;

    if (settings.companionEnabled) {
      final interactionType = switch (event.reminderType) {
        'posture' || 'stretch' || 'standup' => 'stretch',
        _ => 'blink',
      };
      eventBus.emit(
        CompanionInteractionEvent(interactionType: interactionType),
      );

      statsService.recordWellnessAction();

      IpcBridge.instance.dispatch(
        CompanionInteractionIpcEvent(interactionType: interactionType),
      );
      return;
    }

    // Native system-notification reminders were unreliable in practice, so
    // health reminders always show the (dismissable, low-opacity) overlay
    // now, regardless of `event.displayType`.
    //
    // `type` below only picks the native window's behavior — the Dart
    // overlay itself reads `overlayType` from the JSON payload, and
    // defaults to the full break-timer template ('breakScreen') when that
    // key is missing. Without it, health reminders rendered the wrong
    // overlay.
    NativeEnhancementsService.instance.triggerFlashReminder(
      text: HealthReminderCopy.text(event.reminderType),
    );

    sl<OverlayWindowService>().showOverlay(
      type: OverlayType.quickReminder,
      builder: (_) => const SizedBox.shrink(),
      reminderType: event.reminderType,
      // A brief reminder only needs the active display — one Flutter
      // engine per connected monitor for a 2-second poster is wasted CPU.
      showOnAllDisplays: false,
      overlayData: {
        'overlayType': 'quickReminder',
        'reminderType': event.reminderType,
        'durationSeconds': AppConstants.healthReminderDismissDuration.inSeconds,
        'remainingSeconds':
            AppConstants.healthReminderDismissDuration.inSeconds,
        // Computed here (main engine) because the overlay's own Flutter
        // isolate doesn't have SettingsRepository or the detection
        // services registered — see `OverlayWindowConfig.allowFullPoster`.
        'allowFullPoster': allowFullPosterReminder(
          detectMeetings: settings.detectMeetings,
          calendarMeetingActive: sl<MeetingDetectionService>().isMeetingActive,
          detectVideoCalls: settings.detectVideoCalls,
          videoCallActive: sl<SmartDetectionService>().isVideoCallActive,
          presenting: sl<PresentationDetectionService>().isPresenting,
        ),
      },
    );

    // Fallback safety-net hide, independent of the overlay's own dismiss
    // timer — must use the same duration so it never clips the reminder
    // early or lingers past it.
    Future.delayed(AppConstants.healthReminderDismissDuration, () {
      if (sl<OverlayWindowService>().currentOverlayType ==
          OverlayType.quickReminder) {
        sl<OverlayWindowService>().hideOverlay();
      }
    });
  }

  void _handleBreakPostponed(BreakPostponedEvent event) {
    NativeEnhancementsService.instance.hideCursorCountdown();
    NativeEnhancementsService.instance.releaseDisplaySleep();
    final settings = settingsRepository.currentSettings;
    if (settings.companionEnabled) {
      eventBus.emit(CompanionInteractionEvent(interactionType: 'meow'));
      IpcBridge.instance.dispatch(
        CompanionInteractionIpcEvent(interactionType: 'meow'),
      );
    } else {
      notificationService.showReminder(
        message: 'Break postponed by ${event.additionalSeconds ~/ 60} minutes.',
      );
    }
  }

  void _updateTray() {
    final settings = settingsRepository.currentSettings;
    final state = timerEngine.state;
    final countdown = timerEngine.countdownSeconds;

    final remaining = state == TimerState.breakActive
        ? Duration(seconds: countdown)
        : timerEngine.timeUntilNextShortBreak;

    final mins = remaining.inMinutes;
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final title =
        settings.menuBarStyle == 'countdown' ||
            settings.trayIconStyle == 'countdown'
        ? '$mins:$secs'
        : '';

    final status = state == TimerState.breakActive
        ? 'Break active'
        : timerEngine.contextManager.isSmartPauseActive()
        ? 'Paused for Focus or presentation'
        : !timerEngine.contextManager.isWithinWorkingHours()
        ? 'Paused outside working hours'
        : state == TimerState.paused
        ? 'Paused'
        : 'Next break';
    final tooltip = '$status in $mins:$secs';

    final totalSecs = state == TimerState.breakActive
        ? math.max(1, timerEngine.shortBreakDurationSeconds)
        : math.max(1, timerEngine.shortBreakIntervalMinutes * 60);
    trayManagerService.updateProgress(
      state == TimerState.breakActive
          ? 1 - (countdown / totalSecs)
          : timerEngine.workElapsed.inSeconds / totalSecs,
      onBreak: state == TimerState.breakActive,
    );

    if (title != _lastTrayTitle) {
      _lastTrayTitle = title;
      trayManagerService.setTrayTitle(title);
    }
    if (tooltip != _lastTrayTooltip) {
      _lastTrayTooltip = tooltip;
      trayManagerService.setTooltip(tooltip);
    }
  }

  void _setupActivityMonitor() {
    activityMonitor.setIdleThreshold(timerEngine.pauseTimerAfterMinutes);
    activityMonitor.setIdleSampleCallback(timerEngine.reportIdleSeconds);
    activityMonitor.setActivityCallback((isActive) {
      final state = timerEngine.state;

      // Safety net for a stuck sleep flag: handleSystemSleep()/
      // handleSystemWake() are driven purely by native OS notifications
      // (NSWorkspace willSleep/didWake). If a wake notification is ever
      // missed — a false-positive sleep event, a race during a fast
      // sleep/wake cycle, etc. — the tick loop's `systemSleepPaused` guard
      // stays true forever and the timer silently freezes with no state
      // change visible to the user. Real, unambiguous user activity is
      // proof the system is awake, so use it to self-heal.
      if (isActive && timerEngine.systemSleepPaused) {
        _logger.warning(
          'Activity detected while systemSleepPaused was stuck true — '
          'forcing timer wake recovery.',
        );
        timerEngine.handleSystemWake();
      }

      if (isActive &&
          state == TimerState.paused &&
          !timerEngine.stateData.isManuallyPaused) {
        timerEngine.resumeTimers();
      } else if (!isActive && state == TimerState.running) {
        timerEngine.pauseTimers();
        _pauseAutoResumeTimer?.cancel();
        _pauseAutoResumeTimer = Timer(
          Duration(minutes: timerEngine.resetTimerAfterMinutes),
          () {
            if (timerEngine.state == TimerState.paused) {
              timerEngine.resetCycleOnIdle();
              _logger.info(
                'Timer & break cycle reset after ${timerEngine.resetTimerAfterMinutes} min idle',
              );
            }
          },
        );
      }
      eventBus.emit(IdleDetectedEvent(isIdle: !isActive));
    });
    activityMonitor.start();
  }

  void _startUsageTracking() {
    _usageTrackerTimer?.cancel();
    _usageTrackerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (timerEngine.state == TimerState.running) {
        statsService.addUsageMinutes(1);
      }
    });
  }

  void saveState() {
    timerRepository.save(
      timerEngine.stateData,
      shortBreakIntervalMinutes: timerEngine.shortBreakIntervalMinutes,
      shortBreakDurationSeconds: timerEngine.shortBreakDurationSeconds,
      preBreakWarningSeconds: timerEngine.preBreakWarningSeconds,
      longBreakIntervalMinutes: timerEngine.longBreakIntervalMinutes,
      longBreakDurationMinutes: timerEngine.longBreakDurationMinutes,
      pauseTimerAfterMinutes: timerEngine.pauseTimerAfterMinutes,
      resetTimerAfterMinutes: timerEngine.resetTimerAfterMinutes,
    );

    if (settingsRepository.currentSettings.enableSessionResume) {
      sessionStateRepository.saveSession(
        workElapsed: timerEngine.workElapsed,
        totalWorkToday: timerEngine.totalWorkToday,
        postureElapsedSeconds: timerEngine.stateData.postureElapsedSeconds,
        eyeBlinkElapsedSeconds: timerEngine.stateData.eyeBlinkElapsedSeconds,
        isPreBreak: timerEngine.isPreBreak,
        timerState: timerEngine.state.toString().split('.').last,
        longBreakWindowStartedAt:
            timerEngine.stateData.longBreakWindowStartedAt,
      );
    }
  }

  void _restoreState() {
    timerRepository.restore(
      timerEngine.stateData,
      defaultShortBreakIntervalMinutes: timerEngine.shortBreakIntervalMinutes,
      defaultShortBreakDurationSeconds: timerEngine.shortBreakDurationSeconds,
      defaultPreBreakWarningSeconds: timerEngine.preBreakWarningSeconds,
      defaultLongBreakIntervalMinutes: timerEngine.longBreakIntervalMinutes,
      defaultLongBreakDurationMinutes: timerEngine.longBreakDurationMinutes,
      defaultPauseTimerAfterMinutes: timerEngine.pauseTimerAfterMinutes,
      defaultResetTimerAfterMinutes: timerEngine.resetTimerAfterMinutes,
      onSettingsRestored:
          (
            shortInterval,
            shortDuration,
            preWarning,
            longInterval,
            longDuration,
            pauseAfter,
            resetAfter,
          ) {
            timerEngine.shortBreakIntervalMinutes = shortInterval;
            timerEngine.shortBreakDurationSeconds = shortDuration;
            timerEngine.preBreakWarningSeconds = preWarning;
            timerEngine.longBreakIntervalMinutes = longInterval;
            timerEngine.longBreakDurationMinutes = longDuration;
            timerEngine.pauseTimerAfterMinutes = pauseAfter;
            timerEngine.resetTimerAfterMinutes = resetAfter;
          },
    );

    if (settingsRepository.currentSettings.enableSessionResume) {
      final savedSession = sessionStateRepository.getSessionForToday();
      if (savedSession != null) {
        timerEngine.stateData.workElapsed = Duration(
          seconds: savedSession.workElapsedSeconds,
        );
        timerEngine.stateData.totalWorkToday = Duration(
          seconds: savedSession.totalWorkTodaySeconds,
        );
        timerEngine.stateData.postureElapsedSeconds =
            savedSession.postureElapsedSeconds;
        timerEngine.stateData.eyeBlinkElapsedSeconds =
            savedSession.eyeBlinkElapsedSeconds;
        timerEngine.stateData.isPreBreak = savedSession.isPreBreak;
        timerEngine.stateData.longBreakWindowStartedAt =
            savedSession.longBreakWindowStartedAt;
        timerEngine.stateData.countdownSeconds =
            timerEngine.timeUntilNextShortBreak.inSeconds;
        _logger.info(
          'Session restored from today: ${savedSession.workElapsedSeconds}s work elapsed',
        );
      } else {
        timerEngine.stateData.workElapsed = Duration.zero;
        timerEngine.stateData.totalWorkToday = Duration.zero;
        timerEngine.stateData.postureElapsedSeconds = 0;
        timerEngine.stateData.eyeBlinkElapsedSeconds = 0;
        timerEngine.stateData.isPreBreak = false;
        timerEngine.stateData.longBreakWindowStartedAt = null;
        timerEngine.stateData.countdownSeconds =
            timerEngine.timeUntilNextShortBreak.inSeconds;
        _logger.info(
          'New day or no session found. Daily progress reset to zero.',
        );
      }
    } else {
      sessionStateRepository.clearSession();
      timerEngine.stateData.workElapsed = Duration.zero;
      timerEngine.stateData.totalWorkToday = Duration.zero;
      timerEngine.stateData.postureElapsedSeconds = 0;
      timerEngine.stateData.eyeBlinkElapsedSeconds = 0;
      timerEngine.stateData.isPreBreak = false;
      timerEngine.stateData.longBreakWindowStartedAt = null;
      timerEngine.stateData.countdownSeconds =
          timerEngine.timeUntilNextShortBreak.inSeconds;
      _logger.info('Session resume disabled. Started fresh from zero.');
    }

    timerEngine.syncNotifiersFromState();
  }

  void shutdown() {
    _logger.info('Shutting down TimerOrchestrator...');
    timerEngine.pauseTimers(isManual: true);
    saveState();

    if (!settingsRepository.currentSettings.enableSessionResume) {
      sessionStateRepository.clearSession();
    }

    dispose();
  }

  void dispose() {
    _eventSubscription?.cancel();
    _usageTrackerTimer?.cancel();
    _pauseAutoResumeTimer?.cancel();
    _autoSaveTimer?.cancel();
    timerEngine.removeListener(_onTimerEngineChanged);
  }
}
