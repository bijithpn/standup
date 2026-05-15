import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/settings/break_profile.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/analytics/stats_service.dart';

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
    final settings = _settingsRepo.currentSettings;

    if (_timerEngine.state == TimerState.breakActive && !overlayService.isOverlayVisible) {
      // Trigger global break overlay
      overlayService.showOverlay(
        type: OverlayType.breakScreen,
        builder: (context) => const SizedBox.shrink(), // Stack in app.dart handles content
        strictMode: settings.strictMode,
      );
    } else if (_timerEngine.state != TimerState.breakActive && 
               overlayService.currentOverlayType == OverlayType.breakScreen) {
      overlayService.hideOverlay();
    }

    if (_timerEngine.isFlashing && !overlayService.isOverlayVisible) {
      // Trigger global flash reminder
      overlayService.showOverlay(
        type: OverlayType.flashNotification,
        builder: (context) => const SizedBox.shrink(),
        strictMode: false,
      );
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
    );
    _timerEngine.updateMenuStyle(settings.menuBarStyle);
    _timerEngine.setFocusMode(settings.focusModeEnabled);
  }

  void togglePause() {
    if (isPaused) {
      _timerEngine.resumeTimers();
    } else {
      _timerEngine.pauseTimers();
    }
    notifyListeners();
  }

  void takeBreakNow() {
    _timerEngine.triggerBreakNow();
  }

  void skipNextBreak() {
    _timerEngine.skipNextBreak();
  }

  void skipCurrentBreak() {
    if (!_settingsRepo.currentSettings.strictMode) {
      _statsService.recordSkippedBreak();
      _timerEngine.finishBreak(skipped: true);
    }
  }

  void postponeCurrentBreak() {
    if (_timerEngine.canPostpone && !_settingsRepo.currentSettings.strictMode) {
      _timerEngine.postponeBreak();
    }
  }

  void onBreakCompleted() {
    _statsService.recordCompletedBreak();
    // Force save timer state to persist the completed break
    _timerEngine.saveState();
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
