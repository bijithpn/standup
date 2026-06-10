abstract class IpcEvent {
  static const int currentVersion = 1;

  final String eventName;
  final Map<String, dynamic> payload;
  final int version;

  const IpcEvent(this.eventName, this.payload, {this.version = currentVersion});

  Map<String, dynamic> toJson() {
    return {'eventName': eventName, 'payload': payload, 'version': version};
  }

  /// Parses untrusted IPC payloads at the engine boundary.
  /// Unknown events are preserved instead of rejected so older secondary
  /// engines can keep running while the main engine rolls forward.
  static IpcEvent parse(String eventName, Map<String, dynamic> payload) {
    switch (eventName) {
      case IpcEventNames.timerStateChanged:
        return TimerStateChangedIpcEvent.fromJson(payload);
      case IpcEventNames.breakStarted:
        return BreakStartedIpcEvent.fromJson(payload);
      case IpcEventNames.breakEnded:
        return BreakEndedIpcEvent.fromJson(payload);
      case IpcEventNames.companionInteraction:
        return CompanionInteractionIpcEvent.fromJson(payload);
      case IpcEventNames.detectionMeeting:
        return MeetingDetectedIpcEvent.fromJson(payload);
      case IpcEventNames.detectionFocusMode:
        return FocusModeIpcEvent.fromJson(payload);
      case IpcEventNames.trayAction:
        return TrayActionIpcEvent.fromJson(payload);
      case IpcEventNames.companionClose:
        return CompanionCloseIpcEvent();
      case IpcEventNames.companionPositionChanged:
        return CompanionPositionChangedIpcEvent.fromJson(payload);
      case IpcEventNames.companionStateChanged:
        return CompanionStateChangedIpcEvent.fromJson(payload);
      default:
        return UnknownIpcEvent(eventName: eventName, payload: payload);
    }
  }
}

class IpcEventNames {
  IpcEventNames._();

  static const String timerStateChanged = 'timer.stateChanged';
  static const String breakStarted = 'timer.breakStarted';
  static const String breakEnded = 'timer.breakEnded';
  static const String companionInteraction = 'companion.interaction';
  static const String detectionMeeting = 'detection.meeting';
  static const String detectionFocusMode = 'detection.focusMode';
  static const String trayAction = 'tray.action';
  static const String companionClose = 'companion.close';
  static const String companionPositionChanged = 'companion.positionChanged';
  static const String companionStateChanged = 'companion.stateChanged';
}

/// Reads a required payload field and fails before it reaches app state.
T _readRequired<T>(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is T) return value;
  throw FormatException('IPC payload field "$key" must be $T');
}

class TimerStateChangedIpcEvent extends IpcEvent {
  final String stateName;
  final int countdownSeconds;
  final int workElapsedSeconds;
  final int? targetEndTime;
  final int? totalWorkTodaySeconds;

  TimerStateChangedIpcEvent({
    required this.stateName,
    required this.countdownSeconds,
    required this.workElapsedSeconds,
    this.targetEndTime,
    this.totalWorkTodaySeconds,
  }) : super(IpcEventNames.timerStateChanged, {
         'state': stateName,
         'countdownSeconds': countdownSeconds,
         'workElapsedSeconds': workElapsedSeconds,
         'targetEndTime': targetEndTime,
         'totalWorkTodaySeconds': totalWorkTodaySeconds,
       });

  factory TimerStateChangedIpcEvent.fromJson(Map<String, dynamic> payload) {
    return TimerStateChangedIpcEvent(
      stateName: _readRequired<String>(payload, 'state'),
      countdownSeconds: (payload['countdownSeconds'] as num?)?.toInt() ?? 0,
      workElapsedSeconds: (payload['workElapsedSeconds'] as num?)?.toInt() ?? 0,
      targetEndTime: payload['targetEndTime'] as int?,
      totalWorkTodaySeconds: (payload['totalWorkTodaySeconds'] as num?)
          ?.toInt(),
    );
  }
}

class BreakStartedIpcEvent extends IpcEvent {
  final bool isLongBreak;
  final int durationSeconds;
  final String title;

