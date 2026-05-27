import 'package:breakmate/features/break_system/domain/break_model.dart';

enum TimerState { running, paused, idle, breakActive }

enum WorkMode { pomodoro, deepWork, flexible, strict }

/// Container class that encapsulates the operational state variables of the TimerEngine.
class TimerStateData {
  TimerState state = TimerState.idle;
  WorkMode mode = WorkMode.flexible;
  BreakModel? activeBreak;
  int countdownSeconds = 0;
  bool isCompletionState = false;
  Duration workElapsed = Duration.zero;
  Duration totalWorkToday = Duration.zero;
  bool isPreBreak = false;
  int postureElapsedSeconds = 0;
  int eyeBlinkElapsedSeconds = 0;
  bool clockOutTriggered = false;
  DateTime? longBreakWindowStartedAt;
  DateTime? lastBreakFinishedAt;
  DateTime? breakEndTime;
  DateTime? workEndTime;
  bool isManuallyPaused = false;
  bool systemSleepPaused = false;
  bool manualOverride = false;
  DateTime? lastTickTime;
}
