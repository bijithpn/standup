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

  const SettingsModel({
    this.shortBreakIntervalMinutes =
        AppConstants.defaultShortBreakIntervalMinutes,
    this.shortBreakDurationSeconds =
        AppConstants.defaultShortBreakDurationSeconds,
    this.longBreakIntervalMinutes =
        AppConstants.defaultLongBreakIntervalMinutes,
    this.longBreakDurationMinutes =
        AppConstants.defaultLongBreakDurationMinutes,
    this.soundEnabled = true,
    this.autoStart = false,
    this.strictMode = false,
    this.selectedProfileId = 'health',
    this.menuBarStyle = 'countdown',
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
  }) {
    return SettingsModel(
      shortBreakIntervalMinutes:
          shortBreakIntervalMinutes ?? this.shortBreakIntervalMinutes,
      shortBreakDurationSeconds:
          shortBreakDurationSeconds ?? this.shortBreakDurationSeconds,
      longBreakIntervalMinutes:
          longBreakIntervalMinutes ?? this.longBreakIntervalMinutes,
      longBreakDurationMinutes:
          longBreakDurationMinutes ?? this.longBreakDurationMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      autoStart: autoStart ?? this.autoStart,
      strictMode: strictMode ?? this.strictMode,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      menuBarStyle: menuBarStyle ?? this.menuBarStyle,
    );
  }
}