  BreakStartedIpcEvent({
    required this.isLongBreak,
    required this.durationSeconds,
    required this.title,
  }) : super(IpcEventNames.breakStarted, {
         'isLongBreak': isLongBreak,
         'durationSeconds': durationSeconds,
         'title': title,
       });

  factory BreakStartedIpcEvent.fromJson(Map<String, dynamic> payload) {
    return BreakStartedIpcEvent(
      isLongBreak: payload['isLongBreak'] as bool? ?? false,
      durationSeconds: (payload['durationSeconds'] as num?)?.toInt() ?? 0,
      title: payload['title'] as String? ?? 'Break',
    );
  }
}

class BreakEndedIpcEvent extends IpcEvent {
  final bool skipped;

  BreakEndedIpcEvent({required this.skipped})
    : super(IpcEventNames.breakEnded, {'skipped': skipped});

  factory BreakEndedIpcEvent.fromJson(Map<String, dynamic> payload) {
    return BreakEndedIpcEvent(skipped: payload['skipped'] as bool? ?? false);
  }
}

class CompanionInteractionIpcEvent extends IpcEvent {
  final String interactionType;
  final Map<String, dynamic>? metadata;

  CompanionInteractionIpcEvent({required this.interactionType, this.metadata})
    : super(IpcEventNames.companionInteraction, {
        'interactionType': interactionType,
        'metadata': metadata,
      });

  factory CompanionInteractionIpcEvent.fromJson(Map<String, dynamic> payload) {
    return CompanionInteractionIpcEvent(
      interactionType: payload['interactionType'] as String? ?? 'click',
      metadata: payload['metadata'] != null
          ? Map<String, dynamic>.from(payload['metadata'] as Map)
          : null,
    );
  }
}

class MeetingDetectedIpcEvent extends IpcEvent {
  final bool isActive;
  final String bundleId;

  MeetingDetectedIpcEvent({required this.isActive, required this.bundleId})
    : super(IpcEventNames.detectionMeeting, {
        'isActive': isActive,
        'bundleId': bundleId,
      });

  factory MeetingDetectedIpcEvent.fromJson(Map<String, dynamic> payload) {
    return MeetingDetectedIpcEvent(
      isActive: payload['isActive'] as bool? ?? false,
      bundleId: payload['bundleId'] as String? ?? '',
    );
  }
}

class FocusModeIpcEvent extends IpcEvent {
  final bool isActive;

  FocusModeIpcEvent({required this.isActive})
    : super(IpcEventNames.detectionFocusMode, {'isActive': isActive});

  factory FocusModeIpcEvent.fromJson(Map<String, dynamic> payload) {
    return FocusModeIpcEvent(isActive: payload['isActive'] as bool? ?? false);
  }
}

class TrayActionIpcEvent extends IpcEvent {
  final String action;

  TrayActionIpcEvent({required this.action})
    : super(IpcEventNames.trayAction, {'action': action});

  factory TrayActionIpcEvent.fromJson(Map<String, dynamic> payload) {
    return TrayActionIpcEvent(action: payload['action'] as String? ?? '');
  }
}

class CompanionCloseIpcEvent extends IpcEvent {
  CompanionCloseIpcEvent() : super(IpcEventNames.companionClose, {});
}

class CompanionPositionChangedIpcEvent extends IpcEvent {
  final double x;
  final double y;

  CompanionPositionChangedIpcEvent({required this.x, required this.y})
    : super(IpcEventNames.companionPositionChanged, {'x': x, 'y': y});

  factory CompanionPositionChangedIpcEvent.fromJson(
    Map<String, dynamic> payload,
  ) {
    return CompanionPositionChangedIpcEvent(
      x: (payload['x'] as num?)?.toDouble() ?? 0,
      y: (payload['y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CompanionStateChangedIpcEvent extends IpcEvent {
  final String state;

  CompanionStateChangedIpcEvent({required this.state})
    : super(IpcEventNames.companionStateChanged, {'state': state});

  factory CompanionStateChangedIpcEvent.fromJson(Map<String, dynamic> payload) {
    return CompanionStateChangedIpcEvent(
      state: payload['state'] as String? ?? '',
    );
  }
}

class UnknownIpcEvent extends IpcEvent {
  UnknownIpcEvent({
    required String eventName,
    required Map<String, dynamic> payload,
  }) : super(eventName, payload);
}
