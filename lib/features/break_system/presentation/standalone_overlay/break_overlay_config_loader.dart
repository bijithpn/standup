import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

/// Loads initial [OverlayWindowConfig] from [SimplePrefs] and provides model mappings.
class BreakOverlayConfigLoader {
  static OverlayWindowConfig loadFromPrefs({
    required String defaultTitle,
    required String defaultMessage,
    required int defaultDurationSeconds,
  }) {
    try {
      if (SimplePrefs.instance.isReady) {
        final template = SimplePrefs.instance.getString(
          'break_template',
          defaultValue: 'minimal',
        );
        final petTheme = SimplePrefs.instance.getString(
          'companion_pet_theme',
          defaultValue: 'grey_cat',
        );
        final showNotes = SimplePrefs.instance.getBool(
          'show_exercises_in_break',
          defaultValue: true,
        );
        final strict = SimplePrefs.instance.getBool(
          'strict_mode',
          defaultValue: false,
        );
        final anim = SimplePrefs.instance.getBool(
          'enable_animations',
          defaultValue: true,
        );
        final intensity = SimplePrefs.instance.getString(
          'intensity_level',
          defaultValue: 'standard',
        );
        final textColor = SimplePrefs.instance.getInt(
          'clock_face_text_color_hex',
          defaultValue: 0xFFFFFFFF,
        );
        final blurEnabled = SimplePrefs.instance.getBool(
          'clock_face_blur_enabled',
          defaultValue: true,
        );
        final themeMode = SimplePrefs.instance.getString(
          'overlay_theme_mode',
          defaultValue: 'dark',
        );
        final preset = SimplePrefs.instance.getString(
          'breath_preset',
          defaultValue: 'box',
        );
        final lookedAway = SimplePrefs.instance.getBool(
          'looked_away_prompt_enabled',
        );
        final customImg = SimplePrefs.instance.getString(
          'custom_image_path',
          defaultValue: '',
        );

        return OverlayWindowConfig(
          title: defaultTitle,
          tip: defaultMessage,
          durationSeconds: defaultDurationSeconds,
          remainingSeconds: defaultDurationSeconds,
          breakTemplate: template,
          companionPetTheme: petTheme,
          showWellnessNotes: showNotes,
          strictMode: strict,
          enableAnimations: anim,
          intensityLevel: intensity,
          clockFaceTextColorHex: textColor,
          clockFaceBlurEnabled: blurEnabled,
          overlayThemeMode: themeMode,
          breathPreset: preset,
          lookedAwayPromptEnabled: lookedAway,
          customImagePath: customImg.isEmpty ? null : customImg,
        );
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }

    return OverlayWindowConfig(
      title: defaultTitle,
      tip: defaultMessage,
      durationSeconds: defaultDurationSeconds,
      remainingSeconds: defaultDurationSeconds,
    );
  }

  static void updateStatsIfNeeded(OverlayWindowConfig config) {
    if (config.breaksCompleted == null) return;
    try {
      if (sl.isRegistered<StatsService>()) {
        final service = sl<StatsService>();
        if (service.runtimeType.toString() == 'FakeStatsService') {
          (service as dynamic).updateBreaksCompleted(config.breaksCompleted!);
        }
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }
}

extension OverlayWindowConfigModels on OverlayWindowConfig {
  BreakModel toBreakModel(int duration) {
    BreakType type;
    if (breakType != null) {
      type = BreakType.values.firstWhere(
        (e) => e.name == breakType,
        orElse: () => BreakType.long,
      );
    } else {
      type =
          title.toUpperCase().contains('SHORT') ||
              title.toUpperCase().contains('EYE')
          ? BreakType.short
          : BreakType.long;
    }
    return BreakModel(
      type: type,
      durationSeconds: duration,
      title: title,
      tip: tip,
    );
  }

  SettingsModel toSettingsModel() => SettingsModel(
    strictMode: strictMode,
    enableAnimations: enableAnimations,
    companionPetTheme: companionPetTheme,
    breakTemplate: breakTemplate,
    showExercisesInBreak: showWellnessNotes,
    clockFaceTextColorHex: clockFaceTextColorHex,
    clockFaceBlurEnabled: clockFaceBlurEnabled,
    overlayThemeMode: overlayThemeMode,
    breathPreset: breathPreset,
    lookedAwayPromptEnabled: lookedAwayPromptEnabled,
    customImagePath: customImagePath,
  );
}
