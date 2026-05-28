

abstract class IpcEvent {
  final String eventName;
  final Map<String, dynamic> payload;

  const IpcEvent(this.eventName, this.payload);

  Map<String, dynamic> toJson() {
    return {
      'eventName': eventName,
      'payload': payload,
    };
  }
}

class TimerStateChangedIpcEvent extends IpcEvent {
  TimerStateChangedIpcEvent({
    required String stateName,
    required int countdownSeconds,
    required int workElapsedSeconds,
    required int? targetEndTime,
    required int totalWorkTodaySeconds,
  }) : super('timer.stateChanged', {
          'state': stateName,
          'countdownSeconds': countdownSeconds,
          'workElapsedSeconds': workElapsedSeconds,
          ? 'targetEndTime': targetEndTime,
          'totalWorkTodaySeconds': totalWorkTodaySeconds,
        });
}

class BreakStartedIpcEvent extends IpcEvent {
  BreakStartedIpcEvent({
    required bool isLongBreak,
    required int durationSeconds,
    required String title,
  }) : super('timer.breakStarted', {
          'isLongBreak': isLongBreak,
          'durationSeconds': durationSeconds,
          'title': title,
        });
}

class BreakEndedIpcEvent extends IpcEvent {
  BreakEndedIpcEvent({
    required bool skipped,
  }) : super('timer.breakEnded', {
          'skipped': skipped,
        });
}

class CompanionInteractionIpcEvent extends IpcEvent {
  CompanionInteractionIpcEvent({
    required String interactionType,
  }) : super('companion.interaction', {
          'interactionType': interactionType,
        });
}
