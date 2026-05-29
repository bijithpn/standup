import 'dart:convert';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';

class SettingsRepository extends ChangeNotifier {
  final StorageService _storage;
  SettingsModel _current = const SettingsModel();

  SettingsRepository({required StorageService storage}) : _storage = storage;

  SettingsModel get currentSettings => _current;

  void load() {
    final snapshot = _storage.settingsBox?.get(1);
    final companionPrefs = _storage.companionPreferencesBox?.get(1);

    if (snapshot != null) {
      _current = _fromSnapshot(snapshot, companionPrefs);
    } else {
      _current = _loadFromLegacy();
      if (_storage.isReady) {
        save(_current);
      }
    }
  }

  SettingsModel _fromSnapshot(SettingsSnapshot s, CompanionPreferences? cp) {
    return SettingsModel(
      autoStart: s.autoStart,
      clockFaceStyle: s.clockFaceStyle,
      selectedProfileId: s.selectedProfileId,
      strictMode: s.strictMode,
      remindClockOutEnabled: s.remindClockOutEnabled,
      dailyWorkGoalHours: s.dailyWorkGoalHours,
      pauseTimerAfterMinutes: s.pauseTimerAfterMinutes,
      menuBarStyle: s.menuBarStyle,
      focusModeEnabled: s.focusModeEnabled,
      shortBreakIntervalMinutes: s.shortBreakIntervalMinutes,
      shortBreakDurationSeconds: s.shortBreakDurationSeconds,
      preBreakWarningSeconds: s.preBreakWarningSeconds,
      longBreakIntervalMinutes: s.longBreakIntervalMinutes,
      longBreakDurationMinutes: s.longBreakDurationMinutes,
      soundEnabled: s.soundEnabled,
      notificationsEnabled: s.notificationsEnabled,
      postureReminderEnabled: s.postureReminderEnabled,
      postureReminderIntervalMinutes: s.postureReminderIntervalMinutes,
      postureReminderType: s.postureReminderType,
      eyeBlinkReminderEnabled: s.eyeBlinkReminderEnabled,
      eyeBlinkReminderIntervalMinutes: s.eyeBlinkReminderIntervalMinutes,
      eyeBlinkReminderType: s.eyeBlinkReminderType,
      showOnAllDisplays: s.showOnAllDisplays,
      breakTheme: s.breakTheme,
      breakTemplate: s.breakTemplate,
      showExercisesInBreak: s.showExercisesInBreak,
      lastExerciseDate: s.lastExerciseDate,
      shownExercisesToday: List<String>.from(
        jsonDecode(s.shownExercisesTodayJson),
      ),
      playMusicDuringBreak: s.playMusicDuringBreak,
      autoPauseMedia: s.autoPauseMedia,
      clockFaceTextColorHex: s.clockFaceTextColorHex,
      clockFaceBlurEnabled: s.clockFaceBlurEnabled,
      customImagePath: s.customImagePath,
      resetTimerAfterMinutes: s.resetTimerAfterMinutes,
      workingHoursEnabled: s.workingHoursEnabled,
      workingDays: List<int>.from(jsonDecode(s.workingDaysJson)),
      workStartTime: s.workStartTime,
      workEndTime: s.workEndTime,
      detectVideoCalls: s.detectVideoCalls,
      detectMeetings: s.detectMeetings,
      respectFocusMode: s.respectFocusMode,
      enableClockOut: s.enableClockOut,
      clockOutTime: s.clockOutTime,
      exercises: (jsonDecode(s.exercisesJson) as List)
          .map((e) => ExerciseModel.fromMap(e))
          .toList(),
      autoSuggestExercises: s.autoSuggestExercises,
      useCursorCountdown: s.useCursorCountdown,
      enableAnimations: s.enableAnimations,
      trayIconStyle: s.trayIconStyle,
      hasCompletedOnboarding: s.hasCompletedOnboarding,
      quietModeEnabled: s.quietModeEnabled,
      quietModePreset: s.quietModePreset,
      lastSnoozeDurationMinutes: s.lastSnoozeDurationMinutes,
      intensityLevel: s.intensityLevel,
      companionEnabled: cp?.companionEnabled ?? false,
      companionPetTheme: cp?.companionPetTheme ?? 'grey_cat',
      companionPetName: cp?.companionPetName ?? 'Mochi',
      companionScale: cp?.companionScale ?? 1.5,
      companionClickThrough: cp?.companionClickThrough ?? false,
      companionFollowMouse: cp?.companionFollowMouse ?? false,
    );
  }

