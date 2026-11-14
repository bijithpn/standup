import 'package:breakmate/features/settings/settings_model.dart';
import 'package:clock/clock.dart';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/core/services/health_reminder_messages.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/timer_repository.dart';

import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/daily_insight_notifier_service.dart';
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

/// Glue between TimerEngine and the rest of the app: reacts to engine events (IPC to overlays, tray, notifications, stats), wires idle detection and persists state.
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
  Timer? _healthReminderContextTimer;
  Timer? _companionCueTimer;

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

  /// Restores saved state, applies cold-boot recovery, then subscribes to engine events and starts idle/usage tracking.
  void initialize() {
    _logger.info('Initializing TimerOrchestrator...');

    _restoreState();

    if (timerEngine.state == TimerState.running &&
        timerEngine.stateData.lastTickTime != null) {
      final lastTick = timerEngine.stateData.lastTickTime!;
      final durationAway = DateTime.now().difference(lastTick);
      // Away longer than one work interval counts as a rest, so start a fresh session instead of resuming.
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

    // Periodic save so a crash loses at most ~10s of progress.
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (timerEngine.state == TimerState.running ||
          timerEngine.state == TimerState.breakActive) {
        saveState();
      }
    });
  }

  // Shows the cursor countdown 15s before a break and hides it otherwise.
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

  // Single dispatch point for engine events; each handler fans out to IPC, tray, notifications and stats.
  void _handleEvent(AppEvent event) {
    _logger.info('Received event in Orchestrator: $event');

    if (event is TimerStateChangedEvent) {
      _dispatchTimerStateIpc(event);
      saveState();
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

  // Mirrors timer state to other windows (overlay, companion) which cannot read the engine directly.
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

  // Keeps the display awake and notifies overlays/tray; wind-down also triggers the end-of-day summary.
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

    if (timerEngine.state == TimerState.windDown) {
      sl<DailyInsightNotifierService>().showEndOfDaySummary();
    }
    if (event.isLongBreak) {
      notificationService.showClockOutReminder();
    } else {
      notificationService.showBreakStarted(breakTitle: event.title);
    }

    saveState();
  }

  // Records history/stats; on completion also feeds AdaptiveBreakService and applies its suggested next interval.
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
      // Let the "Well Done" completion screen show before recording.
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

  /// Plays the sound, then shows the reminder via the companion if enabled, else a flash reminder (macOS) or quick overlay window.
  void _handleHealthReminder(HealthReminderEvent event) {
    if (timerEngine.contextManager.shouldSuppressHealthReminders) return;
    final settings = settingsRepository.currentSettings;

    if (settings.soundEnabled) {
      final tone = HealthReminderMessages.isCustom(event.reminderType)
          ? 'custom'
          : event.reminderType;
      final player = AudioPlayer();
      player.onPlayerComplete.first.then((_) => player.dispose());
      player
          .play(AssetSource('audio/reminder_$tone.wav'), volume: 0.5)
          .catchError((_) => player.dispose());
    }

    if (settings.companionEnabled &&
        !HealthReminderMessages.isCustom(event.reminderType)) {
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
      if (settings.experience.companionEscalates) {
        final cueAt = clock.now();
        _companionCueTimer?.cancel();
        _companionCueTimer = Timer(AppConstants.companionCueGrace, () {
          final rested = timerEngine.lastRestAt?.isAfter(cueAt) ?? false;
          if (rested ||
              timerEngine.contextManager.shouldSuppressHealthReminders) {
            return;
          }
          _showReminderOverlay(event, settingsRepository.currentSettings);
        });
      }
      return;
    }

    _showReminderOverlay(event, settings);
  }

  void _showReminderOverlay(HealthReminderEvent event, SettingsModel settings) {
    // macOS uses the native flash reminder only; other platforms also show the quick overlay window.
    final macos = Platform.isMacOS;
    NativeEnhancementsService.instance.triggerFlashReminder(
      text: HealthReminderMessages.text(event.reminderType),
      reminderType: event.reminderType,

      durationMs: macos
          ? AppConstants.healthReminderDismissDuration.inMilliseconds
          : 250,
      opacity: macos ? 0.2 : 0.35,
      dismissOnMouseMove: settings.dismissReminderOnMouseMove,
      textScale: settings.experience.textScale,
      highContrast: settings.experience.highContrast,
      reduceMotion: settings.reduceMotion || !settings.enableAnimations,
    );
    _healthReminderContextTimer?.cancel();
    final shownAt = DateTime.now();
    _healthReminderContextTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (timer) {
        if (timerEngine.contextManager.shouldSuppressHealthReminders) {
          timer.cancel();
          NativeEnhancementsService.instance.dismissHealthReminder();
          if (!macos &&
              sl<OverlayWindowService>().currentOverlayType ==
                  OverlayType.quickReminder) {
            sl<OverlayWindowService>().hideOverlay();
          }
        } else if (DateTime.now().difference(shownAt) >=
            AppConstants.healthReminderDismissDuration) {
          timer.cancel();
        }
      },
    );
    if (macos) return;

    sl<OverlayWindowService>().showOverlay(
      type: OverlayType.quickReminder,
      builder: (_) => const SizedBox.shrink(),
      reminderType: event.reminderType,

      showOnAllDisplays: false,
      overlayData: {
        'overlayType': 'quickReminder',
        'reminderType': event.reminderType,
        'durationSeconds': AppConstants.healthReminderDismissDuration.inSeconds,
        'remainingSeconds':
            AppConstants.healthReminderDismissDuration.inSeconds,

        'allowFullPoster': allowFullPosterReminder(
          detectMeetings: settings.detectMeetings,
          calendarMeetingActive: sl<MeetingDetectionService>().isMeetingActive,
          detectVideoCalls: settings.detectVideoCalls,
          videoCallActive: sl<SmartDetectionService>().isVideoCallActive,
          presenting: sl<PresentationDetectionService>().isPresenting,
        ),
      },
    );

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

  // Pushes countdown title, tooltip and progress to the tray; title/tooltip are only sent when changed.
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

  // Idle: discard idle time and pause; return: resume unless manually paused. A long idle also resets the break cycle.
  void _setupActivityMonitor() {
    activityMonitor.setIdleThreshold(timerEngine.pauseTimerAfterMinutes);
    activityMonitor.setIdleSampleCallback(timerEngine.reportIdleSeconds);
    activityMonitor.setActivityCallback((isActive) {
      final state = timerEngine.state;

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
        timerEngine.discardIdleTime(
          Duration(seconds: activityMonitor.lastIdleSeconds.round()),
        );
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

  /// Persists engine state, plus the daily session snapshot when session resume is enabled.
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

  // Restores engine state and today's session; a new day or disabled resume starts from zero.
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

  /// Called on app quit: pauses, saves and disposes.
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
    _healthReminderContextTimer?.cancel();
    _companionCueTimer?.cancel();
    timerEngine.removeListener(_onTimerEngineChanged);
  }
}
