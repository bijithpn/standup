import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/core/utils/logger.dart';

class TimerRepository {
  final StorageService _storageService;
  final AppLogger _logger = AppLogger();

  TimerRepository(this._storageService);

  void save(
    TimerStateData state, {
    required int shortBreakIntervalMinutes,
    required int shortBreakDurationSeconds,
    required int preBreakWarningSeconds,
    required int longBreakIntervalMinutes,
    required int longBreakDurationMinutes,
    required int pauseTimerAfterMinutes,
    required int resetTimerAfterMinutes,
  }) {
    try {
      _storageService.setString('timer_state', state.state.name);
      _storageService.setString('timer_mode', state.mode.name);
      _storageService.setInt('timer_work_elapsed', state.workElapsed.inSeconds);
      _storageService.setInt(
        'timer_total_work_today',
        state.totalWorkToday.inSeconds,
      );
      _storageService.setInt('timer_countdown', state.countdownSeconds);
      _storageService.setInt(
        'timer_short_break_interval',
        shortBreakIntervalMinutes,
      );
      _storageService.setInt(
        'timer_short_break_duration',
        shortBreakDurationSeconds,
      );
      _storageService.setInt('timer_pre_break_warning', preBreakWarningSeconds);
      _storageService.setInt(
        'timer_long_break_interval',
        longBreakIntervalMinutes,
      );
      _storageService.setInt(
        'timer_long_break_duration',
        longBreakDurationMinutes,
      );
      _storageService.setInt('timer_pause_after', pauseTimerAfterMinutes);
      _storageService.setInt('timer_reset_after', resetTimerAfterMinutes);
      _storageService.setBool('timer_is_completion', state.isCompletionState);

      _storageService.setBool('timer_is_pre_break', state.isPreBreak);
      _storageService.setBool(
        'timer_clock_out_triggered',
        state.clockOutTriggered,
      );
      _storageService.setInt(
        'timer_posture_elapsed',
        state.postureElapsedSeconds,
      );
      _storageService.setInt(
        'timer_eye_blink_elapsed',
        state.eyeBlinkElapsedSeconds,
      );
      if (state.longBreakWindowStartedAt != null) {
        _storageService.setInt(
          'timer_long_break_window',
          state.longBreakWindowStartedAt!.millisecondsSinceEpoch,
        );
      }
      if (state.lastBreakFinishedAt != null) {
        _storageService.setInt(
          'timer_last_break_finished',
          state.lastBreakFinishedAt!.millisecondsSinceEpoch,
        );
      }
      _logger.info('Timer state saved via TimerRepository');
    } catch (e) {
      _logger.error('Failed to save timer state: $e');
    }
  }

  void restore(
    TimerStateData state, {
    required int defaultShortBreakIntervalMinutes,
    required int defaultShortBreakDurationSeconds,
    required int defaultPreBreakWarningSeconds,
    required int defaultLongBreakIntervalMinutes,
    required int defaultLongBreakDurationMinutes,
    required int defaultPauseTimerAfterMinutes,
    required int defaultResetTimerAfterMinutes,
    required void Function(
      int shortInterval,
      int shortDuration,
      int preWarning,
      int longInterval,
      int longDuration,
      int pauseAfter,
      int resetAfter,
    )
    onSettingsRestored,
  }) {
    try {
      final stateStr = _storageService.getString(
        'timer_state',
        defaultValue: 'idle',
      );
      state.state = TimerState.values.firstWhere(
        (s) => s.name == stateStr,
        orElse: () => TimerState.idle,
      );

      // Prevent break screen from showing immediately on application launch
      if (state.state == TimerState.breakActive) {
        state.state = TimerState.running;
        state.workElapsed = Duration.zero;
        state.countdownSeconds = 0;
      }

      final modeStr = _storageService.getString(
        'timer_mode',
        defaultValue: 'flexible',
      );
      state.mode = WorkMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => WorkMode.flexible,
      );

      state.workElapsed = Duration(
        seconds: _storageService.getInt('timer_work_elapsed'),
      );
      state.totalWorkToday = Duration(
        seconds: _storageService.getInt('timer_total_work_today'),
      );
      state.countdownSeconds = _storageService.getInt('timer_countdown');
      final shortInterval = _storageService.getInt(
        'timer_short_break_interval',
        defaultValue: defaultShortBreakIntervalMinutes,
      );
      final shortDuration = _storageService.getInt(
        'timer_short_break_duration',
        defaultValue: defaultShortBreakDurationSeconds,
      );
      final preWarning = _storageService.getInt(
        'timer_pre_break_warning',
        defaultValue: defaultPreBreakWarningSeconds,
      );
      final longInterval = _storageService.getInt(
        'timer_long_break_interval',
        defaultValue: defaultLongBreakIntervalMinutes,
      );
      final longDuration = _storageService.getInt(
        'timer_long_break_duration',
        defaultValue: defaultLongBreakDurationMinutes,
      );
      final pauseAfter = _storageService.getInt(
        'timer_pause_after',
        defaultValue: defaultPauseTimerAfterMinutes,
      );
      final resetAfter = _storageService.getInt(
        'timer_reset_after',
        defaultValue: defaultResetTimerAfterMinutes,
      );

      onSettingsRestored(
        shortInterval,
        shortDuration,
        preWarning,
        longInterval,
        longDuration,
        pauseAfter,
        resetAfter,
      );

      state.isCompletionState = _storageService.getBool('timer_is_completion');

      // Prevent pre-break warnings from showing immediately on application launch
      state.isPreBreak = false;
      state.clockOutTriggered = _storageService.getBool(
        'timer_clock_out_triggered',
      );
      state.postureElapsedSeconds = _storageService.getInt(
        'timer_posture_elapsed',
        defaultValue: 0,
      );
      state.eyeBlinkElapsedSeconds = _storageService.getInt(
        'timer_eye_blink_elapsed',
        defaultValue: 0,
      );

      final longBreakWindowMs = _storageService.getInt(
        'timer_long_break_window',
        defaultValue: 0,
      );
      if (longBreakWindowMs > 0) {
        state.longBreakWindowStartedAt = DateTime.fromMillisecondsSinceEpoch(
          longBreakWindowMs,
        );
      }

      final lastBreakMs = _storageService.getInt(
        'timer_last_break_finished',
        defaultValue: 0,
      );
      if (lastBreakMs > 0) {
        state.lastBreakFinishedAt = DateTime.fromMillisecondsSinceEpoch(
          lastBreakMs,
        );
      }

      _logger.info(
        'Timer state restored via TimerRepository: ${state.state}, elapsed=${state.workElapsed.inSeconds}s',
      );
    } catch (e) {
      _logger.error('Failed to restore timer state: $e');
    }
  }
}
