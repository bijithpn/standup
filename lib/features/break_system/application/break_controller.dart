import 'package:flutter/foundation.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:standup/features/statistics/stats_service.dart';

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
  bool get isPaused => _timerEngine.state == TimerState.paused;
  bool get isBreakActive => _timerEngine.state == TimerState.breakActive;

  void initialize() {
    _applySettings();
    _timerEngine.startTimers();
  }

  void _applySettings() {
    final settings = _settingsRepo.currentSettings;
    _timerEngine.updateSettings(
      shortIntervalMinutes: settings.shortBreakIntervalMinutes,
      shortDurationSeconds: settings.shortBreakDurationSeconds,
      longIntervalMinutes: settings.longBreakIntervalMinutes,
      longDurationSeconds: settings.longBreakDurationMinutes * 60,
    );
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

  void onBreakCompleted() {
    _statsService.recordCompletedBreak();
  }

  void refreshSettings() {
    _applySettings();
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
