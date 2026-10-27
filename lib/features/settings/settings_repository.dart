import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/errors/app_exception.dart';

class SettingsRepository extends ChangeNotifier {
  final StorageService _storage;
  SettingsModel _current = const SettingsModel();

  SettingsRepository({required StorageService storage}) : _storage = storage;

  static Map<String, int> _decodeTemplateAccentOverrides(String raw) {
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k as String, v as int));
      }
    } catch (_) {
      // Corrupt/legacy value — fall back to no overrides.
    }
    return const {};
  }

  static Map<String, int> _decodeCategoryDailyBudgetMinutes(String raw) {
    if (raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k as String, v as int));
      }
    } catch (_) {
      // Corrupt/legacy value — fall back to no budgets set.
    }
    return const {};
  }

  SettingsModel get currentSettings => _current;

  Future<void> load() async {
    if (!_storage.isReady) {
      debugPrint(
        '[SettingsRepo] StorageService is not ready. Attempting explicit initialization in load().',
      );
      try {
        await _storage.init();
      } catch (e) {
        debugPrint(
          '[SettingsRepo] Explicit StorageService.init() failed in load(): $e',
        );
      }
    }

    debugPrint('=== STARTUP STORAGE DIAGNOSTICS ===');
    debugPrint('storage.isReady: ${_storage.isReady}');
    debugPrint('storage.hasFailed: ${_storage.hasFailed}');
    debugPrint('settingsBox != null: ${_storage.settingsBox != null}');
    debugPrint(
      'companionPreferencesBox != null: ${_storage.companionPreferencesBox != null}',
    );
    debugPrint('kvBox != null: ${_storage.kvBox != null}');
    debugPrint('active database path: ${_storage.activeDatabasePath}');
    debugPrint('process id: $pid');
    debugPrint('isolate name: "${Isolate.current.debugName ?? ''}"');
    debugPrint('ObjectBox open duration: ${_storage.openDurationMs} ms');
    debugPrint('startup duration: ${_storage.initDurationMs} ms');
    debugPrint('====================================');

    if (!_storage.isReady) {
      debugPrint(
        '[SettingsRepo] StorageService remains uninitialized after load() retry fallback. Falling back to default settings.',
      );
      _current = const SettingsModel();
      return;
    }

    try {
      final snapshot = _storage.settingsBox?.get(1);
      final companionPrefs = _storage.companionPreferencesBox?.get(1);

      debugPrint(
        '[SettingsRepo] Loading settings. Snapshot exists: ${snapshot != null}',
      );

      if (snapshot != null) {
        try {
          _current = _fromSnapshot(snapshot, companionPrefs);
          debugPrint(
            '[SettingsRepo] Loaded from snapshot. hasCompletedOnboarding: ${_current.hasCompletedOnboarding}',
          );
        } catch (e) {
          debugPrint(
            '[SettingsRepo] Error decoding snapshot: $e. Falling back to legacy/defaults.',
          );
          _current = _loadFromLegacy();
        }
      } else {
        _current = _loadFromLegacy();
        debugPrint(
          '[SettingsRepo] Loaded from legacy. hasCompletedOnboarding: ${_current.hasCompletedOnboarding}',
        );
        if (_storage.isReady) {
          unawaited(save(_current));
        }
      }

      // The onboarding completion flag is a one-way toggle (false -> true).
      // We check both the ObjectBox settings snapshot and the database key-value fallback to ensure consistency.
      final snapshotOnboarding = snapshot?.hasCompletedOnboarding ?? false;
      final kvOnboarding = _storage.getBool('has_completed_onboarding');
      final onboardingDone = snapshotOnboarding || kvOnboarding;

      debugPrint(
        '[SettingsRepo] Onboarding reconciliation: '
        'snapshot=$snapshotOnboarding, kv=$kvOnboarding → resolved=$onboardingDone',
      );

      if (onboardingDone && !_current.hasCompletedOnboarding) {
        _current = _current.copyWith(hasCompletedOnboarding: true);
      }

      if (onboardingDone && !kvOnboarding) {
        debugPrint('[SettingsRepo] Back-filling KV onboarding flag.');
        unawaited(_storage.setBool('has_completed_onboarding', true));
      }
      if (onboardingDone && !snapshotOnboarding && snapshot != null) {
        debugPrint('[SettingsRepo] Back-filling snapshot onboarding flag.');
        unawaited(save(_current));
      }

      debugPrint(
        '[SettingsRepo] Final hasCompletedOnboarding: ${_current.hasCompletedOnboarding}',
      );
    } catch (e) {
      debugPrint('[SettingsRepo] Fatal error in load(): $e');
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
            final saved = decoded.map((e) => ExerciseModel.fromMap(e)).toList();
            return _withNewDefaults(saved);
          }
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
      }
    }
    return _loadExercises();
  }

  /// Appends any built-in exercise that isn't already in [saved] by id, so
  /// new default activities show up for existing users too, not just fresh
  /// installs. Existing entries (and any favorite/hidden state) are untouched.
  List<ExerciseModel> _withNewDefaults(List<ExerciseModel> saved) {
    final savedIds = saved.map((e) => e.id).toSet();
    final missing = ExerciseModel.defaults.where(
      (e) => !savedIds.contains(e.id),
    );
    return [...saved, ...missing];
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
      shortBreakIntervalMinutes: s.shortBreakIntervalMinutes,
      shortBreakDurationSeconds: s.shortBreakDurationSeconds,
      preBreakWarningSeconds: s.preBreakWarningSeconds,
      longBreakIntervalMinutes: s.longBreakIntervalMinutes,
      longBreakDurationMinutes: s.longBreakDurationMinutes,
      soundEnabled: s.soundEnabled,
      notificationsEnabled: s.notificationsEnabled,
      postureReminderEnabled: s.postureReminderEnabled,
      postureReminderType: s.postureReminderType,
      eyeBlinkReminderEnabled: s.eyeBlinkReminderEnabled,
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
      workingDays: _decodeIntList(
        s.workingDaysJson,
        fallback: const [1, 2, 3, 4, 5],
      ),
      workStartTime: s.workStartTime,
      workEndTime: s.workEndTime,
      detectVideoCalls: s.detectVideoCalls,
      detectMeetings: s.detectMeetings,
      globalHotkeyEnabled: _storage.getBool(
        'global_hotkey_enabled',
        defaultValue: true,
      ),
      presentationPauseEnabled: _storage.getBool(
        'presentation_pause_enabled',
        defaultValue: false,
      ),
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
      dailyBreakGoalCount: s.dailyBreakGoalCount,
      maxContinuousSittingMinutes: s.maxContinuousSittingMinutes,
      weeklyConsistencyTargetDays: s.weeklyConsistencyTargetDays,
      calendarEnabled: s.calendarEnabled,
      enableSessionResume: s.enableSessionResume,
      companionEnabled: cp?.companionEnabled ?? false,
      pipModeEnabled: _storage.getBool('pip_mode_enabled', defaultValue: true),
      companionPetTheme: cp?.companionPetTheme ?? 'grey_cat',
      companionPetName: cp?.companionPetName ?? 'Mochi',
      companionScale: cp?.companionScale ?? 1.5,
      companionClickThrough: cp?.companionClickThrough ?? false,
      companionFollowMouse: cp?.companionFollowMouse ?? false,
      unlockedPets: _decodeStringList(cp?.unlockedPetsJson ?? '[]'),
      pettingEnabled: _storage.getBool('petting_enabled', defaultValue: true),
      companionGazeEnabled: _storage.getBool(
        'companion_gaze_enabled',
        defaultValue: true,
      ),
      companionGazeSensitivity: _storage
          .getDouble('companion_gaze_sensitivity', defaultValue: 0.5)
          .clamp(0.0, 1.0),
      companionIdleAnimation: _storage.getBool(
        'companion_idle_animation',
        defaultValue: true,
      ),
      companionReactions: _storage.getBool(
        'companion_reactions',
        defaultValue: true,
      ),
      companionReducedMotion: _storage.getBool(
        'companion_reduced_motion',
        defaultValue: false,
      ),
      ballThrowEnabled: _storage.getBool(
        'ball_throw_enabled',
        defaultValue: true,
      ),
      treatEnabled: _storage.getBool('treat_enabled', defaultValue: true),
      developerReactions: _storage.getBool(
        'developer_reactions',
        defaultValue: true,
      ),
      quietModeAutoActivate: _storage.getBool(
        'quiet_mode_auto_activate',
        defaultValue: true,
      ),
      companionToyType: _storage.getString(
        'companion_toy_type',
        defaultValue: 'tennis_ball',
      ),
      companionTreatType: _storage.getString(
        'companion_treat_type',
        defaultValue: 'sushi',
      ),
      overlayThemeMode: _storage.getString(
        'overlay_theme_mode',
        defaultValue: 'dark',
      ),
      breathPreset: _storage.getString('breath_preset', defaultValue: 'box'),
      breakChimeEnabled: _storage.getBool('break_chime_enabled'),
      lookedAwayPromptEnabled: _storage.getBool('looked_away_prompt_enabled'),
      templateAccentOverrides: _decodeTemplateAccentOverrides(
        _storage.getString('template_accent_overrides', defaultValue: ''),
      ),
      categoryDailyBudgetMinutes: _decodeCategoryDailyBudgetMinutes(
        _storage.getString('category_daily_budget_minutes', defaultValue: ''),
      ),
      companionPreviewBackground: _storage.getString(
        'companion_preview_background',
        defaultValue: '',
      ),
      pipBackgroundStyle: _storage.getString(
        'pip_background_style',
        defaultValue: 'transparent',
      ),
      pipOpacity: _storage.getDouble('pip_opacity', defaultValue: 1.0),
      pipDraggableClickable: _storage.getBool(
        'pip_draggable_clickable',
        defaultValue: true,
      ),
      hydrationReminderEnabled: _storage.getBool(
        'hydration_reminder_enabled',
        defaultValue: false,
      ),
      stretchReminderEnabled: _storage.getBool(
        'stretch_reminder_enabled',
        defaultValue: false,
      ),
      standUpReminderEnabled: _storage.getBool(
        'stand_up_reminder_enabled',
        defaultValue: false,
      ),
    );
  }

  List<String> _decodeStringList(String raw) {
    if (raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return List<String>.from(decoded);
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
    return [];
  }

  List<ExerciseModel> _decodeExercises(String raw) {
    if (raw.isEmpty) return ExerciseModel.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => ExerciseModel.fromMap(e)).toList();
      }
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
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
      globalHotkeyEnabled: _storage.getBool(
        'global_hotkey_enabled',
        defaultValue: true,
      ),
      presentationPauseEnabled: _storage.getBool(
        'presentation_pause_enabled',
        defaultValue: false,
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
      pipModeEnabled: _storage.getBool('pip_mode_enabled', defaultValue: true),
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
      pettingEnabled: _storage.getBool('petting_enabled', defaultValue: true),
      companionGazeEnabled: _storage.getBool(
        'companion_gaze_enabled',
        defaultValue: true,
      ),
      companionGazeSensitivity: _storage
          .getDouble('companion_gaze_sensitivity', defaultValue: 0.5)
          .clamp(0.0, 1.0),
      companionIdleAnimation: _storage.getBool(
        'companion_idle_animation',
        defaultValue: true,
      ),
      companionReactions: _storage.getBool(
        'companion_reactions',
        defaultValue: true,
      ),
      companionReducedMotion: _storage.getBool(
        'companion_reduced_motion',
        defaultValue: false,
      ),
      ballThrowEnabled: _storage.getBool(
        'ball_throw_enabled',
        defaultValue: true,
      ),
      treatEnabled: _storage.getBool('treat_enabled', defaultValue: true),
      developerReactions: _storage.getBool(
        'developer_reactions',
        defaultValue: true,
      ),
      quietModeAutoActivate: _storage.getBool(
        'quiet_mode_auto_activate',
        defaultValue: true,
      ),
      calendarEnabled: _storage.getBool(
        'calendar_enabled',
        defaultValue: false,
      ),
      enableSessionResume: _storage.getBool(
        'enable_session_resume',
        defaultValue: true,
      ),
      companionToyType: _storage.getString(
        'companion_toy_type',
        defaultValue: 'tennis_ball',
      ),
      companionTreatType: _storage.getString(
        'companion_treat_type',
        defaultValue: 'sushi',
      ),
      overlayThemeMode: _storage.getString(
        'overlay_theme_mode',
        defaultValue: 'dark',
      ),
      breathPreset: _storage.getString('breath_preset', defaultValue: 'box'),
      breakChimeEnabled: _storage.getBool('break_chime_enabled'),
      lookedAwayPromptEnabled: _storage.getBool('looked_away_prompt_enabled'),
      templateAccentOverrides: _decodeTemplateAccentOverrides(
        _storage.getString('template_accent_overrides', defaultValue: ''),
      ),
      categoryDailyBudgetMinutes: _decodeCategoryDailyBudgetMinutes(
        _storage.getString('category_daily_budget_minutes', defaultValue: ''),
      ),
      companionPreviewBackground: _storage.getString(
        'companion_preview_background',
        defaultValue: '',
      ),
      pipBackgroundStyle: _storage.getString(
        'pip_background_style',
        defaultValue: 'transparent',
      ),
      pipOpacity: _storage.getDouble('pip_opacity', defaultValue: 1.0),
      pipDraggableClickable: _storage.getBool(
        'pip_draggable_clickable',
        defaultValue: true,
      ),
      hydrationReminderEnabled: _storage.getBool(
        'hydration_reminder_enabled',
        defaultValue: false,
      ),
      stretchReminderEnabled: _storage.getBool(
        'stretch_reminder_enabled',
        defaultValue: false,
      ),
      standUpReminderEnabled: _storage.getBool(
        'stand_up_reminder_enabled',
        defaultValue: false,
      ),
    );
  }

  Future<void> completeOnboarding() async {
    debugPrint('[SettingsRepo] Completing onboarding...');
    _current = _current.copyWith(hasCompletedOnboarding: true);
    await _storage.setBool('has_completed_onboarding', true);
    await save(_current);
    final kvVerify = _storage.getBool('has_completed_onboarding');
    final snapVerify =
        _storage.settingsBox?.get(1)?.hasCompletedOnboarding ?? false;
    if (!kvVerify || !snapVerify) {
      debugPrint(
        '[SettingsRepo] Onboarding flag was not fully persisted. '
        'KV=$kvVerify, snapshot=$snapVerify',
      );
    } else {
      debugPrint(
        '[SettingsRepo] Onboarding persisted. KV=$kvVerify, snapshot=$snapVerify',
      );
    }
  }

  Future<void> save(SettingsModel settings) async {
    if (!_storage.isReady) {
      debugPrint(
        '[SettingsRepo] StorageService is not ready during save(). Attempting explicit initialization.',
      );
      try {
        await _storage.init();
      } catch (e) {
        debugPrint(
          '[SettingsRepo] Explicit StorageService.init() failed in save(): $e',
        );
      }
    }

    if (!_storage.isReady || _storage.settingsBox == null) {
      debugPrint(
        '[SettingsRepo] StorageService is unavailable during save(); settingsBox is null. Diagnostic details: '
        'Storage ready: ${_storage.isReady}, settingsBox: ${_storage.settingsBox}, companionPrefsBox: ${_storage.companionPreferencesBox}, kvBox: ${_storage.kvBox}',
      );
      throw AppException(
        type: AppErrorType.storage,
        message: 'Storage unavailable',
      );
    }

    _current = settings;
    debugPrint(
      '[SettingsRepo] Saving settings. hasCompletedOnboarding: ${settings.hasCompletedOnboarding}',
    );

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
      shortBreakIntervalMinutes: settings.shortBreakIntervalMinutes,
      shortBreakDurationSeconds: settings.shortBreakDurationSeconds,
      preBreakWarningSeconds: settings.preBreakWarningSeconds,
      longBreakIntervalMinutes: settings.longBreakIntervalMinutes,
      longBreakDurationMinutes: settings.longBreakDurationMinutes,
      soundEnabled: settings.soundEnabled,
      notificationsEnabled: settings.notificationsEnabled,
      postureReminderEnabled: settings.postureReminderEnabled,
      postureReminderIntervalMinutes: 30,
      postureReminderType: settings.postureReminderType,
      eyeBlinkReminderEnabled: settings.eyeBlinkReminderEnabled,
      eyeBlinkReminderIntervalMinutes: 20,
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
      dailyBreakGoalCount: settings.dailyBreakGoalCount,
      maxContinuousSittingMinutes: settings.maxContinuousSittingMinutes,
      weeklyConsistencyTargetDays: settings.weeklyConsistencyTargetDays,
      calendarEnabled: settings.calendarEnabled,
      enableSessionResume: settings.enableSessionResume,
    );

    await _storage.setBool(
      'has_completed_onboarding',
      settings.hasCompletedOnboarding,
    );
    await _storage.setInt(
      'short_break_interval',
      settings.shortBreakIntervalMinutes,
    );
    await _storage.setBool('strict_mode', settings.strictMode);
    await _storage.setBool('companion_enabled', settings.companionEnabled);

    await _storage.setString('break_template', settings.breakTemplate);
    await _storage.setString('break_theme', settings.breakTheme);
    await _storage.setString('clock_face_style', settings.clockFaceStyle);
    await _storage.setString('menu_bar_style', settings.menuBarStyle);
    await _storage.setString('selected_profile_id', settings.selectedProfileId);
    await _storage.setString('tray_icon_style', settings.trayIconStyle);
    await _storage.setInt(
      'clock_face_text_color_hex',
      settings.clockFaceTextColorHex,
    );
    await _storage.setBool(
      'clock_face_blur_enabled',
      settings.clockFaceBlurEnabled,
    );
    await _storage.setString(
      'custom_image_path',
      settings.customImagePath ?? '',
    );

    await _storage.setInt(
      AppConstants.keyShortBreakInterval,
      settings.shortBreakIntervalMinutes,
    );
    await _storage.setInt(
      AppConstants.keyShortBreakDuration,
      settings.shortBreakDurationSeconds,
    );
    await _storage.setInt(
      AppConstants.keyPreBreakWarningSeconds,
      settings.preBreakWarningSeconds,
    );
    await _storage.setInt(
      AppConstants.keyLongBreakInterval,
      settings.longBreakIntervalMinutes,
    );
    await _storage.setInt(
      AppConstants.keyLongBreakDuration,
      settings.longBreakDurationMinutes,
    );

    await _storage.setBool(AppConstants.keySoundEnabled, settings.soundEnabled);
    await _storage.setBool(
      'notifications_enabled',
      settings.notificationsEnabled,
    );

    await _storage.setBool('detect_video_calls', settings.detectVideoCalls);
    await _storage.setBool('detect_meetings', settings.detectMeetings);
    await _storage.setBool(
      'global_hotkey_enabled',
      settings.globalHotkeyEnabled,
    );
    await _storage.setBool(
      'presentation_pause_enabled',
      settings.presentationPauseEnabled,
    );
    await _storage.setBool('calendar_enabled', settings.calendarEnabled);
    await _storage.setBool(
      'enable_session_resume',
      settings.enableSessionResume,
    );

    await _storage.setBool(
      'show_exercises_in_break',
      settings.showExercisesInBreak,
    );
    await _storage.setBool('enable_animations', settings.enableAnimations);
    await _storage.setString('intensity_level', settings.intensityLevel);

    await _storage.setString(
      AppConstants.keyCompanionPetTheme,
      settings.companionPetTheme,
    );
    await _storage.setDouble('companion_scale', settings.companionScale);
    await _storage.setBool('petting_enabled', settings.pettingEnabled);
    await _storage.setBool(
      'companion_gaze_enabled',
      settings.companionGazeEnabled,
    );
    await _storage.setDouble(
      'companion_gaze_sensitivity',
      settings.companionGazeSensitivity,
    );
    await _storage.setBool(
      'companion_idle_animation',
      settings.companionIdleAnimation,
    );
    await _storage.setBool('companion_reactions', settings.companionReactions);
    await _storage.setBool(
      'companion_reduced_motion',
      settings.companionReducedMotion,
    );
    await _storage.setBool('ball_throw_enabled', settings.ballThrowEnabled);
    await _storage.setBool('treat_enabled', settings.treatEnabled);
    await _storage.setBool('developer_reactions', settings.developerReactions);
    await _storage.setBool(
      'quiet_mode_auto_activate',
      settings.quietModeAutoActivate,
    );
    await _storage.setBool('pip_mode_enabled', settings.pipModeEnabled);
    await _storage.setString('companion_toy_type', settings.companionToyType);
    await _storage.setString(
      'companion_treat_type',
      settings.companionTreatType,
    );
    await _storage.setString('overlay_theme_mode', settings.overlayThemeMode);
    await _storage.setString('breath_preset', settings.breathPreset);
    await _storage.setBool('break_chime_enabled', settings.breakChimeEnabled);
    await _storage.setBool(
      'looked_away_prompt_enabled',
      settings.lookedAwayPromptEnabled,
    );
    await _storage.setString(
      'template_accent_overrides',
      jsonEncode(settings.templateAccentOverrides),
    );
    await _storage.setString(
      'category_daily_budget_minutes',
      jsonEncode(settings.categoryDailyBudgetMinutes),
    );
    await _storage.setString(
      'companion_preview_background',
      settings.companionPreviewBackground,
    );
    await _storage.setString(
      'pip_background_style',
      settings.pipBackgroundStyle,
    );
    await _storage.setDouble('pip_opacity', settings.pipOpacity);
    await _storage.setBool(
      'pip_draggable_clickable',
      settings.pipDraggableClickable,
    );
    await _storage.setBool(
      'hydration_reminder_enabled',
      settings.hydrationReminderEnabled,
    );
    await _storage.setBool(
      'stretch_reminder_enabled',
      settings.stretchReminderEnabled,
    );
    await _storage.setBool(
      'stand_up_reminder_enabled',
      settings.standUpReminderEnabled,
    );

    _storage.settingsBox!.put(snapshot);
    debugPrint(
      '[SettingsRepo] Snapshot written. '
      'hasCompletedOnboarding: ${snapshot.hasCompletedOnboarding}',
    );

    final companionPrefs = CompanionPreferences(
      id: 1,
      companionEnabled: settings.companionEnabled,
      companionPetTheme: settings.companionPetTheme,
      companionPetName: settings.companionPetName,
      companionScale: settings.companionScale,
      companionClickThrough: settings.companionClickThrough,
      companionFollowMouse: settings.companionFollowMouse,
      unlockedPetsJson: jsonEncode(settings.unlockedPets),
    );

    _storage.companionPreferencesBox!.put(companionPrefs);

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
      return exercises.isEmpty
          ? ExerciseModel.defaults
          : _withNewDefaults(exercises);
    } catch (_) {
      return ExerciseModel.defaults;
    }
  }
}
