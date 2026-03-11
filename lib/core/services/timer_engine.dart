import 'dart:async';
import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/errors/app_exception.dart';
import 'package:standup/core/errors/error_handler.dart';
import 'package:standup/core/services/activity_monitor.dart';
import 'package:standup/core/services/notification_service.dart';
import 'package:standup/core/services/storage_service.dart';
import 'package:standup/features/statistics/stats_service.dart';
import 'package:standup/features/menu_bar/tray_manager_service.dart';
import 'package:standup/core/utils/logger.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/core/services/adaptive_break_service.dart';
import 'package:standup/features/settings/settings_repository.dart';

enum TimerState { running, paused, idle, breakActive }

class TimerEngine extends ChangeNotifier {
  final ActivityMonitor _activityMonitor;
  final NotificationService _notificationService;
  final AdaptiveBreakService? _adaptiveBreakService;
  final SettingsRepository _settingsRepository;
  final ErrorHandler _errorHandler = ErrorHandler();
  final AppLogger _logger = AppLogger();

  Timer? _shortBreakTimer;
  Timer? _longBreakTimer;
  Timer? _countdownTimer;
  Timer? _postureTimer;
  Timer? _blinkTimer;
  Timer? _usageTrackerTimer;

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
  DateTime? _lastSaveTime;

