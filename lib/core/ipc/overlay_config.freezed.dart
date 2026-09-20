// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overlay_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OverlayConfig {

 String? get themeId; double? get scale; String? get companionToyType; String? get companionTreatType; String? get petName; bool? get followMouse; bool? get wanderingEnabled; String? get state; Map<String, dynamic>? get mouseFollow;/// The companion's full appearance, as JSON-encoded `AvatarDefinition`.
///
/// The overlay windows run in their own engine, so a theme id alone is not
/// enough — it loses the breed, palette, and seed the user picked, and the
/// overlay would quietly fall back to the stock species. It travels as a
/// string rather than a map because the same payload is relayed through
/// C++ and Swift, where a flat string needs no per-field plumbing.
 String? get avatarDefinitionJson;/// Which renderer the companion uses: `blob` or `artwork`.
 String? get renderMode;/// Whether the companion stays on screen all the time.
///
/// When false it only appears while a break is running and hides again
/// afterwards, so the desktop is its own during focused work.
 bool? get keepOnScreen; bool? get isOnBattery; bool? get isAppActive; bool? get isLowPowerMode; bool? get clickThrough; String? get pipBackgroundStyle; double? get pipOpacity; bool? get pipDraggableClickable; String? get previewBackground;
/// Create a copy of OverlayConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayConfigCopyWith<OverlayConfig> get copyWith => _$OverlayConfigCopyWithImpl<OverlayConfig>(this as OverlayConfig, _$identity);

  /// Serializes this OverlayConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayConfig&&(identical(other.themeId, themeId) || other.themeId == themeId)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.companionToyType, companionToyType) || other.companionToyType == companionToyType)&&(identical(other.companionTreatType, companionTreatType) || other.companionTreatType == companionTreatType)&&(identical(other.petName, petName) || other.petName == petName)&&(identical(other.followMouse, followMouse) || other.followMouse == followMouse)&&(identical(other.wanderingEnabled, wanderingEnabled) || other.wanderingEnabled == wanderingEnabled)&&(identical(other.state, state) || other.state == state)&&const DeepCollectionEquality().equals(other.mouseFollow, mouseFollow)&&(identical(other.avatarDefinitionJson, avatarDefinitionJson) || other.avatarDefinitionJson == avatarDefinitionJson)&&(identical(other.renderMode, renderMode) || other.renderMode == renderMode)&&(identical(other.keepOnScreen, keepOnScreen) || other.keepOnScreen == keepOnScreen)&&(identical(other.isOnBattery, isOnBattery) || other.isOnBattery == isOnBattery)&&(identical(other.isAppActive, isAppActive) || other.isAppActive == isAppActive)&&(identical(other.isLowPowerMode, isLowPowerMode) || other.isLowPowerMode == isLowPowerMode)&&(identical(other.clickThrough, clickThrough) || other.clickThrough == clickThrough)&&(identical(other.pipBackgroundStyle, pipBackgroundStyle) || other.pipBackgroundStyle == pipBackgroundStyle)&&(identical(other.pipOpacity, pipOpacity) || other.pipOpacity == pipOpacity)&&(identical(other.pipDraggableClickable, pipDraggableClickable) || other.pipDraggableClickable == pipDraggableClickable)&&(identical(other.previewBackground, previewBackground) || other.previewBackground == previewBackground));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,themeId,scale,companionToyType,companionTreatType,petName,followMouse,wanderingEnabled,state,const DeepCollectionEquality().hash(mouseFollow),avatarDefinitionJson,renderMode,keepOnScreen,isOnBattery,isAppActive,isLowPowerMode,clickThrough,pipBackgroundStyle,pipOpacity,pipDraggableClickable,previewBackground]);

@override
String toString() {
  return 'OverlayConfig(themeId: $themeId, scale: $scale, companionToyType: $companionToyType, companionTreatType: $companionTreatType, petName: $petName, followMouse: $followMouse, wanderingEnabled: $wanderingEnabled, state: $state, mouseFollow: $mouseFollow, avatarDefinitionJson: $avatarDefinitionJson, renderMode: $renderMode, keepOnScreen: $keepOnScreen, isOnBattery: $isOnBattery, isAppActive: $isAppActive, isLowPowerMode: $isLowPowerMode, clickThrough: $clickThrough, pipBackgroundStyle: $pipBackgroundStyle, pipOpacity: $pipOpacity, pipDraggableClickable: $pipDraggableClickable, previewBackground: $previewBackground)';
}


}

