import 'timer_state.dart';

class TimerTransition {
  static TimerState transition(TimerState current, String action) {
    switch (action) {
      case 'start':
        return TimerState.running;
      case 'pause':
        return current == TimerState.running ? TimerState.paused : current;
      case 'resume':
        return current == TimerState.paused ? TimerState.running : current;
      case 'reset':
        return TimerState.idle;
      case 'break':
        return TimerState.breakActive;
      default:
        return current;
    }
  }
}
