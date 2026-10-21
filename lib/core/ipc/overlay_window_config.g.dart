// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_window_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OverlayWindowConfig _$OverlayWindowConfigFromJson(Map<String, dynamic> json) =>
    _OverlayWindowConfig(
      title: json['title'] as String? ?? "Time for a Break",
      tip: json['tip'] as String? ?? "Take a moment to stretch and breathe",
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 300,
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 300,
      overlayType: json['overlayType'] as String? ?? 'breakScreen',
      strictMode: json['strictMode'] as bool? ?? false,
      enableAnimations: json['enableAnimations'] as bool? ?? true,
      intensityLevel: json['intensityLevel'] as String? ?? 'standard',
      showWellnessNotes: json['showWellnessNotes'] as bool? ?? true,
      isPreview: json['isPreview'] as bool? ?? false,
      breakType: json['breakType'] as String?,
      theme: json['theme'] as String?,
      classicImage: json['classicImage'] as String?,
      breakTemplate: json['breakTemplate'] as String? ?? 'minimal',
      companionPetTheme: json['companionPetTheme'] as String? ?? 'grey_cat',
      clockFaceTextColorHex:
          (json['clockFaceTextColorHex'] as num?)?.toInt() ?? 0xFFFFFFFF,
      clockFaceBlurEnabled: json['clockFaceBlurEnabled'] as bool? ?? true,
      customImagePath: json['customImagePath'] as String?,
      exerciseTitle: json['exerciseTitle'] as String?,
      exerciseInstructions: json['exerciseInstructions'] as String?,
      reminderType: json['reminderType'] as String?,
      breaksCompleted: (json['breaksCompleted'] as num?)?.toInt(),
      targetEndTime: (json['targetEndTime'] as num?)?.toInt(),
      allowFullPoster: json['allowFullPoster'] as bool? ?? false,
    );

Map<String, dynamic> _$OverlayWindowConfigToJson(
  _OverlayWindowConfig instance,
) => <String, dynamic>{
  'title': instance.title,
  'tip': instance.tip,
  'durationSeconds': instance.durationSeconds,
  'remainingSeconds': instance.remainingSeconds,
  'overlayType': instance.overlayType,
  'strictMode': instance.strictMode,
  'enableAnimations': instance.enableAnimations,
  'intensityLevel': instance.intensityLevel,
  'showWellnessNotes': instance.showWellnessNotes,
  'isPreview': instance.isPreview,
  'breakType': instance.breakType,
  'theme': instance.theme,
  'classicImage': instance.classicImage,
  'breakTemplate': instance.breakTemplate,
  'companionPetTheme': instance.companionPetTheme,
  'clockFaceTextColorHex': instance.clockFaceTextColorHex,
  'clockFaceBlurEnabled': instance.clockFaceBlurEnabled,
  'customImagePath': instance.customImagePath,
  'exerciseTitle': instance.exerciseTitle,
  'exerciseInstructions': instance.exerciseInstructions,
  'reminderType': instance.reminderType,
  'breaksCompleted': instance.breaksCompleted,
  'targetEndTime': instance.targetEndTime,
  'allowFullPoster': instance.allowFullPoster,
};
