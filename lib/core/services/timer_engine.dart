import 'dart:async';
import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/services/overlay_window_service.dart';
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
  int _shortBreaksSinceLongBreak = 0;
  bool _isCompletionState = false;
  bool _isFlashing = false;
  bool _isPreBreak = false;

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
  bool get isPreBreak => _isPreBreak;
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
    _isPreBreak = false;
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
    // Clock Out Detection
    if (_settingsRepository.currentSettings.enableClockOut) {
      final clockOutTimeStr = _settingsRepository.currentSettings.clockOutTime;
      final parts = clockOutTimeStr.split(':');
      if (parts.length == 2) {
        final clockOutHour = int.tryParse(parts[0]) ?? 17;
        final clockOutMin = int.tryParse(parts[1]) ?? 0;
        final now = DateTime.now();
        
        if (now.hour > clockOutHour || (now.hour == clockOutHour && now.minute >= clockOutMin)) {
          if (_state == TimerState.running && !sl<OverlayWindowService>().isOverlayVisible) {
             _triggerClockOut();
             return;
          }
        }
      }
    }

    final interval = Duration(minutes: _settingsRepository.currentSettings.shortBreakIntervalMinutes);
    final remaining = interval - _workElapsed;
    
    // 20 second warning
    if (remaining <= const Duration(seconds: 20) && !_isPreBreak) {
      _isPreBreak = true;
      _logger.info('Pre-break warning triggered');
      notifyListeners();
    }
    
    if (_workElapsed >= interval) {
      _isPreBreak = false;
      _triggerBreak();
    }
  }

  void _triggerClockOut() {
    _state = TimerState.breakActive;
    _workElapsed = Duration.zero;
    _countdownSeconds = 3600; // 1 hour break block basically
    
    _activeBreak = BreakModel(
      type: BreakType.long,
      durationSeconds: _countdownSeconds,
      title: 'CLOCK OUT',
      tip: 'Your workday is over. Time to step away and live your life. No more "just five more minutes".',
    );

    _notificationService.showBreakStarted(breakTitle: 'Time to Clock Out!');
    _logger.info('Clock out triggered');
    notifyListeners();
  }

  void setFocusMode(bool enabled) {
    notifyListeners();
  }

  void _triggerBreak() {
    _state = TimerState.breakActive;
    _workElapsed = Duration.zero;
    
    final settings = _settingsRepository.currentSettings;
    
    // Every 4th break is a long break
    bool isLongBreak = _shortBreaksSinceLongBreak >= 3;
    
    if (isLongBreak) {
      _countdownSeconds = settings.longBreakDurationMinutes * 60;
      _activeBreak = BreakModel(
        type: BreakType.long,
        durationSeconds: _countdownSeconds,
        title: 'LONG BREAK',
        tip: 'Time to stand, stretch, and mentally reset. Step away from your desk.',
      );
      _shortBreaksSinceLongBreak = 0;
    } else {
      final suggestedDuration = _adaptiveBreakService?.getSuggestedBreakDuration() ?? 
          settings.shortBreakDurationSeconds;
          
      _countdownSeconds = suggestedDuration;
      _activeBreak = BreakModel(
        type: BreakType.short,
        durationSeconds: _countdownSeconds,
        title: 'Rest Time',
        tip: _randomTip(AppConstants.shortBreakTips),
      );
      _shortBreaksSinceLongBreak++;
    }

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
    _isPreBreak = false;
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
    _isPreBreak = false;
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