/// @nodoc
abstract mixin class $OverlayConfigCopyWith<$Res>  {
  factory $OverlayConfigCopyWith(OverlayConfig value, $Res Function(OverlayConfig) _then) = _$OverlayConfigCopyWithImpl;
@useResult
$Res call({
 String? themeId, double? scale, String? companionToyType, String? companionTreatType, String? petName, bool? followMouse, bool? wanderingEnabled, String? state, Map<String, dynamic>? mouseFollow, String? avatarDefinitionJson, String? renderMode, bool? keepOnScreen, bool? isOnBattery, bool? isAppActive, bool? isLowPowerMode, bool? clickThrough, String? pipBackgroundStyle, double? pipOpacity, bool? pipDraggableClickable, String? previewBackground
});




}
/// @nodoc
class _$OverlayConfigCopyWithImpl<$Res>
    implements $OverlayConfigCopyWith<$Res> {
  _$OverlayConfigCopyWithImpl(this._self, this._then);

  final OverlayConfig _self;
  final $Res Function(OverlayConfig) _then;

/// Create a copy of OverlayConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeId = freezed,Object? scale = freezed,Object? companionToyType = freezed,Object? companionTreatType = freezed,Object? petName = freezed,Object? followMouse = freezed,Object? wanderingEnabled = freezed,Object? state = freezed,Object? mouseFollow = freezed,Object? avatarDefinitionJson = freezed,Object? renderMode = freezed,Object? keepOnScreen = freezed,Object? isOnBattery = freezed,Object? isAppActive = freezed,Object? isLowPowerMode = freezed,Object? clickThrough = freezed,Object? pipBackgroundStyle = freezed,Object? pipOpacity = freezed,Object? pipDraggableClickable = freezed,Object? previewBackground = freezed,}) {
  return _then(_self.copyWith(
themeId: freezed == themeId ? _self.themeId : themeId // ignore: cast_nullable_to_non_nullable
as String?,scale: freezed == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double?,companionToyType: freezed == companionToyType ? _self.companionToyType : companionToyType // ignore: cast_nullable_to_non_nullable
as String?,companionTreatType: freezed == companionTreatType ? _self.companionTreatType : companionTreatType // ignore: cast_nullable_to_non_nullable
as String?,petName: freezed == petName ? _self.petName : petName // ignore: cast_nullable_to_non_nullable
as String?,followMouse: freezed == followMouse ? _self.followMouse : followMouse // ignore: cast_nullable_to_non_nullable
as bool?,wanderingEnabled: freezed == wanderingEnabled ? _self.wanderingEnabled : wanderingEnabled // ignore: cast_nullable_to_non_nullable
as bool?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,mouseFollow: freezed == mouseFollow ? _self.mouseFollow : mouseFollow // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,avatarDefinitionJson: freezed == avatarDefinitionJson ? _self.avatarDefinitionJson : avatarDefinitionJson // ignore: cast_nullable_to_non_nullable
as String?,renderMode: freezed == renderMode ? _self.renderMode : renderMode // ignore: cast_nullable_to_non_nullable
as String?,keepOnScreen: freezed == keepOnScreen ? _self.keepOnScreen : keepOnScreen // ignore: cast_nullable_to_non_nullable
as bool?,isOnBattery: freezed == isOnBattery ? _self.isOnBattery : isOnBattery // ignore: cast_nullable_to_non_nullable
as bool?,isAppActive: freezed == isAppActive ? _self.isAppActive : isAppActive // ignore: cast_nullable_to_non_nullable
as bool?,isLowPowerMode: freezed == isLowPowerMode ? _self.isLowPowerMode : isLowPowerMode // ignore: cast_nullable_to_non_nullable
as bool?,clickThrough: freezed == clickThrough ? _self.clickThrough : clickThrough // ignore: cast_nullable_to_non_nullable
as bool?,pipBackgroundStyle: freezed == pipBackgroundStyle ? _self.pipBackgroundStyle : pipBackgroundStyle // ignore: cast_nullable_to_non_nullable
as String?,pipOpacity: freezed == pipOpacity ? _self.pipOpacity : pipOpacity // ignore: cast_nullable_to_non_nullable
as double?,pipDraggableClickable: freezed == pipDraggableClickable ? _self.pipDraggableClickable : pipDraggableClickable // ignore: cast_nullable_to_non_nullable
as bool?,previewBackground: freezed == previewBackground ? _self.previewBackground : previewBackground // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OverlayConfig].
extension OverlayConfigPatterns on OverlayConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OverlayConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OverlayConfig() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OverlayConfig value)  $default,){
final _that = this;
switch (_that) {
case _OverlayConfig():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OverlayConfig value)?  $default,){
final _that = this;
switch (_that) {
case _OverlayConfig() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? themeId,  double? scale,  String? companionToyType,  String? companionTreatType,  String? petName,  bool? followMouse,  bool? wanderingEnabled,  String? state,  Map<String, dynamic>? mouseFollow,  String? avatarDefinitionJson,  String? renderMode,  bool? keepOnScreen,  bool? isOnBattery,  bool? isAppActive,  bool? isLowPowerMode,  bool? clickThrough,  String? pipBackgroundStyle,  double? pipOpacity,  bool? pipDraggableClickable,  String? previewBackground)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OverlayConfig() when $default != null:
return $default(_that.themeId,_that.scale,_that.companionToyType,_that.companionTreatType,_that.petName,_that.followMouse,_that.wanderingEnabled,_that.state,_that.mouseFollow,_that.avatarDefinitionJson,_that.renderMode,_that.keepOnScreen,_that.isOnBattery,_that.isAppActive,_that.isLowPowerMode,_that.clickThrough,_that.pipBackgroundStyle,_that.pipOpacity,_that.pipDraggableClickable,_that.previewBackground);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? themeId,  double? scale,  String? companionToyType,  String? companionTreatType,  String? petName,  bool? followMouse,  bool? wanderingEnabled,  String? state,  Map<String, dynamic>? mouseFollow,  String? avatarDefinitionJson,  String? renderMode,  bool? keepOnScreen,  bool? isOnBattery,  bool? isAppActive,  bool? isLowPowerMode,  bool? clickThrough,  String? pipBackgroundStyle,  double? pipOpacity,  bool? pipDraggableClickable,  String? previewBackground)  $default,) {final _that = this;
switch (_that) {
case _OverlayConfig():
return $default(_that.themeId,_that.scale,_that.companionToyType,_that.companionTreatType,_that.petName,_that.followMouse,_that.wanderingEnabled,_that.state,_that.mouseFollow,_that.avatarDefinitionJson,_that.renderMode,_that.keepOnScreen,_that.isOnBattery,_that.isAppActive,_that.isLowPowerMode,_that.clickThrough,_that.pipBackgroundStyle,_that.pipOpacity,_that.pipDraggableClickable,_that.previewBackground);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? themeId,  double? scale,  String? companionToyType,  String? companionTreatType,  String? petName,  bool? followMouse,  bool? wanderingEnabled,  String? state,  Map<String, dynamic>? mouseFollow,  String? avatarDefinitionJson,  String? renderMode,  bool? keepOnScreen,  bool? isOnBattery,  bool? isAppActive,  bool? isLowPowerMode,  bool? clickThrough,  String? pipBackgroundStyle,  double? pipOpacity,  bool? pipDraggableClickable,  String? previewBackground)?  $default,) {final _that = this;
switch (_that) {
case _OverlayConfig() when $default != null:
return $default(_that.themeId,_that.scale,_that.companionToyType,_that.companionTreatType,_that.petName,_that.followMouse,_that.wanderingEnabled,_that.state,_that.mouseFollow,_that.avatarDefinitionJson,_that.renderMode,_that.keepOnScreen,_that.isOnBattery,_that.isAppActive,_that.isLowPowerMode,_that.clickThrough,_that.pipBackgroundStyle,_that.pipOpacity,_that.pipDraggableClickable,_that.previewBackground);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OverlayConfig implements OverlayConfig {
  const _OverlayConfig({this.themeId, this.scale, this.companionToyType, this.companionTreatType, this.petName, this.followMouse, this.wanderingEnabled, this.state, final  Map<String, dynamic>? mouseFollow, this.avatarDefinitionJson, this.renderMode, this.keepOnScreen, this.isOnBattery, this.isAppActive, this.isLowPowerMode, this.clickThrough, this.pipBackgroundStyle, this.pipOpacity, this.pipDraggableClickable, this.previewBackground}): _mouseFollow = mouseFollow;
  factory _OverlayConfig.fromJson(Map<String, dynamic> json) => _$OverlayConfigFromJson(json);

@override final  String? themeId;
@override final  double? scale;
@override final  String? companionToyType;
@override final  String? companionTreatType;
@override final  String? petName;
@override final  bool? followMouse;
@override final  bool? wanderingEnabled;
@override final  String? state;
 final  Map<String, dynamic>? _mouseFollow;
@override Map<String, dynamic>? get mouseFollow {
  final value = _mouseFollow;
  if (value == null) return null;
  if (_mouseFollow is EqualUnmodifiableMapView) return _mouseFollow;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

/// The companion's full appearance, as JSON-encoded `AvatarDefinition`.
///
/// The overlay windows run in their own engine, so a theme id alone is not
/// enough — it loses the breed, palette, and seed the user picked, and the
/// overlay would quietly fall back to the stock species. It travels as a
/// string rather than a map because the same payload is relayed through
/// C++ and Swift, where a flat string needs no per-field plumbing.
@override final  String? avatarDefinitionJson;
/// Which renderer the companion uses: `blob` or `artwork`.
@override final  String? renderMode;
/// Whether the companion stays on screen all the time.
///
/// When false it only appears while a break is running and hides again
/// afterwards, so the desktop is its own during focused work.
@override final  bool? keepOnScreen;
@override final  bool? isOnBattery;
@override final  bool? isAppActive;
@override final  bool? isLowPowerMode;
@override final  bool? clickThrough;
@override final  String? pipBackgroundStyle;
@override final  double? pipOpacity;
@override final  bool? pipDraggableClickable;
@override final  String? previewBackground;

/// Create a copy of OverlayConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverlayConfigCopyWith<_OverlayConfig> get copyWith => __$OverlayConfigCopyWithImpl<_OverlayConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OverlayConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OverlayConfig&&(identical(other.themeId, themeId) || other.themeId == themeId)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.companionToyType, companionToyType) || other.companionToyType == companionToyType)&&(identical(other.companionTreatType, companionTreatType) || other.companionTreatType == companionTreatType)&&(identical(other.petName, petName) || other.petName == petName)&&(identical(other.followMouse, followMouse) || other.followMouse == followMouse)&&(identical(other.wanderingEnabled, wanderingEnabled) || other.wanderingEnabled == wanderingEnabled)&&(identical(other.state, state) || other.state == state)&&const DeepCollectionEquality().equals(other._mouseFollow, _mouseFollow)&&(identical(other.avatarDefinitionJson, avatarDefinitionJson) || other.avatarDefinitionJson == avatarDefinitionJson)&&(identical(other.renderMode, renderMode) || other.renderMode == renderMode)&&(identical(other.keepOnScreen, keepOnScreen) || other.keepOnScreen == keepOnScreen)&&(identical(other.isOnBattery, isOnBattery) || other.isOnBattery == isOnBattery)&&(identical(other.isAppActive, isAppActive) || other.isAppActive == isAppActive)&&(identical(other.isLowPowerMode, isLowPowerMode) || other.isLowPowerMode == isLowPowerMode)&&(identical(other.clickThrough, clickThrough) || other.clickThrough == clickThrough)&&(identical(other.pipBackgroundStyle, pipBackgroundStyle) || other.pipBackgroundStyle == pipBackgroundStyle)&&(identical(other.pipOpacity, pipOpacity) || other.pipOpacity == pipOpacity)&&(identical(other.pipDraggableClickable, pipDraggableClickable) || other.pipDraggableClickable == pipDraggableClickable)&&(identical(other.previewBackground, previewBackground) || other.previewBackground == previewBackground));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,themeId,scale,companionToyType,companionTreatType,petName,followMouse,wanderingEnabled,state,const DeepCollectionEquality().hash(_mouseFollow),avatarDefinitionJson,renderMode,keepOnScreen,isOnBattery,isAppActive,isLowPowerMode,clickThrough,pipBackgroundStyle,pipOpacity,pipDraggableClickable,previewBackground]);

@override
String toString() {
  return 'OverlayConfig(themeId: $themeId, scale: $scale, companionToyType: $companionToyType, companionTreatType: $companionTreatType, petName: $petName, followMouse: $followMouse, wanderingEnabled: $wanderingEnabled, state: $state, mouseFollow: $mouseFollow, avatarDefinitionJson: $avatarDefinitionJson, renderMode: $renderMode, keepOnScreen: $keepOnScreen, isOnBattery: $isOnBattery, isAppActive: $isAppActive, isLowPowerMode: $isLowPowerMode, clickThrough: $clickThrough, pipBackgroundStyle: $pipBackgroundStyle, pipOpacity: $pipOpacity, pipDraggableClickable: $pipDraggableClickable, previewBackground: $previewBackground)';
}


}

/// @nodoc
abstract mixin class _$OverlayConfigCopyWith<$Res> implements $OverlayConfigCopyWith<$Res> {
  factory _$OverlayConfigCopyWith(_OverlayConfig value, $Res Function(_OverlayConfig) _then) = __$OverlayConfigCopyWithImpl;
@override @useResult
$Res call({
 String? themeId, double? scale, String? companionToyType, String? companionTreatType, String? petName, bool? followMouse, bool? wanderingEnabled, String? state, Map<String, dynamic>? mouseFollow, String? avatarDefinitionJson, String? renderMode, bool? keepOnScreen, bool? isOnBattery, bool? isAppActive, bool? isLowPowerMode, bool? clickThrough, String? pipBackgroundStyle, double? pipOpacity, bool? pipDraggableClickable, String? previewBackground
});




}
/// @nodoc
class __$OverlayConfigCopyWithImpl<$Res>
    implements _$OverlayConfigCopyWith<$Res> {
  __$OverlayConfigCopyWithImpl(this._self, this._then);

  final _OverlayConfig _self;
  final $Res Function(_OverlayConfig) _then;

/// Create a copy of OverlayConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeId = freezed,Object? scale = freezed,Object? companionToyType = freezed,Object? companionTreatType = freezed,Object? petName = freezed,Object? followMouse = freezed,Object? wanderingEnabled = freezed,Object? state = freezed,Object? mouseFollow = freezed,Object? avatarDefinitionJson = freezed,Object? renderMode = freezed,Object? keepOnScreen = freezed,Object? isOnBattery = freezed,Object? isAppActive = freezed,Object? isLowPowerMode = freezed,Object? clickThrough = freezed,Object? pipBackgroundStyle = freezed,Object? pipOpacity = freezed,Object? pipDraggableClickable = freezed,Object? previewBackground = freezed,}) {
  return _then(_OverlayConfig(
themeId: freezed == themeId ? _self.themeId : themeId // ignore: cast_nullable_to_non_nullable
as String?,scale: freezed == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double?,companionToyType: freezed == companionToyType ? _self.companionToyType : companionToyType // ignore: cast_nullable_to_non_nullable
as String?,companionTreatType: freezed == companionTreatType ? _self.companionTreatType : companionTreatType // ignore: cast_nullable_to_non_nullable
as String?,petName: freezed == petName ? _self.petName : petName // ignore: cast_nullable_to_non_nullable
as String?,followMouse: freezed == followMouse ? _self.followMouse : followMouse // ignore: cast_nullable_to_non_nullable
as bool?,wanderingEnabled: freezed == wanderingEnabled ? _self.wanderingEnabled : wanderingEnabled // ignore: cast_nullable_to_non_nullable
as bool?,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,mouseFollow: freezed == mouseFollow ? _self._mouseFollow : mouseFollow // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,avatarDefinitionJson: freezed == avatarDefinitionJson ? _self.avatarDefinitionJson : avatarDefinitionJson // ignore: cast_nullable_to_non_nullable
as String?,renderMode: freezed == renderMode ? _self.renderMode : renderMode // ignore: cast_nullable_to_non_nullable
as String?,keepOnScreen: freezed == keepOnScreen ? _self.keepOnScreen : keepOnScreen // ignore: cast_nullable_to_non_nullable
as bool?,isOnBattery: freezed == isOnBattery ? _self.isOnBattery : isOnBattery // ignore: cast_nullable_to_non_nullable
as bool?,isAppActive: freezed == isAppActive ? _self.isAppActive : isAppActive // ignore: cast_nullable_to_non_nullable
as bool?,isLowPowerMode: freezed == isLowPowerMode ? _self.isLowPowerMode : isLowPowerMode // ignore: cast_nullable_to_non_nullable
as bool?,clickThrough: freezed == clickThrough ? _self.clickThrough : clickThrough // ignore: cast_nullable_to_non_nullable
as bool?,pipBackgroundStyle: freezed == pipBackgroundStyle ? _self.pipBackgroundStyle : pipBackgroundStyle // ignore: cast_nullable_to_non_nullable
as String?,pipOpacity: freezed == pipOpacity ? _self.pipOpacity : pipOpacity // ignore: cast_nullable_to_non_nullable
as double?,pipDraggableClickable: freezed == pipDraggableClickable ? _self.pipDraggableClickable : pipDraggableClickable // ignore: cast_nullable_to_non_nullable
as bool?,previewBackground: freezed == previewBackground ? _self.previewBackground : previewBackground // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
