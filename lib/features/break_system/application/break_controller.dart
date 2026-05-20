import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/features/settings/break_profile.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/break_system/application/strict_mode_controller.dart';

class BreakController extends ChangeNotifier {
  final TimerEngine _timerEngine;
  final SettingsRepository _settingsRepo;
  final StatsService _statsService;

  BreakController({
    required TimerEngine timerEngine,
    required SettingsRepository settingsRepo,
    required StatsService statsService,
  })  : _timerEngine = timerEngine,
        _settingsRepo = settingsRepo,
        _statsService = statsService {
    _timerEngine.addListener(_onTimerChanged);
  }

  TimerEngine get timerEngine => _timerEngine;
  SettingsRepository get settingsRepository => _settingsRepo;
  bool get isPaused => _timerEngine.state == TimerState.paused;
  bool get isBreakActive => _timerEngine.state == TimerState.breakActive;

  void initialize() {
    _applySettings();
    _timerEngine.startTimers();
    _statsService.load();
    
    // Listen for timer events to trigger global overlays
    _timerEngine.addListener(_handleGlobalOverlays);
  }

  void _handleGlobalOverlays() {
    final overlayService = sl<OverlayWindowService>();
    final strictModeController = sl<StrictModeController>();
    final settings = _settingsRepo.currentSettings;

    bool shouldShowBreak = _timerEngine.state == TimerState.breakActive;
    bool shouldShowWarning = _timerEngine.isPreBreak;

    if (shouldShowBreak) {
      final breakInfo = _timerEngine.activeBreak;
      
      // Attempt to enable native strict mode if requested
      if (settings.strictMode && !strictModeController.isStrictModeActive) {
        strictModeController.enableStrictMode();
      }

      if (overlayService.currentOverlayType != OverlayType.breakScreen) {
        if (strictModeController.isInMeeting) {
          debugPrint('Auto-postponing break due to active meeting.');
          _timerEngine.postponeBreak();
          return;
        }
        overlayService.showOverlay(
          type: OverlayType.breakScreen,
          builder: (context) => const SizedBox.shrink(),
          strictMode: settings.strictMode,
        );
      }
      
      // Update all overlay engines with the current timer state
      if (breakInfo != null) {
        MacOSBridge.updateOverlayData({
          'title': breakInfo.title,
          'durationSeconds': breakInfo.durationSeconds,
          'remainingSeconds': _timerEngine.countdownSeconds,
          'strictMode': settings.strictMode,
        });
      }
    } else if (shouldShowWarning) {
      if (overlayService.currentOverlayType != OverlayType.preBreakWarning) {
        overlayService.showOverlay(
          type: OverlayType.preBreakWarning,
          builder: (context) => const SizedBox.shrink(),
        );
      }
    } else if (overlayService.isOverlayVisible && 
               (overlayService.currentOverlayType == OverlayType.breakScreen ||
                overlayService.currentOverlayType == OverlayType.preBreakWarning)) {
      if (strictModeController.isStrictModeActive) {
        strictModeController.disableStrictMode();
      }
      overlayService.hideOverlay();
    }

    notifyListeners();
  }

  void _applySettings() {
    final settings = _settingsRepo.currentSettings;
    _timerEngine.updateSettings(
      shortIntervalMinutes: settings.shortBreakIntervalMinutes,
      shortDurationSeconds: settings.shortBreakDurationSeconds,
      longIntervalMinutes: settings.longBreakIntervalMinutes,
      longDurationSeconds: settings.longBreakDurationMinutes * 60,
      pauseAfterMinutes: settings.pauseTimerAfterMinutes,
      resetAfterMinutes: settings.resetTimerAfterMinutes,
    );
    _timerEngine.updateMenuStyle(settings.menuBarStyle);
    _timerEngine.setFocusMode(settings.focusModeEnabled);
    sl<NotificationService>().setNotificationsEnabled(settings.notificationsEnabled);
    sl<NotificationService>().setSoundEnabled(settings.soundEnabled);
    sl<TrayManagerService>().setIconModeFromStyle(settings.trayIconStyle);
  }

  void togglePause() {
    if (isPaused) {
      _timerEngine.resumeTimers();
    } else {
      _timerEngine.pauseTimers();
    }
    sl<TrayManagerService>().updatePauseState(isPaused);
    notifyListeners();
  }

  void takeBreakNow() {
    _timerEngine.triggerBreakNow();
    sl<TrayManagerService>().setBreakActive(true);
  }

  void skipNextBreak() {
    _timerEngine.skipNextBreak();
  }

  void skipCurrentBreak() {
    if (!_settingsRepo.currentSettings.strictMode) {
      _timerEngine.finishBreak(skipped: true);
      sl<TrayManagerService>().setBreakActive(false);
    }
  }

  void postponeCurrentBreak() {
    if (_timerEngine.canPostpone && !_settingsRepo.currentSettings.strictMode) {
      _timerEngine.postponeBreak();
    }
  }

  void completeCurrentBreak() {
    _timerEngine.finishBreak(skipped: false);
    sl<TrayManagerService>().setBreakActive(false);
  }

  void onBreakCompleted() {
    // Force save timer state to persist the completed break
    _timerEngine.saveState();
    sl<TrayManagerService>().setBreakActive(false);
  }

  void refreshSettings() {
    _applySettings();
  }

  void changeProfile(BreakProfile profile) {
    final updated = _settingsRepo.currentSettings.copyWith(
      selectedProfileId: profile.id,
      shortBreakIntervalMinutes: profile.shortIntervalMinutes,
      shortBreakDurationSeconds: profile.shortDurationSeconds,
      longBreakIntervalMinutes: profile.longIntervalMinutes,
      longBreakDurationMinutes: profile.longDurationMinutes,
    );
    _settingsRepo.save(updated);
    _applySettings();
    notifyListeners();
  }

  void _onTimerChanged() {
    // Sync tray pause state if it changed externally (e.g. idle detection)
    sl<TrayManagerService>().updatePauseState(isPaused);

    // Track completed breaks when countdown reaches zero naturally
    if (_timerEngine.state == TimerState.running &&
        _timerEngine.activeBreak == null) {
      // Break just finished normally — already handled in finishBreak
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timerEngine.removeListener(_onTimerChanged);
    super.dispose();
  }
}
