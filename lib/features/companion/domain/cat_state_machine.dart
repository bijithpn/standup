enum CatState {
  idle,
  blink,
  stretch,
  walk,
  sleep,
  alert,
  happy,
  drag,
  breakReminder,
  meetingPaused,
  focusMode,
}

enum CatEvent {
  tick,
  userClick,
  userDoubleClick,
  userHover,
  userDragStart,
  userDragEnd,
  breakStarted,
  breakEnded,
  meetingDetected,
  meetingEnded,
  focusModeOn,
  focusModeOff,
  idleTimeout,
  activityDetected,
  randomBehavior,
}

class CatStateTransition {
  final CatEvent event;
  final CatState targetState;
  final Duration? minDuration;
  const CatStateTransition({
    required this.event,
    required this.targetState,
    this.minDuration,
  });
}

class CatStateMachine {
  CatStateMachine({void Function(CatState)? onStateChanged})
      : _onStateChanged = onStateChanged;

  final void Function(CatState)? _onStateChanged;
  CatState _currentState = CatState.idle;
  DateTime? _stateEnteredAt;
  Duration? _minStateDuration;

  CatState get currentState => _currentState;
  Duration get timeInState =>
      _stateEnteredAt != null ? DateTime.now().difference(_stateEnteredAt!) : Duration.zero;
  bool get canTransition =>
      _minStateDuration == null || timeInState >= _minStateDuration!;

  void _transitionTo(CatState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    _stateEnteredAt = DateTime.now();
    _minStateDuration = null;
    _onStateChanged?.call(newState);
  }

  void handleEvent(CatEvent event) {
    switch (_currentState) {
      case CatState.idle:
        _handleIdle(event);
      case CatState.blink:
        _handleBlink(event);
      case CatState.stretch:
        _handleStretch(event);
      case CatState.walk:
        _handleWalk(event);
      case CatState.sleep:
        _handleSleep(event);
      case CatState.alert:
        _handleAlert(event);
      case CatState.happy:
        _handleHappy(event);
      case CatState.drag:
        _handleDrag(event);
      case CatState.breakReminder:
        _handleBreakReminder(event);
      case CatState.meetingPaused:
        _handleMeetingPaused(event);
      case CatState.focusMode:
        _handleFocusMode(event);
    }
  }

  void _handleIdle(CatEvent event) {
    switch (event) {
      case CatEvent.tick:
        break;
      case CatEvent.userClick:
        _transitionTo(CatState.alert);
        _minStateDuration = const Duration(milliseconds: 1500);
      case CatEvent.userDoubleClick:
        _transitionTo(CatState.happy);
        _minStateDuration = const Duration(seconds: 2);
      case CatEvent.userHover:
        _transitionTo(CatState.alert);
        _minStateDuration = const Duration(milliseconds: 500);
      case CatEvent.userDragStart:
        _transitionTo(CatState.drag);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      case CatEvent.meetingDetected:
        _transitionTo(CatState.meetingPaused);
      case CatEvent.focusModeOn:
        _transitionTo(CatState.focusMode);
      case CatEvent.idleTimeout:
        _transitionTo(CatState.sleep);
      case CatEvent.randomBehavior:
        final r = DateTime.now().millisecondsSinceEpoch % 100;
        if (r < 30) {
          _transitionTo(CatState.blink);
          _minStateDuration = const Duration(milliseconds: 300);
        } else if (r < 50) {
          _transitionTo(CatState.stretch);
          _minStateDuration = const Duration(seconds: 2);
        } else if (r < 70) {
          _transitionTo(CatState.walk);
          _minStateDuration = const Duration(seconds: 3);
        }
      default:
        break;
    }
  }

  void _handleBlink(CatEvent event) {
    switch (event) {
      case CatEvent.tick:
        if (canTransition) _transitionTo(CatState.idle);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }

  void _handleStretch(CatEvent event) {
    switch (event) {
      case CatEvent.tick:
        if (canTransition) _transitionTo(CatState.idle);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }

  void _handleWalk(CatEvent event) {
    switch (event) {
      case CatEvent.tick:
        if (canTransition) _transitionTo(CatState.idle);
      case CatEvent.userClick:
        _transitionTo(CatState.alert);
        _minStateDuration = const Duration(milliseconds: 1500);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }

  void _handleSleep(CatEvent event) {
    switch (event) {
      case CatEvent.activityDetected:
        _transitionTo(CatState.idle);
      case CatEvent.userClick:
        _transitionTo(CatState.alert);
        _minStateDuration = const Duration(milliseconds: 1500);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }

  void _handleAlert(CatEvent event) {
    switch (event) {
      case CatEvent.tick:
        if (canTransition) _transitionTo(CatState.idle);
      case CatEvent.userDoubleClick:
        _transitionTo(CatState.happy);
        _minStateDuration = const Duration(seconds: 2);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }

  void _handleHappy(CatEvent event) {
    switch (event) {
      case CatEvent.tick:
        if (canTransition) _transitionTo(CatState.idle);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }

  void _handleDrag(CatEvent event) {
    switch (event) {
      case CatEvent.userDragEnd:
        _transitionTo(CatState.idle);
      default:
        break;
    }
  }

  void _handleBreakReminder(CatEvent event) {
    switch (event) {
      case CatEvent.breakEnded:
        _transitionTo(CatState.happy);
        _minStateDuration = const Duration(seconds: 3);
      case CatEvent.meetingDetected:
        _transitionTo(CatState.meetingPaused);
      default:
        break;
    }
  }

  void _handleMeetingPaused(CatEvent event) {
    switch (event) {
      case CatEvent.meetingEnded:
        _transitionTo(CatState.idle);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }

  void _handleFocusMode(CatEvent event) {
    switch (event) {
      case CatEvent.focusModeOff:
        _transitionTo(CatState.idle);
      case CatEvent.breakStarted:
        _transitionTo(CatState.breakReminder);
      default:
        break;
    }
  }
}
