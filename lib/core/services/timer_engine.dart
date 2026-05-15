import 'dart:async';
import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/services/adaptive_break_service.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_repository.dart';

enum TimerState { running, paused, idle, breakActive }

enum WorkMode { pomodoro, deepWork, flexible, strict }

class TimerEngine extends ChangeNotifier {
  final ActivityMonitor _activityMonitor;
  final NotificationService _notificationService;
  final SettingsRepository _settingsRepository;
  final AdaptiveBreakService? _adaptiveBreakService;
  final AppLogger _logger = AppLogger();

  Timer? _tickTimer;
  Timer? _usageTrackerTimer;

  TimerState _state = TimerState.idle;
  WorkMode _mode = WorkMode.flexible;
  BreakModel? _activeBreak;
  int _countdownSeconds = 0;
  bool _isCompletionState = false;
  bool _isFlashing = false;

  Duration _workElapsed = Duration.zero;
  Duration _totalWorkToday = Duration.zero;
  DateTime? _lastTickTime;

  TimerEngine({
    required ActivityMonitor activityMonitor,
    required NotificationService notificationService,
    required SettingsRepository settingsRepository,
    AdaptiveBreakService? adaptiveBreakService,
  })  : _activityMonitor = activityMonitor,
       _notificationService = notificationService,
       _settingsRepository = settingsRepository,
       _adaptiveBreakService = adaptiveBreakService {
    _loadTimerState();
  }

  TimerState get state => _state;
  WorkMode get mode => _mode;
  BreakModel? get activeBreak => _activeBreak;
  int get countdownSeconds => _countdownSeconds;
  bool get isCompletionState => _isCompletionState;
  bool get isFlashing => _isFlashing;
  Duration get totalWorkToday => _totalWorkToday;

  Duration get timeUntilNextShortBreak {
    final interval = Duration(minutes: _settingsRepository.currentSettings.shortBreakIntervalMinutes);
    final remaining = interval - _workElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canPostpone => true;

  void setWorkMode(WorkMode mode) {
    _mode = mode;
    _logger.info('Work mode changed to: $mode');
    notifyListeners();
  }

  void startTimers() {
    _state = TimerState.running;
    _workElapsed = Duration.zero;
    _lastTickTime = DateTime.now();

    _startTicking();
    _setupActivityMonitor();
    _startUsageTracking();

    _logger.info('Timers started in $_mode mode');
    notifyListeners();
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == TimerState.paused || _state == TimerState.idle) return;

      final now = DateTime.now();
      final delta = now.difference(_lastTickTime ?? now);
      _lastTickTime = now;

      if (_state == TimerState.running) {
        _workElapsed += delta;
        _totalWorkToday += delta;
        _checkBreakConditions();
      } else if (_state == TimerState.breakActive) {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) {
          finishBreak(skipped: false);
        }
      }

      _updateTray();
      notifyListeners();
    });
  }

  void _checkBreakConditions() {
    final interval = Duration(minutes: _settingsRepository.currentSettings.shortBreakIntervalMinutes);
    if (_workElapsed >= interval) {
      _triggerBreak();
    }
  }

  void setFocusMode(bool enabled) {
    notifyListeners();
  }

  void _triggerBreak() {
    _state = TimerState.breakActive;
    _workElapsed = Duration.zero;
    
    final suggestedDuration = _adaptiveBreakService?.getSuggestedBreakDuration() ?? 
        _settingsRepository.currentSettings.shortBreakDurationSeconds;
        
    _countdownSeconds = suggestedDuration;
    
    _activeBreak = BreakModel(
      type: BreakType.short,
      durationSeconds: _countdownSeconds,
      title: 'Rest Time',
      tip: _randomTip(AppConstants.shortBreakTips),
    );

    _notificationService.showBreakStarted(breakTitle: _activeBreak!.title);
    _logger.info('Break triggered: ${_activeBreak!.title}');
  }

  Future<void> finishBreak({required bool skipped}) async {
    if (!skipped) {
      _isCompletionState = true;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));
    }

    _activeBreak = null;
    _isCompletionState = false;
    _state = TimerState.running;
    _lastTickTime = DateTime.now();
    _workElapsed = Duration.zero;

    sl<StatsService>().recordCompletedBreak();
    notifyListeners();
  }

  void updateSettings({
    int? shortIntervalMinutes,
    int? shortDurationSeconds,
    int? longIntervalMinutes,
    int? longDurationSeconds,
  }) {
    notifyListeners();
  }

  void updateMenuStyle(String style) {
    _updateTray();
  }

  void _updateTray() {
    final remaining = _state == TimerState.breakActive 
        ? Duration(seconds: _countdownSeconds)
        : timeUntilNextShortBreak;
    
    final mins = remaining.inMinutes;
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    sl<TrayManagerService>().setTrayTitle('$mins:$secs');
  }

  void _setupActivityMonitor() {
    _activityMonitor.setActivityCallback((isActive) {
      if (isActive && _state == TimerState.paused) {
        resumeTimers();
      } else if (!isActive && _state == TimerState.running) {
        pauseTimers();
      }
    });
    _activityMonitor.start();
  }

  void pauseTimers() {
    if (_state == TimerState.breakActive) return;
    _state = TimerState.paused;
    notifyListeners();
  }

  void resumeTimers() {
    if (_state == TimerState.breakActive) return;
    _state = TimerState.running;
    _lastTickTime = DateTime.now();
    notifyListeners();
  }

  void resetTimers() {
    _workElapsed = Duration.zero;
    _state = TimerState.idle;
    notifyListeners();
  }

  void triggerBreakNow({bool isLong = false}) {
    _triggerBreak();
  }

  void skipNextBreak() {
    _workElapsed = Duration.zero;
    notifyListeners();
  }

  void postponeBreak() {
    _countdownSeconds += 120;
    notifyListeners();
  }

  void saveState() {}

  void _startUsageTracking() {
    _usageTrackerTimer?.cancel();
    _usageTrackerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_state == TimerState.running) {
        sl<StatsService>().addUsageMinutes(1);
      }
    });
  }

  void triggerFlashDemo({required Color color, required String style, required String animation, required double intensity, required int durationMs}) {
    _isFlashing = true;
    notifyListeners();
    Timer(Duration(milliseconds: durationMs), () {
      _isFlashing = false;
      notifyListeners();
    });
  }

  String _randomTip(List<String> tips) {
    final tipsCopy = List<String>.from(tips)..shuffle();
    return tipsCopy.first;
  }

  void _loadTimerState() {}

  @override
  void dispose() {
    _tickTimer?.cancel();
    _usageTrackerTimer?.cancel();
    super.dispose();
  }
}