  // Smart adaptation state
  int _consecutiveActivePolls = 0;
  bool _isBreakDelayed = false;
  int _delaySeconds = 0;
  int _postponeCount = 0;
  static const int maxPostponeCount = 3;
  static const int postponeDurationSeconds = 120; // 2 minutes per postpone

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
    AdaptiveBreakService? adaptiveBreakService,
    required SettingsRepository settingsRepository,
  })  : _activityMonitor = activityMonitor,
       _notificationService = notificationService,
       _adaptiveBreakService = adaptiveBreakService,
       _settingsRepository = settingsRepository {
    _loadTimerState();
  }

  TimerState get state => _state;
  BreakModel? get activeBreak => _activeBreak;
  int get countdownSeconds => _countdownSeconds;
  bool get isCompletionState => _isCompletionState;
  bool get isFlashing => _isFlashing;
  bool get focusModeEnabled => _focusModeEnabled;
  int get postponeCount => _postponeCount;
  bool get canPostpone => _postponeCount < maxPostponeCount;

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
        _lastSaveTime = DateTime.now();

        _startTicking();
        _setupActivityMonitor();
        _startPeriodicReminders();
        _startUsageTracking();

        _logger.info('Timers started');
        notifyListeners();
      },
      errorType: ErrorType.timer,
    );
  }

  void _startUsageTracking() {
    _usageTrackerTimer?.cancel();
    // Track usage minutes every minute
    _usageTrackerTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_state == TimerState.running) {
        try {
          sl<StatsService>().addUsageMinutes(1);
        } catch (e) {
          _logger.error('Failed to track usage: $e');
        }
      }
    });
  }

  bool _hasTriggeredPreBreakFlash = false;

  void _startTicking() {
    _shortBreakTimer?.cancel();
    _longBreakTimer?.cancel();

    // Tick every second for accurate tracking
    _shortBreakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state != TimerState.running && _state != TimerState.breakActive) {
        return;
      }

      final now = DateTime.now();
      final delta = now.difference(_lastTickTime ?? now);
      _lastTickTime = now;

      _shortElapsed += delta;
      _longElapsed += delta;

      _updateTrayCountdown();

      // Save state every 10 seconds
      if (DateTime.now().difference(_lastSaveTime ?? DateTime.now()) >
          const Duration(seconds: 10)) {
        _saveTimerState();
        _lastSaveTime = DateTime.now();
      }

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
      sl<TrayManagerService>().setTrayTitle('PAUSED');
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
        sl<TrayManagerService>().setTrayTitle('$mins:$secs');
        break;
      case 'progress':
        final total = _state == TimerState.breakActive 
            ? (_activeBreak?.durationSeconds ?? 60)
            : (_shortBreakIntervalMinutes * 60);
        final done = total - remaining.inSeconds;
        final progress = (done / total * 5).clamp(0, 5).round();
        // Use Pill-like characters for a high-end feel
        final bars = '▰' * progress + '▱' * (5 - progress);
        sl<TrayManagerService>().setTrayTitle(bars);
        break;
      case 'icon':
        final total = _state == TimerState.breakActive 
            ? (_activeBreak?.durationSeconds ?? 60)
            : (_shortBreakIntervalMinutes * 60);
        final percent = (remaining.inSeconds / total);
        String icon = '○';
        if (percent > 0.75) {
          icon = '◔';
        } else if (percent > 0.5) {
          icon = '◑';
        } else if (percent > 0.25) {
          icon = '◕';
        } else {
          icon = '●';
        }
        sl<TrayManagerService>().setTrayTitle('$icon ${mins}m');
        break;
      case 'focusdot':
        if (_state == TimerState.breakActive) {
          sl<TrayManagerService>().setTrayTitle('Break');
        } else {
          sl<TrayManagerService>().setTrayTitle('Focus');
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
    _postponeCount = 0; // Reset postpone count when skipping
    _logger.info('Next short break skipped');
    notifyListeners();
  }

  /// Postpone the current break by 2 minutes
  /// Can be done up to 3 times per break
  void postponeBreak() {
    if (_state != TimerState.breakActive ||
        _postponeCount >= maxPostponeCount) {
      return;
    }

    _postponeCount++;
    _countdownSeconds += postponeDurationSeconds;
    _logger.info('Break postponed: $_postponeCount/$maxPostponeCount');
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
    _postponeCount = 0; // Reset postpone count for new break

    // Use adaptive break duration if service is available
    final adaptiveDuration =
        _adaptiveBreakService?.getSuggestedBreakDuration() ??
        _shortBreakDurationSeconds;
    
    _triggerBreak(
      BreakModel(
        type: BreakType.short,
        durationSeconds: adaptiveDuration,
        title: 'Short Break',
        tip: _randomTip(AppConstants.shortBreakTips),
      ),
    );
    
    // Record work session for adaptive learning
    _adaptiveBreakService?.recordWorkSession(
      duration: shortBreakInterval,
      hourOfDay: DateTime.now().hour,
      activityLevel: 'medium', // Default until we have better detection
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
      if (_state == TimerState.running && _settingsRepository.currentSettings.notificationsEnabled) {
        _notificationService.showPostureReminder();
      }
    });

    // Blink reminder every 10 minutes
    _blinkTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (_state == TimerState.running && _settingsRepository.currentSettings.notificationsEnabled) {
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
    if (_settingsRepository.currentSettings.notificationsEnabled) {
      _notificationService.showBreakStarted(breakTitle: breakModel.title);
    }
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
    if (_settingsRepository.currentSettings.notificationsEnabled) {
      _notificationService.showReminder(
        message: _settingsRepository.currentSettings.flashMessage,
      );
    }
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

    // Start polling for activity
    _activityMonitor.start();
  }

  void triggerFlashDemo({
    required Color color,
    required String style,
    required String animation,
    required double intensity,
    required int durationMs,
  }) {
    _isFlashing = true;
    notifyListeners();
    Timer(Duration(milliseconds: durationMs), () {
      _isFlashing = false;
      notifyListeners();
    });
  }

  String _randomTip(List<String> tips) {
    // Create a copy of the list before shuffling to avoid modifying the original
    final tipsCopy = List<String>.from(tips);
    tipsCopy.shuffle();
    return tipsCopy.first;
  }

  // ============ Persistence Methods ============

  /// Save current timer state to storage
  void saveState() {
    _saveTimerState();
  }

  void _saveTimerState() {
    try {
      final storage = sl<StorageService>();
      storage.setInt('timer_state', _state.index);
      storage.setInt('short_elapsed_seconds', _shortElapsed.inSeconds);
      storage.setInt('long_elapsed_seconds', _longElapsed.inSeconds);
      storage.setInt('countdown_seconds', _countdownSeconds);
      storage.setBool('is_completion_state', _isCompletionState);
      storage.setBool('is_flashing', _isFlashing);
      storage.setInt('postpone_count', _postponeCount);
      storage.setString('last_save_time', DateTime.now().toIso8601String());

      if (_activeBreak != null) {
        storage.setString('active_break_type', _activeBreak!.type.name);
        storage.setInt('active_break_duration', _activeBreak!.durationSeconds);
        storage.setString('active_break_title', _activeBreak!.title);
        storage.setString('active_break_tip', _activeBreak!.tip);
      }
    } catch (e) {
      _logger.error('Failed to save timer state: $e');
    }
  }

  void _loadTimerState() {
    try {
      final storage = sl<StorageService>();

      // Load elapsed times
      final shortElapsedSeconds = storage.getInt('short_elapsed_seconds');
      _shortElapsed = Duration(seconds: shortElapsedSeconds);

      final longElapsedSeconds = storage.getInt('long_elapsed_seconds');
      _longElapsed = Duration(seconds: longElapsedSeconds);

      // Load state
      final stateIndex = storage.getInt('timer_state');
      if (stateIndex >= 0 && stateIndex < TimerState.values.length) {
        _state = TimerState.values[stateIndex];
      }

      // Load countdown
      _countdownSeconds = storage.getInt('countdown_seconds');
      _isCompletionState = storage.getBool('is_completion_state');
      _isFlashing = storage.getBool('is_flashing');
      _postponeCount = storage.getInt('postpone_count');

      // Load active break if exists
      final breakTypeStr = storage.getString('active_break_type');
      if (breakTypeStr.isNotEmpty) {
        final breakDuration = storage.getInt('active_break_duration');
        final breakTitle = storage.getString('active_break_title');
        final breakTip = storage.getString('active_break_tip');

        BreakType breakType;
        switch (breakTypeStr) {
          case 'long':
            breakType = BreakType.long;
            break;
          case 'short':
          default:
            breakType = BreakType.short;
        }

        _activeBreak = BreakModel(
          type: breakType,
          durationSeconds: breakDuration,
          title: breakTitle,
          tip: breakTip,
        );
      }

      _logger.info(
        'Timer state loaded: state=$_state, short=${_shortElapsed.inSeconds}s, long=${_longElapsed.inSeconds}s',
      );
    } catch (e) {
      _logger.error('Failed to load timer state: $e');
    }
  }

  @override
  void dispose() {
    _saveTimerState();
    _shortBreakTimer?.cancel();
    _longBreakTimer?.cancel();
    _countdownTimer?.cancel();
    _usageTrackerTimer?.cancel();
    super.dispose();
  }
}
