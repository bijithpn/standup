import 'package:freezed_annotation/freezed_annotation.dart';

part 'overlay_window_config.freezed.dart';
part 'overlay_window_config.g.dart';

@freezed
/// Everything the break overlay window needs to render a break, serialized by the main app and parsed in the overlay process.
abstract class OverlayWindowConfig with _$OverlayWindowConfig {
  const factory OverlayWindowConfig({
    @Default("Time for a Break") String title,
    @Default("Take a moment to stretch and breathe") String tip,
    @Default(300) int durationSeconds,
    @Default(300) int remainingSeconds,
    @Default('breakScreen') String overlayType,
    @Default(false) bool strictMode,
    @Default(true) bool enableAnimations,
    @Default(false) bool reduceMotion,
    @Default(false) bool largeText,
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
    @Default('dark') String overlayThemeMode,
    @Default('box') String breathPreset,
    @Default(false) bool lookedAwayPromptEnabled,
    String? customImagePath,
    String? exerciseTitle,
    String? exerciseInstructions,
    String? reminderType,
    int? breaksCompleted,
    int? targetEndTime,

    @Default(false) bool allowFullPoster,
  }) = _OverlayWindowConfig;

  factory OverlayWindowConfig.fromJson(Map<String, dynamic> json) =>
      _$OverlayWindowConfigFromJson(_normalize(json));
}

// Accepts legacy short keys ("type", "template") from older senders.
Map<String, dynamic> _normalize(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  if (normalized['overlayType'] == null && normalized['type'] != null) {
    normalized['overlayType'] = normalized['type'];
  }
  if (normalized['breakTemplate'] == null && normalized['template'] != null) {
    normalized['breakTemplate'] = normalized['template'];
  }
  return normalized;
}
