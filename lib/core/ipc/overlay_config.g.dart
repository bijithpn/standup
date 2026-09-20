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
      isOnBattery: json['isOnBattery'] as bool?,
      isAppActive: json['isAppActive'] as bool?,
      isLowPowerMode: json['isLowPowerMode'] as bool?,
      clickThrough: json['clickThrough'] as bool?,
      pipBackgroundStyle: json['pipBackgroundStyle'] as String?,
      pipOpacity: (json['pipOpacity'] as num?)?.toDouble(),
      pipDraggableClickable: json['pipDraggableClickable'] as bool?,
      previewBackground: json['previewBackground'] as String?,
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
      'isOnBattery': instance.isOnBattery,
      'isAppActive': instance.isAppActive,
      'isLowPowerMode': instance.isLowPowerMode,
      'clickThrough': instance.clickThrough,
      'pipBackgroundStyle': instance.pipBackgroundStyle,
      'pipOpacity': instance.pipOpacity,
      'pipDraggableClickable': instance.pipDraggableClickable,
      'previewBackground': instance.previewBackground,
    };
