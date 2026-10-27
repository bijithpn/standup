// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ipc_events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimerStateChangedIpcEvent _$TimerStateChangedIpcEventFromJson(
  Map<String, dynamic> json,
) => TimerStateChangedIpcEvent(
  stateName: json['stateName'] as String,
  countdownSeconds: (json['countdownSeconds'] as num).toInt(),
  workElapsedSeconds: (json['workElapsedSeconds'] as num).toInt(),
  targetEndTime: (json['targetEndTime'] as num?)?.toInt(),
  totalWorkTodaySeconds: (json['totalWorkTodaySeconds'] as num?)?.toInt(),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$TimerStateChangedIpcEventToJson(
  TimerStateChangedIpcEvent instance,
) => <String, dynamic>{
  'stateName': instance.stateName,
  'countdownSeconds': instance.countdownSeconds,
  'workElapsedSeconds': instance.workElapsedSeconds,
  'targetEndTime': instance.targetEndTime,
  'totalWorkTodaySeconds': instance.totalWorkTodaySeconds,
  'runtimeType': instance.$type,
};

BreakStartedIpcEvent _$BreakStartedIpcEventFromJson(
  Map<String, dynamic> json,
) => BreakStartedIpcEvent(
  isLongBreak: json['isLongBreak'] as bool,
  durationSeconds: (json['durationSeconds'] as num).toInt(),
  title: json['title'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$BreakStartedIpcEventToJson(
  BreakStartedIpcEvent instance,
) => <String, dynamic>{
  'isLongBreak': instance.isLongBreak,
  'durationSeconds': instance.durationSeconds,
  'title': instance.title,
  'runtimeType': instance.$type,
};

BreakEndedIpcEvent _$BreakEndedIpcEventFromJson(Map<String, dynamic> json) =>
    BreakEndedIpcEvent(
      skipped: json['skipped'] as bool,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$BreakEndedIpcEventToJson(BreakEndedIpcEvent instance) =>
    <String, dynamic>{
      'skipped': instance.skipped,
      'runtimeType': instance.$type,
    };

CompanionInteractionIpcEvent _$CompanionInteractionIpcEventFromJson(
  Map<String, dynamic> json,
) => CompanionInteractionIpcEvent(
  interactionType: json['interactionType'] as String,
  metadata: json['metadata'] as Map<String, dynamic>?,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$CompanionInteractionIpcEventToJson(
  CompanionInteractionIpcEvent instance,
) => <String, dynamic>{
  'interactionType': instance.interactionType,
  'metadata': instance.metadata,
  'runtimeType': instance.$type,
};

MeetingDetectedIpcEvent _$MeetingDetectedIpcEventFromJson(
  Map<String, dynamic> json,
) => MeetingDetectedIpcEvent(
  isActive: json['isActive'] as bool,
  bundleId: json['bundleId'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$MeetingDetectedIpcEventToJson(
  MeetingDetectedIpcEvent instance,
) => <String, dynamic>{
  'isActive': instance.isActive,
  'bundleId': instance.bundleId,
  'runtimeType': instance.$type,
};

TrayActionIpcEvent _$TrayActionIpcEventFromJson(Map<String, dynamic> json) =>
    TrayActionIpcEvent(
      action: json['action'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$TrayActionIpcEventToJson(TrayActionIpcEvent instance) =>
    <String, dynamic>{'action': instance.action, 'runtimeType': instance.$type};

CompanionCloseIpcEvent _$CompanionCloseIpcEventFromJson(
  Map<String, dynamic> json,
) => CompanionCloseIpcEvent($type: json['runtimeType'] as String?);

Map<String, dynamic> _$CompanionCloseIpcEventToJson(
  CompanionCloseIpcEvent instance,
) => <String, dynamic>{'runtimeType': instance.$type};

CompanionPositionChangedIpcEvent _$CompanionPositionChangedIpcEventFromJson(
  Map<String, dynamic> json,
) => CompanionPositionChangedIpcEvent(
  x: (json['x'] as num).toDouble(),
  y: (json['y'] as num).toDouble(),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$CompanionPositionChangedIpcEventToJson(
  CompanionPositionChangedIpcEvent instance,
) => <String, dynamic>{
  'x': instance.x,
  'y': instance.y,
  'runtimeType': instance.$type,
};

CompanionStateChangedIpcEvent _$CompanionStateChangedIpcEventFromJson(
  Map<String, dynamic> json,
) => CompanionStateChangedIpcEvent(
  state: json['state'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$CompanionStateChangedIpcEventToJson(
  CompanionStateChangedIpcEvent instance,
) => <String, dynamic>{'state': instance.state, 'runtimeType': instance.$type};

UnknownIpcEvent _$UnknownIpcEventFromJson(Map<String, dynamic> json) =>
    UnknownIpcEvent(
      eventName: json['eventName'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$UnknownIpcEventToJson(UnknownIpcEvent instance) =>
    <String, dynamic>{
      'eventName': instance.eventName,
      'payload': instance.payload,
      'runtimeType': instance.$type,
    };
