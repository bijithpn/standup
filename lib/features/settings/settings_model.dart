import 'package:standup/core/constants/app_constants.dart';

class SettingsModel {
  final int shortBreakIntervalMinutes;
  final int shortBreakDurationSeconds;
  final int longBreakIntervalMinutes;
  final int longBreakDurationMinutes;
  final bool soundEnabled;
  final bool autoStart;
  final bool strictMode;
  final String selectedProfileId;
  final String menuBarStyle; // 'countdown', 'progress', 'icon'

  // Flash settings
  final int flashColorHex;
  final String flashStyle; // 'default', 'photo'
  final String flashMessage;
  final String flashAnimationType; // 'pulse', 'glow', 'fade', 'dim', 'edge'
  final double flashIntensity; // 0.0 to 1.0
  final int flashDurationMs;

  // Focus mode
  final bool focusModeEnabled;

  // Clock face / Appearance
  final String clockFaceStyle; // 'breakloop', 'desktop', 'personal', 'ambient', 'focus'
  final int clockFaceTextColorHex;
  final bool clockFaceBlurEnabled;
  final String? customImagePath;

  // Inactivity
  final int pauseTimerAfterMinutes;
  final int resetTimerAfterMinutes;

  // Working hours
  final bool workingHoursEnabled;
  final bool autoSuggestExercises;

  final int dailyWorkGoalHours;
  final bool remindClockOutEnabled;

  const SettingsModel({
    this.shortBreakIntervalMinutes = AppConstants.defaultShortBreakIntervalMinutes,
    this.shortBreakDurationSeconds = AppConstants.defaultShortBreakDurationSeconds,
    this.longBreakIntervalMinutes = AppConstants.defaultLongBreakIntervalMinutes,
    this.longBreakDurationMinutes = AppConstants.defaultLongBreakDurationMinutes,
    this.soundEnabled = true,
    this.autoStart = false,
    this.strictMode = false,
    this.selectedProfileId = 'health',
    this.menuBarStyle = 'countdown',
    this.flashColorHex = 0xFFF87171,
    this.flashStyle = 'default',
    this.flashMessage = 'Take a deep breath',
    this.flashAnimationType = 'pulse',
    this.flashIntensity = 0.5,
    this.flashDurationMs = 2500,
    this.focusModeEnabled = false,
    this.clockFaceStyle = 'breakloop',
    this.clockFaceTextColorHex = 0xFFFFFFFF,
    this.clockFaceBlurEnabled = true,
    this.customImagePath,
    this.pauseTimerAfterMinutes = 1,
    this.resetTimerAfterMinutes = 5,
    this.workingHoursEnabled = false,
    this.autoSuggestExercises = true,
    this.dailyWorkGoalHours = 8,
    this.remindClockOutEnabled = true,
  });

  SettingsModel copyWith({
    int? shortBreakIntervalMinutes,
    int? shortBreakDurationSeconds,
    int? longBreakIntervalMinutes,
    int? longBreakDurationMinutes,
    bool? soundEnabled,
    bool? autoStart,
    bool? strictMode,
    String? selectedProfileId,
    String? menuBarStyle,
    int? flashColorHex,
    String? flashStyle,
    String? flashMessage,
    String? flashAnimationType,
    double? flashIntensity,
    int? flashDurationMs,
    bool? focusModeEnabled,
    String? clockFaceStyle,
    int? clockFaceTextColorHex,
    bool? clockFaceBlurEnabled,
    String? customImagePath,
    int? pauseTimerAfterMinutes,
    int? resetTimerAfterMinutes,
    bool? workingHoursEnabled,
    bool? autoSuggestExercises,
    int? dailyWorkGoalHours,
    bool? remindClockOutEnabled,
  }) {
    return SettingsModel(
      shortBreakIntervalMinutes: shortBreakIntervalMinutes ?? this.shortBreakIntervalMinutes,
      shortBreakDurationSeconds: shortBreakDurationSeconds ?? this.shortBreakDurationSeconds,
      longBreakIntervalMinutes: longBreakIntervalMinutes ?? this.longBreakIntervalMinutes,
      longBreakDurationMinutes: longBreakDurationMinutes ?? this.longBreakDurationMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      autoStart: autoStart ?? this.autoStart,
      strictMode: strictMode ?? this.strictMode,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      menuBarStyle: menuBarStyle ?? this.menuBarStyle,
      flashColorHex: flashColorHex ?? this.flashColorHex,
      flashStyle: flashStyle ?? this.flashStyle,
      flashMessage: flashMessage ?? this.flashMessage,
      flashAnimationType: flashAnimationType ?? this.flashAnimationType,
      flashIntensity: flashIntensity ?? this.flashIntensity,
      flashDurationMs: flashDurationMs ?? this.flashDurationMs,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      clockFaceStyle: clockFaceStyle ?? this.clockFaceStyle,
      clockFaceTextColorHex: clockFaceTextColorHex ?? this.clockFaceTextColorHex,
      clockFaceBlurEnabled: clockFaceBlurEnabled ?? this.clockFaceBlurEnabled,
      customImagePath: customImagePath ?? this.customImagePath,
      pauseTimerAfterMinutes: pauseTimerAfterMinutes ?? this.pauseTimerAfterMinutes,
      resetTimerAfterMinutes: resetTimerAfterMinutes ?? this.resetTimerAfterMinutes,
      workingHoursEnabled: workingHoursEnabled ?? this.workingHoursEnabled,
      autoSuggestExercises: autoSuggestExercises ?? this.autoSuggestExercises,
      dailyWorkGoalHours: dailyWorkGoalHours ?? this.dailyWorkGoalHours,
      remindClockOutEnabled: remindClockOutEnabled ?? this.remindClockOutEnabled,
    );
  }
}
