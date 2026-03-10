import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/errors/app_exception.dart';
import 'package:standup/core/errors/error_handler.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
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
  Timer? _postureTimer;
  Timer? _blinkTimer;

  TimerState _state = TimerState.idle;
  BreakModel? _activeBreak;
  int _countdownSeconds = 0;
  bool _isCompletionState = false;
  bool _isFlashing = false;
  bool _focusModeEnabled = false;

  // Elapsed tracking for pause/resume
  Duration _shortElapsed = Duration.zero;
  Duration _longElapsed = Duration.zero;
  DateTime? _lastTickTime;

  // Smart adaptation state
  int _consecutiveActivePolls = 0;
  bool _isBreakDelayed = false;
  int _delaySeconds = 0;

  String _menuBarStyle = 'countdown';

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
  bool get isCompletionState => _isCompletionState;
  bool get isFlashing => _isFlashing;
  bool get focusModeEnabled => _focusModeEnabled;

  Duration get shortBreakInterval =>
      Duration(minutes: _shortBreakIntervalMinutes);
  Duration get longBreakInterval =>
      Duration(minutes: _longBreakIntervalMinutes);

  Duration get timeUntilNextShortBreak {
    final interval = Duration(minutes: _shortBreakIntervalMinutes);
    if (_isBreakDelayed) {
      final elapsedSinceDue = _shortElapsed - interval;
      final remainingDelay = Duration(seconds: _delaySeconds) - elapsedSinceDue;
      return remainingDelay.isNegative ? Duration.zero : remainingDelay;
    }
    final remaining = interval - _shortElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get timeUntilNextLongBreak {
    final remaining = longBreakInterval - _longElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void setFocusMode(bool enabled) {
    _focusModeEnabled = enabled;
    notifyListeners();
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

  void updateMenuStyle(String style) {
    _menuBarStyle = style;
    _updateTrayCountdown();
    notifyListeners();
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
        _startPeriodicReminders();

        _logger.info('Timers started');
        notifyListeners();
      },
      errorType: ErrorType.timer,
    );
  }

  bool _hasTriggeredPreBreakFlash = false;

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

      _updateTrayCountdown();

      final shortInterval = Duration(minutes: _shortBreakIntervalMinutes);
      
      // Check if 30s before short break
      if (!_hasTriggeredPreBreakFlash && 
          _shortElapsed >= shortInterval - const Duration(seconds: 30)) {
        _triggerFlash();
        _hasTriggeredPreBreakFlash = true;
      }

      // Check if short break is due
      if (_shortElapsed >= shortInterval) {
        if (_shouldDelayBreak()) {
          _delayBreak();
        } else if (!_isBreakDelayed ||
            (_shortElapsed >=
                shortInterval + Duration(seconds: _delaySeconds))) {
          _triggerShortBreak();
          _hasTriggeredPreBreakFlash = false;
        }
      }

      // Check if long break is due
      if (_longElapsed >= Duration(minutes: _longBreakIntervalMinutes)) {
        _triggerLongBreak();
      }
    });
  }

  bool _shouldDelayBreak() {
    // If user has been extremely active (no idle for 10+ mins), delay slightly
    return _consecutiveActivePolls > 20 && !_isBreakDelayed;
  }

  void _delayBreak() {
    _isBreakDelayed = true;
    _delaySeconds = 120; // Delay by 2 mins
    _logger.info('Break delayed due to intense activity');
  }

  void _updateTrayCountdown() {
    if (_state == TimerState.paused) {
      sl<TrayManagerService>().setTrayTitle('  [ PAUSED ]  ');
      return;
    }
    
    if (_state != TimerState.running && _state != TimerState.breakActive) {
      sl<TrayManagerService>().setTrayTitle('');
      return;
    }

    final remaining = _state == TimerState.breakActive 
        ? Duration(seconds: _countdownSeconds)
        : timeUntilNextShortBreak;
        
    final mins = remaining.inMinutes;
    final secs = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    switch (_menuBarStyle) {
      case 'countdown':
        sl<TrayManagerService>().setTrayTitle('  [ $mins:$secs ]  ');
        break;
      case 'progress':
        final total = _state == TimerState.breakActive 
            ? (_activeBreak?.durationSeconds ?? 60)
            : (_shortBreakIntervalMinutes * 60);
        final done = total - remaining.inSeconds;
        final progress = (done / total * 5).clamp(0, 5).round();
        // Use Pill-like characters for a high-end feel
        final bars = '▰' * progress + '▱' * (5 - progress);
        sl<TrayManagerService>().setTrayTitle('  [ $bars ]  ');
        break;
      case 'icon':
        final total = _state == TimerState.breakActive 
            ? (_activeBreak?.durationSeconds ?? 60)
            : (_shortBreakIntervalMinutes * 60);
        final percent = (remaining.inSeconds / total);
        String icon = '○';
        if (percent > 0.75) icon = '◔';
        else if (percent > 0.5) icon = '◑';
        else if (percent > 0.25) icon = '◕';
        else icon = '●';
        sl<TrayManagerService>().setTrayTitle('  [ $icon ${mins}m ]  ');
        break;
      case 'focusdot':
        if (_state == TimerState.breakActive) {
          sl<TrayManagerService>().setTrayTitle('  [ ○ Break ]  ');
        } else {
          sl<TrayManagerService>().setTrayTitle('  [ ● Focus ]  ');
        }
        break;
      default:
        sl<TrayManagerService>().setTrayTitle('');
    }
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
    _isBreakDelayed = false;
    _delaySeconds = 0;
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

  void _startPeriodicReminders() {
    _postureTimer?.cancel();
    _blinkTimer?.cancel();

    // Posture reminder every 15 minutes
    _postureTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (_state == TimerState.running) {
        _notificationService.showPostureReminder();
      }
    });

    // Blink reminder every 10 minutes
    _blinkTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (_state == TimerState.running) {
        _notificationService.showBlinkReminder();
      }
    });
  }

  void _triggerBreak(BreakModel breakModel) {
    _state = TimerState.breakActive;
    _activeBreak = breakModel;
    _countdownSeconds = breakModel.durationSeconds;

    // Trigger flash instead of / in addition to notification
    _triggerFlash();
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

  void _triggerFlash() {
    _isFlashing = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 1500), () {
      _isFlashing = false;
      notifyListeners();
    });
  }

  Future<void> finishBreak({required bool skipped}) async {
    _countdownTimer?.cancel();
    
    if (!skipped) {
      _isCompletionState = true;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));
      _notificationService.showBreakFinished();
    }

    _activeBreak = null;
    _isCompletionState = false;
    _countdownSeconds = 0;
    _state = TimerState.running;
    _lastTickTime = DateTime.now();

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

      if (isActive) {
        _consecutiveActivePolls++;
      } else {
        _consecutiveActivePolls = 0;
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
