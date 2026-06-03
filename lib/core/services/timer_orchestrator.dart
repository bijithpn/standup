import 'dart:async';
import 'package:flutter/material.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/timer_repository.dart';

import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/app/dependency_injection.dart';

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

    // 1. Restore State
    _restoreState();

    // 2. Start listening to EventBus
    _eventSubscription = eventBus.stream.listen(_handleEvent);

    // 3. Listen to high-frequency notifiers for tray updates
    timerEngine.countdownNotifier.addListener(_updateTray);
    timerEngine.workElapsedNotifier.addListener(_updateTray);

    // Listen for low-frequency changes (state, mode, etc.) for state saving
    timerEngine.addListener(_onTimerEngineChanged);

    // 4. Setup ActivityMonitor callback
    _setupActivityMonitor();

    // 5. Start usage tracking
    _startUsageTracking();

    // 6. Perform initial update of the tray to reflect restored state immediately
    _updateTray();

    // 7. Start periodic state auto-saving for crash/restart resilience (every 10 seconds)
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (timerEngine.state == TimerState.running ||
          timerEngine.state == TimerState.breakActive) {
        saveState();
      }
    });
  }

  void _onTimerEngineChanged() {
    _updateTray();
  }

  void _handleEvent(AppEvent event) {
    _logger.info('Received event in Orchestrator: $event');

    // Handle IPC and side effects
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
      notificationService.showBreakReminder(isLong: event.isLongBreak);
    }

    saveState();
  }

  Future<void> _handleBreakEnded(BreakEndedEvent event) async {
    IpcBridge.instance.dispatch(BreakEndedIpcEvent(skipped: event.skipped));

    trayManagerService.setBreakActive(false);

    if (event.skipped) {
      statsService.recordSkippedBreak();
    } else {
      // Completed break
      await Future.delayed(const Duration(seconds: 2));
      statsService.recordCompletedBreak();

      if (!sl<OverlayWindowService>().isOverlayVisible) {
        await notificationService.showBreakFinished();
      }

      // Record actual session duration
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

      // Fetch suggested next break interval
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
      final interactionType = event.reminderType == 'posture'
          ? 'stretch'
          : 'blink';
      eventBus.emit(
        CompanionInteractionEvent(interactionType: interactionType),
      );

      statsService.recordWellnessAction();

      IpcBridge.instance.dispatch(
        CompanionInteractionIpcEvent(interactionType: interactionType),
      );
      return;
    }

    if (event.displayType == 'native') {
      if (event.reminderType == 'posture') {
        notificationService.showPostureReminder();
      } else {
        notificationService.showEyeRestReminder();
      }
    } else {
      sl<OverlayWindowService>().showOverlay(
        type: OverlayType.quickReminder,
        builder: (_) => const SizedBox.shrink(),
        reminderType: event.reminderType,
      );

      Future.delayed(const Duration(seconds: 5), () {
        if (sl<OverlayWindowService>().currentOverlayType ==
            OverlayType.quickReminder) {
          sl<OverlayWindowService>().hideOverlay();
        }
      });
    }
  }

  void _handleBreakPostponed(BreakPostponedEvent event) {
    // Notify IPC or perform postponement side effects if needed
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
        ? 'Paused for meeting or Focus'
        : !timerEngine.contextManager.isWithinWorkingHours()
        ? 'Paused outside working hours'
        : state == TimerState.paused
        ? 'Paused'
        : 'Next break';
    final tooltip = '$status in $mins:$secs';

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
    activityMonitor.setActivityCallback((isActive) {
      final state = timerEngine.state;
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
              timerEngine.stateData.workElapsed = Duration.zero;
              _logger.info(
                'Timer reset after ${timerEngine.resetTimerAfterMinutes} min idle',
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

    // Save session state if feature is enabled
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

    // Restore session state if feature is enabled
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
        _logger.info(
          'Session restored from today: ${savedSession.workElapsedSeconds}s work elapsed',
        );
      } else {
        // New day or no saved session exists - reset all progress to zero
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
      // Feature disabled - clear any saved session and start fresh from zero
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

    // Synchronize all value notifiers (visuals/GUI, tray) with the restored state
    timerEngine.syncNotifiersFromState();
  }

  void shutdown() {
    _logger.info('Shutting down TimerOrchestrator...');
    timerEngine.pauseTimers(isManual: true);
    saveState();

    // Clear session on shutdown if feature is disabled
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
