// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OverlayConfig _$OverlayConfigFromJson(Map<String, dynamic> json) =>
    _OverlayConfig(
      themeId: json['themeId'] as String?,
      scale: (json['scale'] as num?)?.toDouble(),
      companionToyType: json['companionToyType'] as String?,
      companionTreatType: json['companionTreatType'] as String?,
      petName: json['petName'] as String?,
      followMouse: json['followMouse'] as bool?,
      wanderingEnabled: json['wanderingEnabled'] as bool?,
      state: json['state'] as String?,
      mouseFollow: json['mouseFollow'] as Map<String, dynamic>?,
      avatarDefinitionJson: json['avatarDefinitionJson'] as String?,
      renderMode: json['renderMode'] as String?,
      keepOnScreen: json['keepOnScreen'] as bool?,
      clickThrough: json['clickThrough'] as bool?,
      pipBackgroundStyle: json['pipBackgroundStyle'] as String?,
      pipOpacity: (json['pipOpacity'] as num?)?.toDouble(),
      pipDraggableClickable: json['pipDraggableClickable'] as bool?,
      previewBackground: json['previewBackground'] as String?,
      pettingEnabled: json['pettingEnabled'] as bool?,
      playEnabled: json['playEnabled'] as bool?,
      treatEnabled: json['treatEnabled'] as bool?,
      gazeEnabled: json['gazeEnabled'] as bool?,
      gazeSensitivity: (json['gazeSensitivity'] as num?)?.toDouble(),
      idleAnimation: json['idleAnimation'] as bool?,
      reactionsEnabled: json['reactionsEnabled'] as bool?,
      reducedMotion: json['reducedMotion'] as bool?,
      animationsEnabled: json['animationsEnabled'] as bool?,
    );

Map<String, dynamic> _$OverlayConfigToJson(_OverlayConfig instance) =>
    <String, dynamic>{
      'themeId': instance.themeId,
      'scale': instance.scale,
      'companionToyType': instance.companionToyType,
      'companionTreatType': instance.companionTreatType,
      'petName': instance.petName,
      'followMouse': instance.followMouse,
      'wanderingEnabled': instance.wanderingEnabled,
      'state': instance.state,
      'mouseFollow': instance.mouseFollow,
      'avatarDefinitionJson': instance.avatarDefinitionJson,
      'renderMode': instance.renderMode,
      'keepOnScreen': instance.keepOnScreen,
      'clickThrough': instance.clickThrough,
      'pipBackgroundStyle': instance.pipBackgroundStyle,
      'pipOpacity': instance.pipOpacity,
      'pipDraggableClickable': instance.pipDraggableClickable,
      'previewBackground': instance.previewBackground,
      'pettingEnabled': instance.pettingEnabled,
      'playEnabled': instance.playEnabled,
      'treatEnabled': instance.treatEnabled,
      'gazeEnabled': instance.gazeEnabled,
      'gazeSensitivity': instance.gazeSensitivity,
      'idleAnimation': instance.idleAnimation,
      'reactionsEnabled': instance.reactionsEnabled,
      'reducedMotion': instance.reducedMotion,
      'animationsEnabled': instance.animationsEnabled,
    };
