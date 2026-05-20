import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/core/native/macos_bridge.dart';

class CatBehaviorController {
  final TimerEngine _timerEngine;
  CatAnimationState? _lastState;
  bool? _lastWandering;

  CatBehaviorController({required TimerEngine timerEngine})
      : _timerEngine = timerEngine {
    _timerEngine.addListener(_onTimerChanged);
  }

  /// Tear down hooks when shutting down.
  void dispose() {
    _timerEngine.removeListener(_onTimerChanged);
  }

  /// Listens to core timer engine states and commands the pet to change behaviors.
  void _onTimerChanged() {
    // 1. flashing alert takes top priority (Strict Mode warning, breaks, etc.)
    if (_timerEngine.isFlashing) {
      _sendWandering(false);
      _sendState(CatAnimationState.notification);
      return;
    }

    // 2. pre-break warning countdown (Excited pacing/bounding)
    if (_timerEngine.isPreBreak) {
      _sendWandering(false);
      _sendState(CatAnimationState.excited);
      return;
    }

    // 3. Map states based on TimerState
    switch (_timerEngine.state) {
      case TimerState.breakActive:
        // Break active: pet bounds excitedly in break mode
        _sendWandering(false);
        _sendState(CatAnimationState.breakMode);
        break;

      case TimerState.running:
        // Focus mode active: disable wandering to avoid distraction.
        // The pet sits calmly or types/paws on an invisible keyboard.
        _sendWandering(false);
        _sendState(CatAnimationState.focusMode);
        break;

      case TimerState.paused:
        // Paused: sits peacefully
        _sendWandering(false);
        _sendState(CatAnimationState.idle);
        break;

      case TimerState.idle:
        // Idle/Dashboard: enable random wandering (idle, sleep, walk, clean paws)
        _sendWandering(true);
        _sendState(CatAnimationState.idle);
        break;
    }
  }

  void _sendState(CatAnimationState state) {
    if (_lastState == state) return;
    _lastState = state;
    MacOSBridge.triggerCompanionState(state.name);
  }

  void _sendWandering(bool enabled) {
    if (_lastWandering == enabled) return;
    _lastWandering = enabled;
    MacOSBridge.setCompanionWandering(enabled);
  }
}
