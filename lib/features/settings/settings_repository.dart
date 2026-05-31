import 'dart:convert';
import 'dart:async';
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
    try {
      final snapshot = _storage.settingsBox?.get(1);
      final companionPrefs = _storage.companionPreferencesBox?.get(1);

      debugPrint('[SettingsRepo] Loading settings. Snapshot exists: ${snapshot != null}');

      if (snapshot != null) {
        try {
          _current = _fromSnapshot(snapshot, companionPrefs);
          debugPrint('[SettingsRepo] Loaded from snapshot. hasCompletedOnboarding: ${_current.hasCompletedOnboarding}');
        } catch (e) {
          debugPrint('[SettingsRepo] Error decoding snapshot: $e. Falling back to legacy/defaults.');
          _current = _loadFromLegacy();
        }
        
        // Critical fix: Always override with primitive storage if it's more definitive
        // This prevents the onboarding loop if the database snapshot is stale
        final completedOnboarding = _storage.getBool('has_completed_onboarding');
        debugPrint('[SettingsRepo] Definitive storage check: $completedOnboarding');
        
        if (completedOnboarding && !_current.hasCompletedOnboarding) {
          debugPrint('[SettingsRepo] Fix applied: forcing hasCompletedOnboarding to true');
          _current = _current.copyWith(hasCompletedOnboarding: true);
          unawaited(save(_current)); // Resync back to snapshot for consistency
        }
      } else {
        _current = _loadFromLegacy();
        debugPrint('[SettingsRepo] Loaded from legacy. hasCompletedOnboarding: ${_current.hasCompletedOnboarding}');
        if (_storage.isReady) {
          unawaited(save(_current));
        }
      }
    } catch (e) {
      debugPrint('[SettingsRepo] Fatal error in load(): $e');
      // Ensure we have at least defaults
      _current = const SettingsModel();
    }
  }

  List<ExerciseModel> getExercises() {
    if (_storage.settingsBox != null) {
      final snapshot = _storage.settingsBox?.get(1);
      if (snapshot != null && snapshot.exercisesJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(snapshot.exercisesJson);
          if (decoded is List) {
            return decoded.map((e) => ExerciseModel.fromMap(e)).toList();
          }
        } catch (_) {}
      }
    }
    return _loadExercises();
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
      shownExercisesToday: _decodeStringList(s.shownExercisesTodayJson),
      playMusicDuringBreak: s.playMusicDuringBreak,
      autoPauseMedia: s.autoPauseMedia,
      clockFaceTextColorHex: s.clockFaceTextColorHex,
      clockFaceBlurEnabled: s.clockFaceBlurEnabled,
      customImagePath: s.customImagePath,
      resetTimerAfterMinutes: s.resetTimerAfterMinutes,
      workingHoursEnabled: s.workingHoursEnabled,
      workingDays: _decodeIntList(s.workingDaysJson, fallback: const [1, 2, 3, 4, 5]),
      workStartTime: s.workStartTime,
      workEndTime: s.workEndTime,
      detectVideoCalls: s.detectVideoCalls,
      detectMeetings: s.detectMeetings,
      respectFocusMode: s.respectFocusMode,
      enableClockOut: s.enableClockOut,
      clockOutTime: s.clockOutTime,
      exercises: _decodeExercises(s.exercisesJson),
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

  List<String> _decodeStringList(String raw) {
    if (raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return List<String>.from(decoded);
    } catch (_) {}
    return [];
  }

  List<ExerciseModel> _decodeExercises(String raw) {
    if (raw.isEmpty) return ExerciseModel.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => ExerciseModel.fromMap(e)).toList();
      }
    } catch (_) {}
    return ExerciseModel.defaults;
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
      hasCompletedOnboarding: _storage.getBool('has_completed_onboarding'),
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

  Future<void> completeOnboarding() async {
    debugPrint('[SettingsRepo] Explicitly completing onboarding...');
    _current = _current.copyWith(hasCompletedOnboarding: true);
    await save(_current);
    debugPrint('[SettingsRepo] Onboarding completion persisted.');
  }

  Future<void> save(SettingsModel settings) async {
    _current = settings;
    debugPrint('[SettingsRepo] Saving settings. hasCompletedOnboarding: ${settings.hasCompletedOnboarding}');

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

    // Mirror critical onboarding state to primitives for reliability FIRST
    // This is because KeyValueRecords are often more stable than complex snapshots
    await _storage.setBool('has_completed_onboarding', settings.hasCompletedOnboarding);
    await _storage.setInt('short_break_interval', settings.shortBreakIntervalMinutes);
    await _storage.setBool('strict_mode', settings.strictMode);
    await _storage.setBool('companion_enabled', settings.companionEnabled);

    // Then save the full snapshot
    if (_storage.settingsBox != null) {
      _storage.settingsBox!.put(snapshot);
    }

    final companionPrefs = CompanionPreferences(
      id: 1,
      companionEnabled: settings.companionEnabled,
      companionPetTheme: settings.companionPetTheme,
      companionPetName: settings.companionPetName,
      companionScale: settings.companionScale,
      companionClickThrough: settings.companionClickThrough,
      companionFollowMouse: settings.companionFollowMouse,
    );

    if (_storage.companionPreferencesBox != null) {
      _storage.companionPreferencesBox!.put(companionPrefs);
    }
    
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
