import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_window_config.freezed.dart';
part 'overlay_window_config.g.dart';

@freezed
abstract class OverlayWindowConfig with _$OverlayWindowConfig {
  const factory OverlayWindowConfig({
    @Default("Time for a Break") String title,
    @Default("Take a moment to stretch and breathe") String tip,
    @Default(300) int durationSeconds,
    @Default(300) int remainingSeconds,
    @Default('breakScreen') String overlayType,
    @Default(false) bool strictMode,
    @Default(true) bool enableAnimations,
    @Default('standard') String intensityLevel,
    @Default(true) bool showWellnessNotes,
    @Default(false) bool isPreview,
    String? breakType,
    String? theme,
    String? classicImage,
    @Default('minimal') String breakTemplate,
    @Default('grey_cat') String companionPetTheme,
    @Default(0xFFFFFFFF) int clockFaceTextColorHex,
    @Default(true) bool clockFaceBlurEnabled,
    String? customImagePath,
    String? exerciseTitle,
    String? exerciseInstructions,
    String? reminderType,
    int? breaksCompleted,
    int? targetEndTime,
  }) = _OverlayWindowConfig;

  factory OverlayWindowConfig.fromJson(Map<String, dynamic> json) =>
      _$OverlayWindowConfigFromJson(json);
}
