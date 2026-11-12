// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ipc_events.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
IpcEvent _$IpcEventFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'timerStateChanged':
          return TimerStateChangedIpcEvent.fromJson(
            json
          );
                case 'breakStarted':
          return BreakStartedIpcEvent.fromJson(
            json
          );
                case 'breakEnded':
          return BreakEndedIpcEvent.fromJson(
            json
          );
                case 'companionInteraction':
          return CompanionInteractionIpcEvent.fromJson(
            json
          );
                case 'meetingDetected':
          return MeetingDetectedIpcEvent.fromJson(
            json
          );
                case 'trayAction':
          return TrayActionIpcEvent.fromJson(
            json
          );
                case 'companionClose':
          return CompanionCloseIpcEvent.fromJson(
            json
          );
                case 'companionPositionChanged':
          return CompanionPositionChangedIpcEvent.fromJson(
            json
          );
                case 'companionStateChanged':
          return CompanionStateChangedIpcEvent.fromJson(
            json
          );
                case 'unknown':
          return UnknownIpcEvent.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'IpcEvent',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$IpcEvent {



  /// Serializes this IpcEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is IpcEvent);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IpcEvent()';
}


}

/// @nodoc
class $IpcEventCopyWith<$Res>  {
$IpcEventCopyWith(IpcEvent _, $Res Function(IpcEvent) __);
}


