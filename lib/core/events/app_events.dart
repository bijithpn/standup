sealed class AppEvent {
  final DateTime timestamp;
  AppEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

enum TimerStateEvent { running, paused, idle, breakActive }

class TimerStateChangedEvent extends AppEvent {
  final TimerStateEvent state;
  final int countdownSeconds;
  final int workElapsedSeconds;
  TimerStateChangedEvent({
    required this.state,
    required this.countdownSeconds,
    required this.workElapsedSeconds,
    super.timestamp,
  });
}

class BreakStartedEvent extends AppEvent {
  final bool isLongBreak;
  final int durationSeconds;
  final String title;
  BreakStartedEvent({
    required this.isLongBreak,
    required this.durationSeconds,
    required this.title,
    super.timestamp,
  });
}

class BreakEndedEvent extends AppEvent {
  final bool skipped;
  BreakEndedEvent({required this.skipped, super.timestamp});
}

class BreakPostponedEvent extends AppEvent {
  final int additionalSeconds;
  BreakPostponedEvent({required this.additionalSeconds, super.timestamp});
}

enum CompanionState {
  idle,
  walking,
  sleeping,
  alert,
  dragging,
  listening,
  happy,
  breakReminder,
  meetingPaused,
  focusMode,
}

class CompanionStateChangedEvent extends AppEvent {
  final CompanionState state;
  CompanionStateChangedEvent({required this.state, super.timestamp});
}

class CompanionInteractionEvent extends AppEvent {
  final String interactionType;
  final Map<String, dynamic>? metadata;
  CompanionInteractionEvent({
    required this.interactionType,
    this.metadata,
    super.timestamp,
  });
}

class CompanionPositionChangedEvent extends AppEvent {
  final double x;
  final double y;
  CompanionPositionChangedEvent({
    required this.x,
    required this.y,
    super.timestamp,
  });
}

class MeetingDetectedEvent extends AppEvent {
  final bool isActive;
  final String? bundleId;
  MeetingDetectedEvent({required this.isActive, this.bundleId, super.timestamp});
}

class FocusModeEvent extends AppEvent {
  final bool isActive;
  FocusModeEvent({required this.isActive, super.timestamp});
}

class IdleDetectedEvent extends AppEvent {
  final bool isIdle;
  IdleDetectedEvent({required this.isIdle, super.timestamp});
}

class TrayActionEvent extends AppEvent {
  final String action;
  TrayActionEvent({required this.action, super.timestamp});
}

class SettingsChangedEvent extends AppEvent {
  final String key;
  final dynamic value;
  SettingsChangedEvent({required this.key, required this.value, super.timestamp});
}

class OverlayShownEvent extends AppEvent {
  final String overlayType;
  OverlayShownEvent({required this.overlayType, super.timestamp});
}

class OverlayHiddenEvent extends AppEvent {
  final String overlayType;
  OverlayHiddenEvent({required this.overlayType, super.timestamp});
}
