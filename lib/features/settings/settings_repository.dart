import 'dart:convert';

import 'package:standup/core/services/storage_service.dart';
import 'package:standup/features/settings/exercise_model.dart';
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
      notificationsEnabled: _storage.getBool('notifications_enabled', defaultValue: true),
      showOnAllDisplays: _storage.getBool('show_on_all_displays', defaultValue: true),
      breakTheme: _storage.getString('break_theme', defaultValue: 'random'),
      breakTemplate: _storage.getString('break_template', defaultValue: 'minimal'),
      

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
        defaultValue: 5,
      ),
      resetTimerAfterMinutes: _storage.getInt(
        'reset_timer_after_minutes',
        defaultValue: 15,
      ),
      workingHoursEnabled: _storage.getBool('working_hours_enabled'),
      workingDays: _decodeIntList(
        _storage.getString('working_days'),
        fallback: const [1, 2, 3, 4, 5],
      ),
      workStartTime: _storage.getString('work_start_time', defaultValue: '09:00'),
      workEndTime: _storage.getString('work_end_time', defaultValue: '18:00'),
      detectVideoCalls: _storage.getBool('detect_video_calls', defaultValue: true),
      detectMeetings: _storage.getBool('detect_meetings', defaultValue: true),
      respectFocusMode: _storage.getBool('respect_focus_mode', defaultValue: true),
      enableClockOut: _storage.getBool('enable_clock_out', defaultValue: false),
      clockOutTime: _storage.getString('clock_out_time', defaultValue: '17:00'),
      exercises: _loadExercises(),
      autoSuggestExercises: _storage.getBool(
        'auto_suggest_exercises',
        defaultValue: true,
      ),
      useCursorCountdown: _storage.getBool('use_cursor_countdown', defaultValue: true),
      trayIconStyle: _storage.getString('tray_icon_style', defaultValue: 'companion') == 'cat' ? 'companion' : _storage.getString('tray_icon_style', defaultValue: 'companion'),
      dailyWorkGoalHours: _storage.getInt('daily_work_goal_hours', defaultValue: 8),
      remindClockOutEnabled: _storage.getBool('remind_clock_out_enabled', defaultValue: true),
      companionEnabled: _storage.getBool('companion_enabled', defaultValue: true),
      companionPetTheme: _storage.getString('companion_cat_theme', defaultValue: 'grey_cat'),
      companionPetName: _storage.getString('companion_pet_name', defaultValue: 'Mochi'),
      companionScale: _storage.getDouble('companion_scale', defaultValue: 1.5),
      companionClickThrough: _storage.getBool('companion_click_through', defaultValue: false),
      companionFollowMouse: _storage.getBool('companion_follow_mouse', defaultValue: false),
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
      _storage.setBool('notifications_enabled', settings.notificationsEnabled),
      _storage.setBool('show_on_all_displays', settings.showOnAllDisplays),
      _storage.setString('break_theme', settings.breakTheme),
      _storage.setString('break_template', settings.breakTemplate),
      

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
      _storage.setString('working_days', jsonEncode(settings.workingDays)),
      _storage.setString('work_start_time', settings.workStartTime),
      _storage.setString('work_end_time', settings.workEndTime),
      _storage.setBool('detect_video_calls', settings.detectVideoCalls),
      _storage.setBool('detect_meetings', settings.detectMeetings),
      _storage.setBool('respect_focus_mode', settings.respectFocusMode),
      _storage.setBool('enable_clock_out', settings.enableClockOut),
      _storage.setString('clock_out_time', settings.clockOutTime),
      _storage.setString(
        'exercises',
        jsonEncode(settings.exercises.map((e) => e.toMap()).toList()),
      ),
      _storage.setBool('auto_suggest_exercises', settings.autoSuggestExercises),
      _storage.setBool('use_cursor_countdown', settings.useCursorCountdown),
      _storage.setString('tray_icon_style', settings.trayIconStyle),
      _storage.setInt('daily_work_goal_hours', settings.dailyWorkGoalHours),
      _storage.setBool(
        'remind_clock_out_enabled',
        settings.remindClockOutEnabled,
      ),
      _storage.setBool('companion_enabled', settings.companionEnabled),
      _storage.setString('companion_cat_theme', settings.companionPetTheme),
      _storage.setString('companion_pet_name', settings.companionPetName),
      _storage.setDouble('companion_scale', settings.companionScale),
      _storage.setBool('companion_click_through', settings.companionClickThrough),
      _storage.setBool('companion_follow_mouse', settings.companionFollowMouse),
    ]);
  }

  List<int> _decodeIntList(String raw, {required List<int> fallback}) {
    if (raw.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return fallback;
      return decoded.whereType<num>().map((e) => e.toInt()).toList();
    } catch (_) {
      return fallback;
    }
  }

  List<ExerciseModel> _loadExercises() {
    final raw = _storage.getString('exercises');
    if (raw.isEmpty) return ExerciseModel.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return ExerciseModel.defaults;
      final exercises = decoded
          .whereType<Map<String, dynamic>>()
          .map(ExerciseModel.fromMap)
          .toList();
      return exercises.isEmpty ? ExerciseModel.defaults : exercises;
    } catch (_) {
      return ExerciseModel.defaults;
    }
  }
}
