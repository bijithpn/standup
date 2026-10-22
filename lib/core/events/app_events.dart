import 'dart:ui' show Rect;

sealed class AppEvent {
  final DateTime timestamp;
  AppEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

enum TimerStateEvent { running, paused, idle, breakActive }

class TimerStateChangedEvent extends AppEvent {
  final TimerStateEvent state;
  final int countdownSeconds;
  final int workElapsedSeconds;
  final DateTime? targetEndTime;
  final int? totalWorkTodaySeconds;
  TimerStateChangedEvent({
    required this.state,
    required this.countdownSeconds,
    required this.workElapsedSeconds,
    this.targetEndTime,
    this.totalWorkTodaySeconds,
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
  stretch,
  blink,
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
  MeetingDetectedEvent({
    required this.isActive,
    this.bundleId,
    super.timestamp,
  });
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
  SettingsChangedEvent({
    required this.key,
    required this.value,
    super.timestamp,
  });
}

class OverlayShownEvent extends AppEvent {
  final String overlayType;
  OverlayShownEvent({required this.overlayType, super.timestamp});
}

class OverlayHiddenEvent extends AppEvent {
  final String overlayType;
  OverlayHiddenEvent({required this.overlayType, super.timestamp});
}

class DisplayConnectedEvent extends AppEvent {
  final String displayId;
  DisplayConnectedEvent({required this.displayId, super.timestamp});
}

class DisplayDisconnectedEvent extends AppEvent {
  final String displayId;
  DisplayDisconnectedEvent({required this.displayId, super.timestamp});
}

class DisplayChangedEvent extends AppEvent {
  DisplayChangedEvent({super.timestamp});
}

class OverlayLayoutChangedEvent extends AppEvent {
  final String displayId;
  OverlayLayoutChangedEvent({required this.displayId, super.timestamp});
}

class HealthReminderEvent extends AppEvent {
  final String reminderType; // 'posture' or 'eyeblink'
  final String displayType; // 'native' or 'overlay'
  HealthReminderEvent({
    required this.reminderType,
    required this.displayType,
    super.timestamp,
  });
}

class NotificationPermissionDeniedEvent extends AppEvent {
  NotificationPermissionDeniedEvent({super.timestamp});
}

class CursorEnteredZoneEvent extends AppEvent {
  final double velocity;
  CursorEnteredZoneEvent({required this.velocity, super.timestamp});
}

class CursorExitedZoneEvent extends AppEvent {
  CursorExitedZoneEvent({super.timestamp});
}

class CursorDwellEvent extends AppEvent {
  final double durationSeconds;
  CursorDwellEvent({required this.durationSeconds, super.timestamp});
}

class CursorFastMoveEvent extends AppEvent {
  final double velocity;
  CursorFastMoveEvent({required this.velocity, super.timestamp});
}

class ThrowableSpawnedEvent extends AppEvent {
  final int objectId;
  ThrowableSpawnedEvent({required this.objectId, super.timestamp});
}

class ThrowableStationaryEvent extends AppEvent {
  final int objectId;
  ThrowableStationaryEvent({required this.objectId, super.timestamp});
}

class ThrowableFetchedEvent extends AppEvent {
  final int objectId;
  ThrowableFetchedEvent({required this.objectId, super.timestamp});
}

class ThrowableReturnedEvent extends AppEvent {
  final int objectId;
  ThrowableReturnedEvent({required this.objectId, super.timestamp});
}

class ThrowableDisposedEvent extends AppEvent {
  final int objectId;
  ThrowableDisposedEvent({required this.objectId, super.timestamp});
}

class ThrowableEatenEvent extends AppEvent {
  final int objectId;
  ThrowableEatenEvent({required this.objectId, super.timestamp});
}

class ThrowRejectedEvent extends AppEvent {
  ThrowRejectedEvent({super.timestamp});
}

class TreatSpawnFailedEvent extends AppEvent {
  TreatSpawnFailedEvent({super.timestamp});
}

class PetWindowOverlapEvent extends AppEvent {
  final bool started;
  PetWindowOverlapEvent({required this.started, super.timestamp});
}

class PetStandingSurfaceLostEvent extends AppEvent {
  PetStandingSurfaceLostEvent({super.timestamp});
}

class PetStandingWindowMovedEvent extends AppEvent {
  final Rect newBounds;
  PetStandingWindowMovedEvent({required this.newBounds, super.timestamp});
}

class PetLandedEvent extends AppEvent {
  PetLandedEvent({super.timestamp});
}

class PlatformErrorEvent extends AppEvent {
  final String message;
  PlatformErrorEvent({required this.message, super.timestamp});
}

class ConstraintWindowBoundsChangedEvent extends AppEvent {
  final Rect bounds;
  ConstraintWindowBoundsChangedEvent({required this.bounds, super.timestamp});
}

class LowPowerModeChangedEvent extends AppEvent {
  final bool isLowPower;
  LowPowerModeChangedEvent({required this.isLowPower, super.timestamp});
}

class BatteryStateChangedEvent extends AppEvent {
  final bool isOnBattery;
  final double batteryLevel;
  final bool isLowPowerMode;
  BatteryStateChangedEvent({
    required this.isOnBattery,
    this.batteryLevel = 1.0,
    this.isLowPowerMode = false,
    super.timestamp,
  });
}
