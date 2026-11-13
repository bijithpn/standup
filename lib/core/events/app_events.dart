import 'dart:ui' show Rect;

/// Base type for events published on the in-app event bus; sealed so listeners can switch exhaustively.
sealed class AppEvent {
  final DateTime timestamp;
  AppEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

// Mirrors the timer engine states for UI/tray listeners.
enum TimerStateEvent { running, paused, idle, breakActive }

/// Emitted by the timer engine on every state change or tick; drives the countdown UI and tray.
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

/// Emitted when a break begins; triggers the break overlay.
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

/// Emitted when a break finishes or is skipped.
class BreakEndedEvent extends AppEvent {
  final bool skipped;
  BreakEndedEvent({required this.skipped, super.timestamp});
}

/// Emitted when the user snoozes a pending break.
class BreakPostponedEvent extends AppEvent {
  final int additionalSeconds;
  BreakPostponedEvent({required this.additionalSeconds, super.timestamp});
}

// Animation states of the desktop companion pet.
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
}

class CompanionStateChangedEvent extends AppEvent {
  final CompanionState state;
  CompanionStateChangedEvent({required this.state, super.timestamp});
}

/// User interaction with the companion (click, pet, etc.), identified by [interactionType].
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

/// A meeting/video call started or ended.
class MeetingDetectedEvent extends AppEvent {
  final bool isActive;
  final String? bundleId;
  MeetingDetectedEvent({
    required this.isActive,
    this.bundleId,
    super.timestamp,
  });
}

/// User went idle or became active again.
class IdleDetectedEvent extends AppEvent {
  final bool isIdle;
  IdleDetectedEvent({required this.isIdle, super.timestamp});
}

/// A tray/menu-bar menu item was chosen.
class TrayActionEvent extends AppEvent {
  final String action;
  TrayActionEvent({required this.action, super.timestamp});
}

/// A single setting changed; services subscribe to react without polling.
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

/// Display configuration changed (resolution, arrangement); overlays re-layout.
class DisplayChangedEvent extends AppEvent {
  DisplayChangedEvent({super.timestamp});
}

class OverlayLayoutChangedEvent extends AppEvent {
  final String displayId;
  OverlayLayoutChangedEvent({required this.displayId, super.timestamp});
}

/// A health reminder (eyes, posture, water, ...) is due, shown as [displayType].
class HealthReminderEvent extends AppEvent {
  final String reminderType;
  final String displayType;
  HealthReminderEvent({
    required this.reminderType,
    required this.displayType,
    super.timestamp,
  });
}

class NotificationPermissionDeniedEvent extends AppEvent {
  NotificationPermissionDeniedEvent({super.timestamp});
}

// Cursor/throwable/pet events below drive the companion pet behaviour.
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

/// The window the pet was standing on closed or moved away, so the pet must fall.
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

/// Bounds of the window the pet is constrained to changed.
class ConstraintWindowBoundsChangedEvent extends AppEvent {
  final Rect bounds;
  ConstraintWindowBoundsChangedEvent({required this.bounds, super.timestamp});
}

class LowPowerModeChangedEvent extends AppEvent {
  final bool isLowPower;
  LowPowerModeChangedEvent({required this.isLowPower, super.timestamp});
}
