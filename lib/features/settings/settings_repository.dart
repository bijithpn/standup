import 'package:standup/core/services/storage_service.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/core/constants/app_constants.dart';

class SettingsRepository {
  final StorageService _storage;
  SettingsModel _current = const SettingsModel();

  SettingsRepository({required StorageService storage}) : _storage = storage;

  SettingsModel get currentSettings => _current;

  void load() {
    _current = SettingsModel(
      shortBreakIntervalMinutes: _storage.getInt(
        AppConstants.keyShortBreakInterval,
        defaultValue: AppConstants.defaultShortBreakIntervalMinutes,
      ),
      shortBreakDurationSeconds: _storage.getInt(
        AppConstants.keyShortBreakDuration,
        defaultValue: AppConstants.defaultShortBreakDurationSeconds,
      ),
      longBreakIntervalMinutes: _storage.getInt(
        AppConstants.keyLongBreakInterval,
        defaultValue: AppConstants.defaultLongBreakIntervalMinutes,
      ),
      longBreakDurationMinutes: _storage.getInt(
        AppConstants.keyLongBreakDuration,
        defaultValue: AppConstants.defaultLongBreakDurationMinutes,
      ),
      soundEnabled: _storage.getBool(
        AppConstants.keySoundEnabled,
        defaultValue: true,
      ),
      autoStart: _storage.getBool(AppConstants.keyAutoStart),
      strictMode: _storage.getBool(AppConstants.keyStrictMode),
      selectedProfileId: _storage.getString('selected_profile_id', defaultValue: 'health'),
      menuBarStyle: _storage.getString('menu_bar_style', defaultValue: 'countdown'),
      
      flashColorHex: _storage.getInt(
        'flash_color_hex',
        defaultValue: 0xFFF87171,
      ),
      flashStyle: _storage.getString('flash_style', defaultValue: 'default'),
      flashMessage: _storage.getString(
        'flash_message',
        defaultValue: 'Take a deep breath',
      ),
      flashAnimationType: _storage.getString('flash_animation_type', defaultValue: 'pulse'),
      flashIntensity: _storage.getDouble('flash_intensity', defaultValue: 0.5),
      flashDurationMs: _storage.getInt('flash_duration_ms', defaultValue: 2500),
      focusModeEnabled: _storage.getBool('focus_mode_enabled'),
      clockFaceStyle: _storage.getString(
        'clock_face_style',
        defaultValue: 'breakloop',
      ),
      clockFaceTextColorHex: _storage.getInt(
        'clock_face_text_color_hex',
        defaultValue: 0xFFFFFFFF,
      ),
      clockFaceBlurEnabled: _storage.getBool(
        'clock_face_blur_enabled',
        defaultValue: true,
      ),
      customImagePath: _storage.getString('custom_image_path'),
      pauseTimerAfterMinutes: _storage.getInt(
        'pause_timer_after_minutes',
        defaultValue: 1,
      ),
      resetTimerAfterMinutes: _storage.getInt(
        'reset_timer_after_minutes',
        defaultValue: 5,
      ),
      workingHoursEnabled: _storage.getBool('working_hours_enabled'),
      dailyWorkGoalHours: _storage.getInt('daily_work_goal_hours', defaultValue: 8),
      remindClockOutEnabled: _storage.getBool('remind_clock_out_enabled', defaultValue: true),
    );
  }

  Future<void> save(SettingsModel settings) async {
    _current = settings;
    await Future.wait([
      _storage.setInt(
        AppConstants.keyShortBreakInterval,
        settings.shortBreakIntervalMinutes,
      ),
      _storage.setInt(
        AppConstants.keyShortBreakDuration,
        settings.shortBreakDurationSeconds,
      ),
      _storage.setInt(
        AppConstants.keyLongBreakInterval,
        settings.longBreakIntervalMinutes,
      ),
      _storage.setInt(
        AppConstants.keyLongBreakDuration,
        settings.longBreakDurationMinutes,
      ),
      _storage.setBool(AppConstants.keySoundEnabled, settings.soundEnabled),
      _storage.setBool(AppConstants.keyAutoStart, settings.autoStart),
      _storage.setBool(AppConstants.keyStrictMode, settings.strictMode),
      _storage.setString('selected_profile_id', settings.selectedProfileId),
      _storage.setString('menu_bar_style', settings.menuBarStyle),
      
      _storage.setInt('flash_color_hex', settings.flashColorHex),
      _storage.setString('flash_style', settings.flashStyle),
      _storage.setString('flash_message', settings.flashMessage),
      _storage.setString('flash_animation_type', settings.flashAnimationType),
      _storage.setDouble('flash_intensity', settings.flashIntensity),
      _storage.setInt('flash_duration_ms', settings.flashDurationMs),
      _storage.setBool('focus_mode_enabled', settings.focusModeEnabled),
      _storage.setString('clock_face_style', settings.clockFaceStyle),
      _storage.setInt(
        'clock_face_text_color_hex',
        settings.clockFaceTextColorHex,
      ),
      _storage.setBool(
        'clock_face_blur_enabled',
        settings.clockFaceBlurEnabled,
      ),
      if (settings.customImagePath != null)
        _storage.setString('custom_image_path', settings.customImagePath!),
      _storage.setInt(
        'pause_timer_after_minutes',
        settings.pauseTimerAfterMinutes,
      ),
      _storage.setInt(
        'reset_timer_after_minutes',
        settings.resetTimerAfterMinutes,
      ),
      _storage.setBool('working_hours_enabled', settings.workingHoursEnabled),
      _storage.setBool('auto_suggest_exercises', settings.autoSuggestExercises),
      _storage.setInt('daily_work_goal_hours', settings.dailyWorkGoalHours),
      _storage.setBool(
        'remind_clock_out_enabled',
        settings.remindClockOutEnabled,
      ),
    ]);
  }
}
