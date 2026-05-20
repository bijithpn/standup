import 'dart:async';
import 'package:standup/core/events/app_events.dart';
import 'package:standup/core/events/event_bus.dart';
import 'package:standup/core/utils/logger.dart';

class CompanionStateManager {
  CompanionStateManager({EventBus? eventBus})
      : _eventBus = eventBus ?? EventBus.instance,
        _logger = AppLogger();

  final EventBus _eventBus;
  final AppLogger _logger;
  StreamSubscription<AppEvent>? _subscription;

  CompanionState _state = CompanionState.idle;
  bool _isVisible = false;
  double _positionX = 0;
  double _positionY = 0;
  String _currentTheme = 'grey';
  bool _isDragging = false;
  bool _meetingPaused = false;
  bool _focusModeActive = false;

  CompanionState get state => _state;
  bool get isVisible => _isVisible;
  double get positionX => _positionX;
  double get positionY => _positionY;
  String get currentTheme => _currentTheme;
  bool get isDragging => _isDragging;
  bool get meetingPaused => _meetingPaused;
  bool get focusModeActive => _focusModeActive;

  void startListening() {
    _subscription = _eventBus.stream.listen(_handleEvent);
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handleEvent(AppEvent event) {
    switch (event) {
      case TimerStateChangedEvent e:
        _onTimerStateChanged(e);
      case BreakStartedEvent e:
        _onBreakStarted(e);
      case BreakEndedEvent e:
        _onBreakEnded(e);
      case MeetingDetectedEvent e:
        _onMeetingDetected(e);
      case FocusModeEvent e:
        _onFocusMode(e);
      case IdleDetectedEvent e:
        _onIdleDetected(e);
      case CompanionInteractionEvent e:
        _onInteraction(e);
      case CompanionPositionChangedEvent e:
        _onPositionChanged(e);
      case SettingsChangedEvent e:
        _onSettingsChanged(e);
      default:
        break;
    }
  }

  void _onTimerStateChanged(TimerStateChangedEvent event) {
    switch (event.state) {
      case TimerStateEvent.running:
        if (_meetingPaused || _focusModeActive) return;
        _setState(CompanionState.idle);
      case TimerStateEvent.breakActive:
        _setState(CompanionState.breakReminder);
      case TimerStateEvent.paused:
        _setState(CompanionState.idle);
      case TimerStateEvent.idle:
        _setState(CompanionState.sleeping);
    }
  }

  void _onBreakStarted(BreakStartedEvent event) {
    _setState(CompanionState.breakReminder);
  }

  void _onBreakEnded(BreakEndedEvent event) {
    if (_meetingPaused) {
      _setState(CompanionState.meetingPaused);
    } else if (_focusModeActive) {
      _setState(CompanionState.focusMode);
    } else {
      _setState(CompanionState.happy);
      Future.delayed(const Duration(seconds: 3), () {
        if (_state == CompanionState.happy) {
          _setState(CompanionState.idle);
        }
      });
    }
  }

  void _onMeetingDetected(MeetingDetectedEvent event) {
    _meetingPaused = event.isActive;
    if (event.isActive) {
      _setState(CompanionState.meetingPaused);
    } else if (_state == CompanionState.meetingPaused) {
      _setState(CompanionState.idle);
    }
  }

  void _onFocusMode(FocusModeEvent event) {
    _focusModeActive = event.isActive;
    if (event.isActive) {
      _setState(CompanionState.focusMode);
    } else if (_state == CompanionState.focusMode) {
      _setState(CompanionState.idle);
    }
  }

  void _onIdleDetected(IdleDetectedEvent event) {
    if (event.isIdle && _state == CompanionState.idle) {
      _setState(CompanionState.sleeping);
    } else if (!event.isIdle && _state == CompanionState.sleeping) {
      _setState(CompanionState.idle);
    }
  }

  void _onInteraction(CompanionInteractionEvent event) {
    switch (event.interactionType) {
      case 'click':
        _setState(CompanionState.alert);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (_state == CompanionState.alert) _setState(CompanionState.idle);
        });
      case 'doubleClick':
        _setState(CompanionState.happy);
        Future.delayed(const Duration(seconds: 2), () {
          if (_state == CompanionState.happy) _setState(CompanionState.idle);
        });
      case 'drag':
        _isDragging = true;
        _setState(CompanionState.dragging);
      case 'hover':
        if (_state == CompanionState.idle) {
          _setState(CompanionState.alert);
        }
      case 'rightClick':
        break;
    }
  }

  void _onPositionChanged(CompanionPositionChangedEvent event) {
    _positionX = event.x;
    _positionY = event.y;
  }

  void _onSettingsChanged(SettingsChangedEvent event) {
    if (event.key == 'companion_theme') {
      _currentTheme = event.value as String;
    }
  }

  void _setState(CompanionState newState) {
    if (_state == newState) return;
    _state = newState;
    _eventBus.emit(CompanionStateChangedEvent(state: newState));
    _logger.info('Companion state changed to: ${newState.name}');
  }

  void setVisibility(bool visible) {
    _isVisible = visible;
  }

  void endDrag() {
    _isDragging = false;
    if (_state == CompanionState.dragging) {
      _setState(CompanionState.idle);
    }
  }

  void dispose() {
    stopListening();
  }
}
