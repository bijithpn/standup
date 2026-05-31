abstract class IpcEvent {
  static const int currentVersion = 1;

  final String eventName;
  final Map<String, dynamic> payload;
  final int version;

  const IpcEvent(this.eventName, this.payload, {this.version = currentVersion});

  Map<String, dynamic> toJson() {
    return {'eventName': eventName, 'payload': payload, 'version': version};
  }

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
}

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
  final int totalWorkTodaySeconds;

  TimerStateChangedIpcEvent({
    required this.stateName,
    required this.countdownSeconds,
    required this.workElapsedSeconds,
    required this.targetEndTime,
    required this.totalWorkTodaySeconds,
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
      countdownSeconds: _readRequired<int>(payload, 'countdownSeconds'),
      workElapsedSeconds: _readRequired<int>(payload, 'workElapsedSeconds'),
      targetEndTime: payload['targetEndTime'] as int?,
      totalWorkTodaySeconds: _readRequired<int>(
        payload,
        'totalWorkTodaySeconds',
      ),
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
      isLongBreak: _readRequired<bool>(payload, 'isLongBreak'),
      durationSeconds: _readRequired<int>(payload, 'durationSeconds'),
      title: _readRequired<String>(payload, 'title'),
    );
  }
}

class BreakEndedIpcEvent extends IpcEvent {
  final bool skipped;

  BreakEndedIpcEvent({required this.skipped})
    : super(IpcEventNames.breakEnded, {'skipped': skipped});

  factory BreakEndedIpcEvent.fromJson(Map<String, dynamic> payload) {
    return BreakEndedIpcEvent(skipped: _readRequired<bool>(payload, 'skipped'));
  }
}

class CompanionInteractionIpcEvent extends IpcEvent {
  final String interactionType;

  CompanionInteractionIpcEvent({required this.interactionType})
    : super(IpcEventNames.companionInteraction, {
        'interactionType': interactionType,
      });

  factory CompanionInteractionIpcEvent.fromJson(Map<String, dynamic> payload) {
    return CompanionInteractionIpcEvent(
      interactionType: _readRequired<String>(payload, 'interactionType'),
    );
  }
}

class UnknownIpcEvent extends IpcEvent {
  UnknownIpcEvent({
    required String eventName,
    required Map<String, dynamic> payload,
  }) : super(eventName, payload);
}
