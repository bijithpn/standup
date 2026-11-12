import 'package:freezed_annotation/freezed_annotation.dart';

part 'ipc_events.freezed.dart';
part 'ipc_events.g.dart';

@freezed
sealed class IpcEvent with _$IpcEvent {
  const IpcEvent._();

  const factory IpcEvent.timerStateChanged({
    required String stateName,
    required int countdownSeconds,
    required int workElapsedSeconds,
    int? targetEndTime,
    int? totalWorkTodaySeconds,
  }) = TimerStateChangedIpcEvent;

  const factory IpcEvent.breakStarted({
    required bool isLongBreak,
    required int durationSeconds,
    required String title,
  }) = BreakStartedIpcEvent;

  const factory IpcEvent.breakEnded({required bool skipped}) =
      BreakEndedIpcEvent;

  const factory IpcEvent.companionInteraction({
    required String interactionType,
    Map<String, dynamic>? metadata,
  }) = CompanionInteractionIpcEvent;

  const factory IpcEvent.meetingDetected({
    required bool isActive,
    required String bundleId,
  }) = MeetingDetectedIpcEvent;

  const factory IpcEvent.trayAction({required String action}) =
      TrayActionIpcEvent;

  const factory IpcEvent.companionClose() = CompanionCloseIpcEvent;

  const factory IpcEvent.companionPositionChanged({
    required double x,
    required double y,
  }) = CompanionPositionChangedIpcEvent;

  const factory IpcEvent.companionStateChanged({required String state}) =
      CompanionStateChangedIpcEvent;

  const factory IpcEvent.unknown({
    required String eventName,
    required Map<String, dynamic> payload,
  }) = UnknownIpcEvent;

  factory IpcEvent.fromJson(Map<String, dynamic> json) =>
      _$IpcEventFromJson(json);

  String get eventName => when(
    timerStateChanged: (_, _, _, _, _) => IpcEventNames.timerStateChanged,
    breakStarted: (_, _, _) => IpcEventNames.breakStarted,
    breakEnded: (_) => IpcEventNames.breakEnded,
    companionInteraction: (_, _) => IpcEventNames.companionInteraction,
    meetingDetected: (_, _) => IpcEventNames.detectionMeeting,
    trayAction: (_) => IpcEventNames.trayAction,
    companionClose: () => IpcEventNames.companionClose,
    companionPositionChanged: (_, _) => IpcEventNames.companionPositionChanged,
    companionStateChanged: (_) => IpcEventNames.companionStateChanged,
    unknown: (name, _) => name,
  );

  Map<String, dynamic> get payload => (toJson()..remove('runtimeType'));

  static IpcEvent parse(String eventName, Map<String, dynamic> payload) {
    // Add runtimeType for Freezed fromJson
    final Map<String, dynamic> jsonWithRuntimeType = Map.from(payload);
    switch (eventName) {
      case IpcEventNames.timerStateChanged:
        jsonWithRuntimeType['runtimeType'] = 'timerStateChanged';
        break;
      case IpcEventNames.breakStarted:
        jsonWithRuntimeType['runtimeType'] = 'breakStarted';
        break;
      case IpcEventNames.breakEnded:
        jsonWithRuntimeType['runtimeType'] = 'breakEnded';
        break;
      case IpcEventNames.companionInteraction:
        jsonWithRuntimeType['runtimeType'] = 'companionInteraction';
        break;
      case IpcEventNames.detectionMeeting:
        jsonWithRuntimeType['runtimeType'] = 'meetingDetected';
        break;
      case IpcEventNames.trayAction:
        jsonWithRuntimeType['runtimeType'] = 'trayAction';
        break;
      case IpcEventNames.companionClose:
        jsonWithRuntimeType['runtimeType'] = 'companionClose';
        break;
      case IpcEventNames.companionPositionChanged:
        jsonWithRuntimeType['runtimeType'] = 'companionPositionChanged';
        break;
      case IpcEventNames.companionStateChanged:
        jsonWithRuntimeType['runtimeType'] = 'companionStateChanged';
        break;
      default:
        return IpcEvent.unknown(eventName: eventName, payload: payload);
    }
    return IpcEvent.fromJson(jsonWithRuntimeType);
  }
}

class IpcEventNames {
  IpcEventNames._();

  static const String timerStateChanged = 'timer.stateChanged';
  static const String breakStarted = 'timer.breakStarted';
  static const String breakEnded = 'timer.breakEnded';
  static const String companionInteraction = 'companion.interaction';
  static const String detectionMeeting = 'detection.meeting';
  static const String trayAction = 'tray.action';
  static const String companionClose = 'companion.close';
  static const String companionPositionChanged = 'companion.positionChanged';
  static const String companionStateChanged = 'companion.stateChanged';
}
