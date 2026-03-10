import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/errors/app_exception.dart';
import 'package:standup/core/errors/error_handler.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/features/break_system/domain/break_model.dart';

enum TimerState { running, paused, idle, breakActive }

class TimerEngine extends ChangeNotifier {
  final ActivityMonitor _activityMonitor;
  final NotificationService _notificationService;
  final ErrorHandler _errorHandler = ErrorHandler();
  final AppLogger _logger = AppLogger();

  Timer? _shortBreakTimer;
  Timer? _longBreakTimer;
  Timer? _countdownTimer;

  TimerState _state = TimerState.idle;
  BreakModel? _activeBreak;
  int _countdownSeconds = 0;

  // Elapsed tracking for pause/resume
  Duration _shortElapsed = Duration.zero;
  Duration _longElapsed = Duration.zero;
  DateTime? _lastTickTime;

  int _shortBreakIntervalMinutes = AppConstants.defaultShortBreakIntervalMinutes;
  int _shortBreakDurationSeconds = AppConstants.defaultShortBreakDurationSeconds;
  int _longBreakIntervalMinutes = AppConstants.defaultLongBreakIntervalMinutes;
  int _longBreakDurationSeconds =
      AppConstants.defaultLongBreakDurationMinutes * 60;

  VoidCallback? onBreakTriggered;

  TimerEngine({
    required ActivityMonitor activityMonitor,
    required NotificationService notificationService,
  })  : _activityMonitor = activityMonitor,
        _notificationService = notificationService;

  TimerState get state => _state;
  BreakModel? get activeBreak => _activeBreak;
  int get countdownSeconds => _countdownSeconds;

  Duration get shortBreakInterval =>
      Duration(minutes: _shortBreakIntervalMinutes);
  Duration get longBreakInterval =>
      Duration(minutes: _longBreakIntervalMinutes);

  Duration get timeUntilNextShortBreak {
    final remaining = shortBreakInterval - _shortElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get timeUntilNextLongBreak {
    final remaining = longBreakInterval - _longElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void updateSettings({
    int? shortIntervalMinutes,
    int? shortDurationSeconds,
    int? longIntervalMinutes,
    int? longDurationSeconds,
  }) {
    _shortBreakIntervalMinutes =
        shortIntervalMinutes ?? _shortBreakIntervalMinutes;
    _shortBreakDurationSeconds =
        shortDurationSeconds ?? _shortBreakDurationSeconds;
    _longBreakIntervalMinutes =
        longIntervalMinutes ?? _longBreakIntervalMinutes;
    _longBreakDurationSeconds =
        longDurationSeconds ?? _longBreakDurationSeconds;
  }

  void startTimers() {
    _errorHandler.guard(
      action: () async {
        _state = TimerState.running;
        _shortElapsed = Duration.zero;
        _longElapsed = Duration.zero;
        _lastTickTime = DateTime.now();

        _startTicking();
        _setupActivityMonitor();

        _logger.info('Timers started');
        notifyListeners();
      },
      errorType: ErrorType.timer,
    );
  }

  void _startTicking() {
    _shortBreakTimer?.cancel();
    _longBreakTimer?.cancel();

    // Tick every second for accurate tracking
    _shortBreakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state != TimerState.running) return;

      final now = DateTime.now();
      final delta = now.difference(_lastTickTime ?? now);
      _lastTickTime = now;

      _shortElapsed += delta;
      _longElapsed += delta;

      // Check if short break is due
      if (_shortElapsed >= Duration(minutes: _shortBreakIntervalMinutes)) {
        _triggerShortBreak();
      }

      // Check if long break is due
      if (_longElapsed >= Duration(minutes: _longBreakIntervalMinutes)) {
        _triggerLongBreak();
      }
    });
  }

  void pauseTimers() {
    if (_state == TimerState.breakActive) return;

    _state = TimerState.paused;
    _lastTickTime = null;
    _logger.info('Timers paused');
    notifyListeners();
  }

  void resumeTimers() {
    if (_state == TimerState.breakActive) return;

    _state = TimerState.running;
    _lastTickTime = DateTime.now();
    _logger.info('Timers resumed');
    notifyListeners();
  }

  void resetTimers() {
    _shortBreakTimer?.cancel();
    _longBreakTimer?.cancel();
    _countdownTimer?.cancel();

    _shortElapsed = Duration.zero;
    _longElapsed = Duration.zero;
    _state = TimerState.idle;
    _activeBreak = null;
    _countdownSeconds = 0;

    _logger.info('Timers reset');
    notifyListeners();
  }

  void skipNextBreak() {
    // Reset the shorter timer to push the next break forward
    _shortElapsed = Duration.zero;
    _logger.info('Next short break skipped');
    notifyListeners();
  }

  void triggerBreakNow({bool isLong = false}) {
    if (isLong) {
      _triggerLongBreak();
    } else {
      _triggerShortBreak();
    }
  }

  void _triggerShortBreak() {
    _shortElapsed = Duration.zero;
    _triggerBreak(
      BreakModel(
        type: BreakType.short,
        durationSeconds: _shortBreakDurationSeconds,
        title: 'Short Break',
        tip: _randomTip(AppConstants.shortBreakTips),
      ),
    );
  }

  void _triggerLongBreak() {
    _longElapsed = Duration.zero;
    _shortElapsed = Duration.zero;
    _triggerBreak(
      BreakModel(
        type: BreakType.long,
        durationSeconds: _longBreakDurationSeconds,
        title: 'Long Break',
        tip: _randomTip(AppConstants.longBreakTips),
      ),
    );
  }

  void _triggerBreak(BreakModel breakModel) {
    _state = TimerState.breakActive;
    _activeBreak = breakModel;
    _countdownSeconds = breakModel.durationSeconds;

    _notificationService.showBreakStarted(breakTitle: breakModel.title);
    onBreakTriggered?.call();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _countdownSeconds--;
      notifyListeners();

      if (_countdownSeconds <= 0) {
        finishBreak(skipped: false);
      }
    });

    _logger.info('Break triggered: ${breakModel.title}');
    notifyListeners();
  }

  void finishBreak({required bool skipped}) {
    _countdownTimer?.cancel();
    _activeBreak = null;
    _countdownSeconds = 0;
    _state = TimerState.running;
    _lastTickTime = DateTime.now();

    if (!skipped) {
      _notificationService.showBreakFinished();
    }

    _logger.info(skipped ? 'Break skipped' : 'Break completed');
    notifyListeners();
  }

  void _setupActivityMonitor() {
    _activityMonitor.setActivityCallback((isActive) {
      if (isActive && _state == TimerState.paused) {
        resumeTimers();
      } else if (!isActive && _state == TimerState.running) {
        pauseTimers();
      }
    });
  }

  String _randomTip(List<String> tips) {
    tips.shuffle();
    return tips.first;
  }

  @override
  void dispose() {
    _shortBreakTimer?.cancel();
    _longBreakTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
