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

    /// The companion's full appearance, as JSON-encoded `AvatarDefinition`.
    ///
    /// The overlay windows run in their own engine, so a theme id alone is not
    /// enough — it loses the breed, palette, and seed the user picked, and the
    /// overlay would quietly fall back to the stock species. It travels as a
    /// string rather than a map because the same payload is relayed through
    /// C++ and Swift, where a flat string needs no per-field plumbing.
    String? avatarDefinitionJson,

    /// Which renderer the companion uses: `blob` or `artwork`.
    String? renderMode,

    /// Whether the companion stays on screen all the time.
    ///
    /// When false it only appears while a break is running and hides again
    /// afterwards, so the desktop is its own during focused work.
    bool? keepOnScreen,
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
