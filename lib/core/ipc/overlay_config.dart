import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_config.freezed.dart';
part 'overlay_config.g.dart';

@freezed
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
    bool? isOnBattery,
    bool? isAppActive,
    bool? isLowPowerMode,
    bool? clickThrough,
    String? pipBackgroundStyle,
    double? pipOpacity,
    bool? pipDraggableClickable,
    String? previewBackground,
  }) = _OverlayConfig;

  factory OverlayConfig.fromJson(Map<String, dynamic> json) =>
      _$OverlayConfigFromJson(json);
}