  SettingsModel _loadFromLegacy() {
    return SettingsModel(
      shortBreakIntervalMinutes: _storage.getInt(
        AppConstants.keyShortBreakInterval,
        defaultValue: AppConstants.defaultShortBreakIntervalMinutes,
      ),
      shortBreakDurationSeconds: _storage.getInt(
        AppConstants.keyShortBreakDuration,
        defaultValue: AppConstants.defaultShortBreakDurationSeconds,
      ),
      preBreakWarningSeconds: _storage.getInt(
        AppConstants.keyPreBreakWarningSeconds,
        defaultValue: AppConstants.defaultPreBreakWarningSeconds,
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
      selectedProfileId: _storage.getString(
        'selected_profile_id',
        defaultValue: 'health',
      ),
      menuBarStyle: _storage.getString(
        'menu_bar_style',
        defaultValue: 'countdown',
      ),
      notificationsEnabled: _storage.getBool(
        'notifications_enabled',
        defaultValue: true,
      ),
      showOnAllDisplays: _storage.getBool(
        'show_on_all_displays',
        defaultValue: true,
      ),
      breakTheme: _storage.getString('break_theme', defaultValue: 'random'),
      breakTemplate: _storage.getString(
        'break_template',
        defaultValue: 'minimal',
      ),
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
      workStartTime: _storage.getString(
        'work_start_time',
        defaultValue: '09:00',
      ),
      workEndTime: _storage.getString('work_end_time', defaultValue: '18:00'),
      detectVideoCalls: _storage.getBool(
        'detect_video_calls',
        defaultValue: true,
      ),
      detectMeetings: _storage.getBool('detect_meetings', defaultValue: true),
      respectFocusMode: _storage.getBool(
        'respect_focus_mode',
        defaultValue: true,
      ),
      enableClockOut: _storage.getBool('enable_clock_out', defaultValue: false),
      clockOutTime: _storage.getString('clock_out_time', defaultValue: '17:00'),
      exercises: _loadExercises(),
      autoSuggestExercises: _storage.getBool(
        'auto_suggest_exercises',
        defaultValue: true,
      ),
      useCursorCountdown: _storage.getBool(
        'use_cursor_countdown',
        defaultValue: true,
      ),
      trayIconStyle:
          _storage.getString('tray_icon_style', defaultValue: 'companion') ==
              'cat'
          ? 'companion'
          : _storage.getString('tray_icon_style', defaultValue: 'companion'),
      dailyWorkGoalHours: _storage.getInt(
        'daily_work_goal_hours',
        defaultValue: 8,
      ),
      remindClockOutEnabled: _storage.getBool(
        'remind_clock_out_enabled',
        defaultValue: true,
      ),
      companionEnabled: _storage.getBool(
        'companion_enabled',
        defaultValue: true,
      ),
      companionPetTheme: _storage.getString(
        AppConstants.keyCompanionPetTheme,
        defaultValue: _storage.getString(
          AppConstants.legacyKeyCompanionCatTheme,
          defaultValue: 'grey_cat',
        ),
      ),
      companionPetName: _storage.getString(
        'companion_pet_name',
        defaultValue: 'Mochi',
      ),
      companionScale: _storage.getDouble('companion_scale', defaultValue: 1.5),
      companionClickThrough: _storage.getBool(
        'companion_click_through',
        defaultValue: false,
      ),
      companionFollowMouse: _storage.getBool(
        'companion_follow_mouse',
        defaultValue: false,
      ),
    );
  }

  Future<void> save(SettingsModel settings) async {
    _current = settings;

    final snapshot = SettingsSnapshot(
      id: 1,
      autoStart: settings.autoStart,
      clockFaceStyle: settings.clockFaceStyle,
      selectedProfileId: settings.selectedProfileId,
      strictMode: settings.strictMode,
      remindClockOutEnabled: settings.remindClockOutEnabled,
      dailyWorkGoalHours: settings.dailyWorkGoalHours,
      pauseTimerAfterMinutes: settings.pauseTimerAfterMinutes,
      menuBarStyle: settings.menuBarStyle,
      focusModeEnabled: settings.focusModeEnabled,
      shortBreakIntervalMinutes: settings.shortBreakIntervalMinutes,
      shortBreakDurationSeconds: settings.shortBreakDurationSeconds,
      preBreakWarningSeconds: settings.preBreakWarningSeconds,
      longBreakIntervalMinutes: settings.longBreakIntervalMinutes,
      longBreakDurationMinutes: settings.longBreakDurationMinutes,
      soundEnabled: settings.soundEnabled,
      notificationsEnabled: settings.notificationsEnabled,
      postureReminderEnabled: settings.postureReminderEnabled,
      postureReminderIntervalMinutes: settings.postureReminderIntervalMinutes,
      postureReminderType: settings.postureReminderType,
      eyeBlinkReminderEnabled: settings.eyeBlinkReminderEnabled,
      eyeBlinkReminderIntervalMinutes: settings.eyeBlinkReminderIntervalMinutes,
      eyeBlinkReminderType: settings.eyeBlinkReminderType,
      showOnAllDisplays: settings.showOnAllDisplays,
      breakTheme: settings.breakTheme,
      breakTemplate: settings.breakTemplate,
      showExercisesInBreak: settings.showExercisesInBreak,
      lastExerciseDate: settings.lastExerciseDate,
      shownExercisesTodayJson: jsonEncode(settings.shownExercisesToday),
      playMusicDuringBreak: settings.playMusicDuringBreak,
      autoPauseMedia: settings.autoPauseMedia,
      clockFaceTextColorHex: settings.clockFaceTextColorHex,
      clockFaceBlurEnabled: settings.clockFaceBlurEnabled,
      customImagePath: settings.customImagePath,
      resetTimerAfterMinutes: settings.resetTimerAfterMinutes,
      workingHoursEnabled: settings.workingHoursEnabled,
      workingDaysJson: jsonEncode(settings.workingDays),
      workStartTime: settings.workStartTime,
      workEndTime: settings.workEndTime,
      detectVideoCalls: settings.detectVideoCalls,
      detectMeetings: settings.detectMeetings,
      respectFocusMode: settings.respectFocusMode,
      enableClockOut: settings.enableClockOut,
      clockOutTime: settings.clockOutTime,
      exercisesJson: jsonEncode(
        settings.exercises.map((e) => e.toMap()).toList(),
      ),
      autoSuggestExercises: settings.autoSuggestExercises,
      useCursorCountdown: settings.useCursorCountdown,
      enableAnimations: settings.enableAnimations,
      trayIconStyle: settings.trayIconStyle,
      hasCompletedOnboarding: settings.hasCompletedOnboarding,
      quietModeEnabled: settings.quietModeEnabled,
      quietModePreset: settings.quietModePreset,
      lastSnoozeDurationMinutes: settings.lastSnoozeDurationMinutes,
      intensityLevel: settings.intensityLevel,
    );

    _storage.settingsBox?.put(snapshot);

    final companionPrefs = CompanionPreferences(
      id: 1,
      companionEnabled: settings.companionEnabled,
      companionPetTheme: settings.companionPetTheme,
      companionPetName: settings.companionPetName,
      companionScale: settings.companionScale,
      companionClickThrough: settings.companionClickThrough,
      companionFollowMouse: settings.companionFollowMouse,
    );

    _storage.companionPreferencesBox?.put(companionPrefs);
    notifyListeners();
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
