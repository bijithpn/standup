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
    // Whether a quickReminder may take over the whole screen as a full
    // poster, or must stay the small low-opacity pill. Computed on the main
    // engine (which has SettingsRepository and the meeting/presentation
    // detection services registered) and handed to the overlay's own,
    // separate Flutter isolate — that isolate only registers a minimal set
    // of services (see `overlayMain()`), so it cannot look any of this up
    // itself.
    @Default(false) bool allowFullPoster,
  }) = _OverlayWindowConfig;

  factory OverlayWindowConfig.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    if (normalized['overlayType'] == null && normalized['type'] != null) {
      normalized['overlayType'] = normalized['type'];
    }
    if (normalized['breakTemplate'] == null && normalized['template'] != null) {
      normalized['breakTemplate'] = normalized['template'];
    }
    return _$OverlayWindowConfigFromJson(normalized);
  }
}
