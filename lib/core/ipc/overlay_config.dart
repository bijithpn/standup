import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_config.freezed.dart';
part 'overlay_config.g.dart';

@freezed
/// Appearance/behaviour settings pushed to the companion (pet) overlay window; null fields mean "leave unchanged".
sealed class OverlayConfig with _$OverlayConfig {
  const factory OverlayConfig({
    String? themeId,
    double? scale,
    String? companionToyType,
    String? companionTreatType,
    String? petName,
    bool? followMouse,
    bool? wanderingEnabled,
    String? state,
    Map<String, dynamic>? mouseFollow,

    String? avatarDefinitionJson,

    String? renderMode,

    bool? keepOnScreen,
    bool? clickThrough,
    String? pipBackgroundStyle,
    double? pipOpacity,
    bool? pipDraggableClickable,
    String? previewBackground,

    bool? pettingEnabled,
    bool? playEnabled,
    bool? treatEnabled,

    bool? gazeEnabled,
    double? gazeSensitivity,
    bool? idleAnimation,
    bool? reactionsEnabled,
    bool? reducedMotion,
    bool? animationsEnabled,
  }) = _OverlayConfig;

  factory OverlayConfig.fromJson(Map<String, dynamic> json) =>
      _$OverlayConfigFromJson(json);
}