/// Adds pattern-matching-related methods to [IpcEvent].
extension IpcEventPatterns on IpcEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TimerStateChangedIpcEvent value)?  timerStateChanged,TResult Function( BreakStartedIpcEvent value)?  breakStarted,TResult Function( BreakEndedIpcEvent value)?  breakEnded,TResult Function( CompanionInteractionIpcEvent value)?  companionInteraction,TResult Function( MeetingDetectedIpcEvent value)?  meetingDetected,TResult Function( TrayActionIpcEvent value)?  trayAction,TResult Function( CompanionCloseIpcEvent value)?  companionClose,TResult Function( CompanionPositionChangedIpcEvent value)?  companionPositionChanged,TResult Function( CompanionStateChangedIpcEvent value)?  companionStateChanged,TResult Function( UnknownIpcEvent value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TimerStateChangedIpcEvent() when timerStateChanged != null:
return timerStateChanged(_that);case BreakStartedIpcEvent() when breakStarted != null:
return breakStarted(_that);case BreakEndedIpcEvent() when breakEnded != null:
return breakEnded(_that);case CompanionInteractionIpcEvent() when companionInteraction != null:
return companionInteraction(_that);case MeetingDetectedIpcEvent() when meetingDetected != null:
return meetingDetected(_that);case TrayActionIpcEvent() when trayAction != null:
return trayAction(_that);case CompanionCloseIpcEvent() when companionClose != null:
return companionClose(_that);case CompanionPositionChangedIpcEvent() when companionPositionChanged != null:
return companionPositionChanged(_that);case CompanionStateChangedIpcEvent() when companionStateChanged != null:
return companionStateChanged(_that);case UnknownIpcEvent() when unknown != null:
return unknown(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TimerStateChangedIpcEvent value)  timerStateChanged,required TResult Function( BreakStartedIpcEvent value)  breakStarted,required TResult Function( BreakEndedIpcEvent value)  breakEnded,required TResult Function( CompanionInteractionIpcEvent value)  companionInteraction,required TResult Function( MeetingDetectedIpcEvent value)  meetingDetected,required TResult Function( TrayActionIpcEvent value)  trayAction,required TResult Function( CompanionCloseIpcEvent value)  companionClose,required TResult Function( CompanionPositionChangedIpcEvent value)  companionPositionChanged,required TResult Function( CompanionStateChangedIpcEvent value)  companionStateChanged,required TResult Function( UnknownIpcEvent value)  unknown,}){
final _that = this;
switch (_that) {
case TimerStateChangedIpcEvent():
return timerStateChanged(_that);case BreakStartedIpcEvent():
return breakStarted(_that);case BreakEndedIpcEvent():
return breakEnded(_that);case CompanionInteractionIpcEvent():
return companionInteraction(_that);case MeetingDetectedIpcEvent():
return meetingDetected(_that);case TrayActionIpcEvent():
return trayAction(_that);case CompanionCloseIpcEvent():
return companionClose(_that);case CompanionPositionChangedIpcEvent():
return companionPositionChanged(_that);case CompanionStateChangedIpcEvent():
return companionStateChanged(_that);case UnknownIpcEvent():
return unknown(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TimerStateChangedIpcEvent value)?  timerStateChanged,TResult? Function( BreakStartedIpcEvent value)?  breakStarted,TResult? Function( BreakEndedIpcEvent value)?  breakEnded,TResult? Function( CompanionInteractionIpcEvent value)?  companionInteraction,TResult? Function( MeetingDetectedIpcEvent value)?  meetingDetected,TResult? Function( TrayActionIpcEvent value)?  trayAction,TResult? Function( CompanionCloseIpcEvent value)?  companionClose,TResult? Function( CompanionPositionChangedIpcEvent value)?  companionPositionChanged,TResult? Function( CompanionStateChangedIpcEvent value)?  companionStateChanged,TResult? Function( UnknownIpcEvent value)?  unknown,}){
final _that = this;
switch (_that) {
case TimerStateChangedIpcEvent() when timerStateChanged != null:
return timerStateChanged(_that);case BreakStartedIpcEvent() when breakStarted != null:
return breakStarted(_that);case BreakEndedIpcEvent() when breakEnded != null:
return breakEnded(_that);case CompanionInteractionIpcEvent() when companionInteraction != null:
return companionInteraction(_that);case MeetingDetectedIpcEvent() when meetingDetected != null:
return meetingDetected(_that);case TrayActionIpcEvent() when trayAction != null:
return trayAction(_that);case CompanionCloseIpcEvent() when companionClose != null:
return companionClose(_that);case CompanionPositionChangedIpcEvent() when companionPositionChanged != null:
return companionPositionChanged(_that);case CompanionStateChangedIpcEvent() when companionStateChanged != null:
return companionStateChanged(_that);case UnknownIpcEvent() when unknown != null:
return unknown(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String stateName,  int countdownSeconds,  int workElapsedSeconds,  int? targetEndTime,  int? totalWorkTodaySeconds)?  timerStateChanged,TResult Function( bool isLongBreak,  int durationSeconds,  String title)?  breakStarted,TResult Function( bool skipped)?  breakEnded,TResult Function( String interactionType,  Map<String, dynamic>? metadata)?  companionInteraction,TResult Function( bool isActive,  String bundleId)?  meetingDetected,TResult Function( String action)?  trayAction,TResult Function()?  companionClose,TResult Function( double x,  double y)?  companionPositionChanged,TResult Function( String state)?  companionStateChanged,TResult Function( String eventName,  Map<String, dynamic> payload)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TimerStateChangedIpcEvent() when timerStateChanged != null:
return timerStateChanged(_that.stateName,_that.countdownSeconds,_that.workElapsedSeconds,_that.targetEndTime,_that.totalWorkTodaySeconds);case BreakStartedIpcEvent() when breakStarted != null:
return breakStarted(_that.isLongBreak,_that.durationSeconds,_that.title);case BreakEndedIpcEvent() when breakEnded != null:
return breakEnded(_that.skipped);case CompanionInteractionIpcEvent() when companionInteraction != null:
return companionInteraction(_that.interactionType,_that.metadata);case MeetingDetectedIpcEvent() when meetingDetected != null:
return meetingDetected(_that.isActive,_that.bundleId);case TrayActionIpcEvent() when trayAction != null:
return trayAction(_that.action);case CompanionCloseIpcEvent() when companionClose != null:
return companionClose();case CompanionPositionChangedIpcEvent() when companionPositionChanged != null:
return companionPositionChanged(_that.x,_that.y);case CompanionStateChangedIpcEvent() when companionStateChanged != null:
return companionStateChanged(_that.state);case UnknownIpcEvent() when unknown != null:
return unknown(_that.eventName,_that.payload);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String stateName,  int countdownSeconds,  int workElapsedSeconds,  int? targetEndTime,  int? totalWorkTodaySeconds)  timerStateChanged,required TResult Function( bool isLongBreak,  int durationSeconds,  String title)  breakStarted,required TResult Function( bool skipped)  breakEnded,required TResult Function( String interactionType,  Map<String, dynamic>? metadata)  companionInteraction,required TResult Function( bool isActive,  String bundleId)  meetingDetected,required TResult Function( String action)  trayAction,required TResult Function()  companionClose,required TResult Function( double x,  double y)  companionPositionChanged,required TResult Function( String state)  companionStateChanged,required TResult Function( String eventName,  Map<String, dynamic> payload)  unknown,}) {final _that = this;
switch (_that) {
case TimerStateChangedIpcEvent():
return timerStateChanged(_that.stateName,_that.countdownSeconds,_that.workElapsedSeconds,_that.targetEndTime,_that.totalWorkTodaySeconds);case BreakStartedIpcEvent():
return breakStarted(_that.isLongBreak,_that.durationSeconds,_that.title);case BreakEndedIpcEvent():
return breakEnded(_that.skipped);case CompanionInteractionIpcEvent():
return companionInteraction(_that.interactionType,_that.metadata);case MeetingDetectedIpcEvent():
return meetingDetected(_that.isActive,_that.bundleId);case TrayActionIpcEvent():
return trayAction(_that.action);case CompanionCloseIpcEvent():
return companionClose();case CompanionPositionChangedIpcEvent():
return companionPositionChanged(_that.x,_that.y);case CompanionStateChangedIpcEvent():
return companionStateChanged(_that.state);case UnknownIpcEvent():
return unknown(_that.eventName,_that.payload);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String stateName,  int countdownSeconds,  int workElapsedSeconds,  int? targetEndTime,  int? totalWorkTodaySeconds)?  timerStateChanged,TResult? Function( bool isLongBreak,  int durationSeconds,  String title)?  breakStarted,TResult? Function( bool skipped)?  breakEnded,TResult? Function( String interactionType,  Map<String, dynamic>? metadata)?  companionInteraction,TResult? Function( bool isActive,  String bundleId)?  meetingDetected,TResult? Function( String action)?  trayAction,TResult? Function()?  companionClose,TResult? Function( double x,  double y)?  companionPositionChanged,TResult? Function( String state)?  companionStateChanged,TResult? Function( String eventName,  Map<String, dynamic> payload)?  unknown,}) {final _that = this;
switch (_that) {
case TimerStateChangedIpcEvent() when timerStateChanged != null:
return timerStateChanged(_that.stateName,_that.countdownSeconds,_that.workElapsedSeconds,_that.targetEndTime,_that.totalWorkTodaySeconds);case BreakStartedIpcEvent() when breakStarted != null:
return breakStarted(_that.isLongBreak,_that.durationSeconds,_that.title);case BreakEndedIpcEvent() when breakEnded != null:
return breakEnded(_that.skipped);case CompanionInteractionIpcEvent() when companionInteraction != null:
return companionInteraction(_that.interactionType,_that.metadata);case MeetingDetectedIpcEvent() when meetingDetected != null:
return meetingDetected(_that.isActive,_that.bundleId);case TrayActionIpcEvent() when trayAction != null:
return trayAction(_that.action);case CompanionCloseIpcEvent() when companionClose != null:
return companionClose();case CompanionPositionChangedIpcEvent() when companionPositionChanged != null:
return companionPositionChanged(_that.x,_that.y);case CompanionStateChangedIpcEvent() when companionStateChanged != null:
return companionStateChanged(_that.state);case UnknownIpcEvent() when unknown != null:
return unknown(_that.eventName,_that.payload);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class TimerStateChangedIpcEvent extends IpcEvent {
  const TimerStateChangedIpcEvent({required this.stateName, required this.countdownSeconds, required this.workElapsedSeconds, this.targetEndTime, this.totalWorkTodaySeconds, final  String? $type}): $type = $type ?? 'timerStateChanged',super._();
  factory TimerStateChangedIpcEvent.fromJson(Map<String, dynamic> json) => _$TimerStateChangedIpcEventFromJson(json);

 final  String stateName;
 final  int countdownSeconds;
 final  int workElapsedSeconds;
 final  int? targetEndTime;
 final  int? totalWorkTodaySeconds;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimerStateChangedIpcEventCopyWith<TimerStateChangedIpcEvent> get copyWith => _$TimerStateChangedIpcEventCopyWithImpl<TimerStateChangedIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimerStateChangedIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimerStateChangedIpcEvent&&(identical(other.stateName, stateName) || other.stateName == stateName)&&(identical(other.countdownSeconds, countdownSeconds) || other.countdownSeconds == countdownSeconds)&&(identical(other.workElapsedSeconds, workElapsedSeconds) || other.workElapsedSeconds == workElapsedSeconds)&&(identical(other.targetEndTime, targetEndTime) || other.targetEndTime == targetEndTime)&&(identical(other.totalWorkTodaySeconds, totalWorkTodaySeconds) || other.totalWorkTodaySeconds == totalWorkTodaySeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stateName,countdownSeconds,workElapsedSeconds,targetEndTime,totalWorkTodaySeconds);

@override
String toString() {
  return 'IpcEvent.timerStateChanged(stateName: $stateName, countdownSeconds: $countdownSeconds, workElapsedSeconds: $workElapsedSeconds, targetEndTime: $targetEndTime, totalWorkTodaySeconds: $totalWorkTodaySeconds)';
}


}

/// @nodoc
abstract mixin class $TimerStateChangedIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $TimerStateChangedIpcEventCopyWith(TimerStateChangedIpcEvent value, $Res Function(TimerStateChangedIpcEvent) _then) = _$TimerStateChangedIpcEventCopyWithImpl;
@useResult
$Res call({
 String stateName, int countdownSeconds, int workElapsedSeconds, int? targetEndTime, int? totalWorkTodaySeconds
});




}
/// @nodoc
class _$TimerStateChangedIpcEventCopyWithImpl<$Res>
    implements $TimerStateChangedIpcEventCopyWith<$Res> {
  _$TimerStateChangedIpcEventCopyWithImpl(this._self, this._then);

  final TimerStateChangedIpcEvent _self;
  final $Res Function(TimerStateChangedIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? stateName = null,Object? countdownSeconds = null,Object? workElapsedSeconds = null,Object? targetEndTime = freezed,Object? totalWorkTodaySeconds = freezed,}) {
  return _then(TimerStateChangedIpcEvent(
stateName: null == stateName ? _self.stateName : stateName // ignore: cast_nullable_to_non_nullable
as String,countdownSeconds: null == countdownSeconds ? _self.countdownSeconds : countdownSeconds // ignore: cast_nullable_to_non_nullable
as int,workElapsedSeconds: null == workElapsedSeconds ? _self.workElapsedSeconds : workElapsedSeconds // ignore: cast_nullable_to_non_nullable
as int,targetEndTime: freezed == targetEndTime ? _self.targetEndTime : targetEndTime // ignore: cast_nullable_to_non_nullable
as int?,totalWorkTodaySeconds: freezed == totalWorkTodaySeconds ? _self.totalWorkTodaySeconds : totalWorkTodaySeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class BreakStartedIpcEvent extends IpcEvent {
  const BreakStartedIpcEvent({required this.isLongBreak, required this.durationSeconds, required this.title, final  String? $type}): $type = $type ?? 'breakStarted',super._();
  factory BreakStartedIpcEvent.fromJson(Map<String, dynamic> json) => _$BreakStartedIpcEventFromJson(json);

 final  bool isLongBreak;
 final  int durationSeconds;
 final  String title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BreakStartedIpcEventCopyWith<BreakStartedIpcEvent> get copyWith => _$BreakStartedIpcEventCopyWithImpl<BreakStartedIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BreakStartedIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BreakStartedIpcEvent&&(identical(other.isLongBreak, isLongBreak) || other.isLongBreak == isLongBreak)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isLongBreak,durationSeconds,title);

@override
String toString() {
  return 'IpcEvent.breakStarted(isLongBreak: $isLongBreak, durationSeconds: $durationSeconds, title: $title)';
}


}

/// @nodoc
abstract mixin class $BreakStartedIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $BreakStartedIpcEventCopyWith(BreakStartedIpcEvent value, $Res Function(BreakStartedIpcEvent) _then) = _$BreakStartedIpcEventCopyWithImpl;
@useResult
$Res call({
 bool isLongBreak, int durationSeconds, String title
});




}
/// @nodoc
class _$BreakStartedIpcEventCopyWithImpl<$Res>
    implements $BreakStartedIpcEventCopyWith<$Res> {
  _$BreakStartedIpcEventCopyWithImpl(this._self, this._then);

  final BreakStartedIpcEvent _self;
  final $Res Function(BreakStartedIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? isLongBreak = null,Object? durationSeconds = null,Object? title = null,}) {
  return _then(BreakStartedIpcEvent(
isLongBreak: null == isLongBreak ? _self.isLongBreak : isLongBreak // ignore: cast_nullable_to_non_nullable
as bool,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class BreakEndedIpcEvent extends IpcEvent {
  const BreakEndedIpcEvent({required this.skipped, final  String? $type}): $type = $type ?? 'breakEnded',super._();
  factory BreakEndedIpcEvent.fromJson(Map<String, dynamic> json) => _$BreakEndedIpcEventFromJson(json);

 final  bool skipped;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BreakEndedIpcEventCopyWith<BreakEndedIpcEvent> get copyWith => _$BreakEndedIpcEventCopyWithImpl<BreakEndedIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BreakEndedIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BreakEndedIpcEvent&&(identical(other.skipped, skipped) || other.skipped == skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skipped);

@override
String toString() {
  return 'IpcEvent.breakEnded(skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class $BreakEndedIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $BreakEndedIpcEventCopyWith(BreakEndedIpcEvent value, $Res Function(BreakEndedIpcEvent) _then) = _$BreakEndedIpcEventCopyWithImpl;
@useResult
$Res call({
 bool skipped
});




}
/// @nodoc
class _$BreakEndedIpcEventCopyWithImpl<$Res>
    implements $BreakEndedIpcEventCopyWith<$Res> {
  _$BreakEndedIpcEventCopyWithImpl(this._self, this._then);

  final BreakEndedIpcEvent _self;
  final $Res Function(BreakEndedIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? skipped = null,}) {
  return _then(BreakEndedIpcEvent(
skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CompanionInteractionIpcEvent extends IpcEvent {
  const CompanionInteractionIpcEvent({required this.interactionType, final  Map<String, dynamic>? metadata, final  String? $type}): _metadata = metadata,$type = $type ?? 'companionInteraction',super._();
  factory CompanionInteractionIpcEvent.fromJson(Map<String, dynamic> json) => _$CompanionInteractionIpcEventFromJson(json);

 final  String interactionType;
 final  Map<String, dynamic>? _metadata;
 Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanionInteractionIpcEventCopyWith<CompanionInteractionIpcEvent> get copyWith => _$CompanionInteractionIpcEventCopyWithImpl<CompanionInteractionIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanionInteractionIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanionInteractionIpcEvent&&(identical(other.interactionType, interactionType) || other.interactionType == interactionType)&&const DeepCollectionEquality().equals(other._metadata, _metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,interactionType,const DeepCollectionEquality().hash(_metadata));

@override
String toString() {
  return 'IpcEvent.companionInteraction(interactionType: $interactionType, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $CompanionInteractionIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $CompanionInteractionIpcEventCopyWith(CompanionInteractionIpcEvent value, $Res Function(CompanionInteractionIpcEvent) _then) = _$CompanionInteractionIpcEventCopyWithImpl;
@useResult
$Res call({
 String interactionType, Map<String, dynamic>? metadata
});




}
/// @nodoc
class _$CompanionInteractionIpcEventCopyWithImpl<$Res>
    implements $CompanionInteractionIpcEventCopyWith<$Res> {
  _$CompanionInteractionIpcEventCopyWithImpl(this._self, this._then);

  final CompanionInteractionIpcEvent _self;
  final $Res Function(CompanionInteractionIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? interactionType = null,Object? metadata = freezed,}) {
  return _then(CompanionInteractionIpcEvent(
interactionType: null == interactionType ? _self.interactionType : interactionType // ignore: cast_nullable_to_non_nullable
as String,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MeetingDetectedIpcEvent extends IpcEvent {
  const MeetingDetectedIpcEvent({required this.isActive, required this.bundleId, final  String? $type}): $type = $type ?? 'meetingDetected',super._();
  factory MeetingDetectedIpcEvent.fromJson(Map<String, dynamic> json) => _$MeetingDetectedIpcEventFromJson(json);

 final  bool isActive;
 final  String bundleId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MeetingDetectedIpcEventCopyWith<MeetingDetectedIpcEvent> get copyWith => _$MeetingDetectedIpcEventCopyWithImpl<MeetingDetectedIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MeetingDetectedIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MeetingDetectedIpcEvent&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.bundleId, bundleId) || other.bundleId == bundleId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isActive,bundleId);

@override
String toString() {
  return 'IpcEvent.meetingDetected(isActive: $isActive, bundleId: $bundleId)';
}


}

/// @nodoc
abstract mixin class $MeetingDetectedIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $MeetingDetectedIpcEventCopyWith(MeetingDetectedIpcEvent value, $Res Function(MeetingDetectedIpcEvent) _then) = _$MeetingDetectedIpcEventCopyWithImpl;
@useResult
$Res call({
 bool isActive, String bundleId
});




}
/// @nodoc
class _$MeetingDetectedIpcEventCopyWithImpl<$Res>
    implements $MeetingDetectedIpcEventCopyWith<$Res> {
  _$MeetingDetectedIpcEventCopyWithImpl(this._self, this._then);

  final MeetingDetectedIpcEvent _self;
  final $Res Function(MeetingDetectedIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? isActive = null,Object? bundleId = null,}) {
  return _then(MeetingDetectedIpcEvent(
isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,bundleId: null == bundleId ? _self.bundleId : bundleId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class TrayActionIpcEvent extends IpcEvent {
  const TrayActionIpcEvent({required this.action, final  String? $type}): $type = $type ?? 'trayAction',super._();
  factory TrayActionIpcEvent.fromJson(Map<String, dynamic> json) => _$TrayActionIpcEventFromJson(json);

 final  String action;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrayActionIpcEventCopyWith<TrayActionIpcEvent> get copyWith => _$TrayActionIpcEventCopyWithImpl<TrayActionIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrayActionIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrayActionIpcEvent&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,action);

@override
String toString() {
  return 'IpcEvent.trayAction(action: $action)';
}


}

/// @nodoc
abstract mixin class $TrayActionIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $TrayActionIpcEventCopyWith(TrayActionIpcEvent value, $Res Function(TrayActionIpcEvent) _then) = _$TrayActionIpcEventCopyWithImpl;
@useResult
$Res call({
 String action
});




}
/// @nodoc
class _$TrayActionIpcEventCopyWithImpl<$Res>
    implements $TrayActionIpcEventCopyWith<$Res> {
  _$TrayActionIpcEventCopyWithImpl(this._self, this._then);

  final TrayActionIpcEvent _self;
  final $Res Function(TrayActionIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? action = null,}) {
  return _then(TrayActionIpcEvent(
action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CompanionCloseIpcEvent extends IpcEvent {
  const CompanionCloseIpcEvent({final  String? $type}): $type = $type ?? 'companionClose',super._();
  factory CompanionCloseIpcEvent.fromJson(Map<String, dynamic> json) => _$CompanionCloseIpcEventFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CompanionCloseIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanionCloseIpcEvent);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'IpcEvent.companionClose()';
}


}




/// @nodoc
@JsonSerializable()

class CompanionPositionChangedIpcEvent extends IpcEvent {
  const CompanionPositionChangedIpcEvent({required this.x, required this.y, final  String? $type}): $type = $type ?? 'companionPositionChanged',super._();
  factory CompanionPositionChangedIpcEvent.fromJson(Map<String, dynamic> json) => _$CompanionPositionChangedIpcEventFromJson(json);

 final  double x;
 final  double y;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanionPositionChangedIpcEventCopyWith<CompanionPositionChangedIpcEvent> get copyWith => _$CompanionPositionChangedIpcEventCopyWithImpl<CompanionPositionChangedIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanionPositionChangedIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanionPositionChangedIpcEvent&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,x,y);

@override
String toString() {
  return 'IpcEvent.companionPositionChanged(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class $CompanionPositionChangedIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $CompanionPositionChangedIpcEventCopyWith(CompanionPositionChangedIpcEvent value, $Res Function(CompanionPositionChangedIpcEvent) _then) = _$CompanionPositionChangedIpcEventCopyWithImpl;
@useResult
$Res call({
 double x, double y
});




}
/// @nodoc
class _$CompanionPositionChangedIpcEventCopyWithImpl<$Res>
    implements $CompanionPositionChangedIpcEventCopyWith<$Res> {
  _$CompanionPositionChangedIpcEventCopyWithImpl(this._self, this._then);

  final CompanionPositionChangedIpcEvent _self;
  final $Res Function(CompanionPositionChangedIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,}) {
  return _then(CompanionPositionChangedIpcEvent(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CompanionStateChangedIpcEvent extends IpcEvent {
  const CompanionStateChangedIpcEvent({required this.state, final  String? $type}): $type = $type ?? 'companionStateChanged',super._();
  factory CompanionStateChangedIpcEvent.fromJson(Map<String, dynamic> json) => _$CompanionStateChangedIpcEventFromJson(json);

 final  String state;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanionStateChangedIpcEventCopyWith<CompanionStateChangedIpcEvent> get copyWith => _$CompanionStateChangedIpcEventCopyWithImpl<CompanionStateChangedIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanionStateChangedIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanionStateChangedIpcEvent&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,state);

@override
String toString() {
  return 'IpcEvent.companionStateChanged(state: $state)';
}


}

/// @nodoc
abstract mixin class $CompanionStateChangedIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $CompanionStateChangedIpcEventCopyWith(CompanionStateChangedIpcEvent value, $Res Function(CompanionStateChangedIpcEvent) _then) = _$CompanionStateChangedIpcEventCopyWithImpl;
@useResult
$Res call({
 String state
});




}
/// @nodoc
class _$CompanionStateChangedIpcEventCopyWithImpl<$Res>
    implements $CompanionStateChangedIpcEventCopyWith<$Res> {
  _$CompanionStateChangedIpcEventCopyWithImpl(this._self, this._then);

  final CompanionStateChangedIpcEvent _self;
  final $Res Function(CompanionStateChangedIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(CompanionStateChangedIpcEvent(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class UnknownIpcEvent extends IpcEvent {
  const UnknownIpcEvent({required this.eventName, required final  Map<String, dynamic> payload, final  String? $type}): _payload = payload,$type = $type ?? 'unknown',super._();
  factory UnknownIpcEvent.fromJson(Map<String, dynamic> json) => _$UnknownIpcEventFromJson(json);

 final  String eventName;
 final  Map<String, dynamic> _payload;
 Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnknownIpcEventCopyWith<UnknownIpcEvent> get copyWith => _$UnknownIpcEventCopyWithImpl<UnknownIpcEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnknownIpcEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownIpcEvent&&(identical(other.eventName, eventName) || other.eventName == eventName)&&const DeepCollectionEquality().equals(other._payload, _payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventName,const DeepCollectionEquality().hash(_payload));

@override
String toString() {
  return 'IpcEvent.unknown(eventName: $eventName, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $UnknownIpcEventCopyWith<$Res> implements $IpcEventCopyWith<$Res> {
  factory $UnknownIpcEventCopyWith(UnknownIpcEvent value, $Res Function(UnknownIpcEvent) _then) = _$UnknownIpcEventCopyWithImpl;
@useResult
$Res call({
 String eventName, Map<String, dynamic> payload
});




}
/// @nodoc
class _$UnknownIpcEventCopyWithImpl<$Res>
    implements $UnknownIpcEventCopyWith<$Res> {
  _$UnknownIpcEventCopyWithImpl(this._self, this._then);

  final UnknownIpcEvent _self;
  final $Res Function(UnknownIpcEvent) _then;

/// Create a copy of IpcEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? eventName = null,Object? payload = null,}) {
  return _then(UnknownIpcEvent(
eventName: null == eventName ? _self.eventName : eventName // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
