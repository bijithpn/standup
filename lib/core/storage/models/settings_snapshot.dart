import 'package:objectbox/objectbox.dart';

@Entity()
class SettingsSnapshot {
  @Id()
  int id; // Will always be 1 for a singleton

  bool autoStart;
  String clockFaceStyle;
  String selectedProfileId;
  bool strictMode;
  bool remindClockOutEnabled;
  int dailyWorkGoalHours;
  int pauseTimerAfterMinutes;
  String menuBarStyle;
  bool focusModeEnabled;

  // Break timings
  int shortBreakIntervalMinutes;
  int shortBreakDurationSeconds;
  int preBreakWarningSeconds;
  int longBreakIntervalMinutes;
  int longBreakDurationMinutes;

  // Notifications
  bool soundEnabled;
  bool notificationsEnabled;
  bool postureReminderEnabled;
  int postureReminderIntervalMinutes;
  String postureReminderType;
  bool eyeBlinkReminderEnabled;
  int eyeBlinkReminderIntervalMinutes;
  String eyeBlinkReminderType;

  // Break Screen
  bool showOnAllDisplays;
  String breakTheme;
  String breakTemplate;
  bool showExercisesInBreak;
  String lastExerciseDate;
  String shownExercisesTodayJson; // Stored as JSON string
  bool playMusicDuringBreak;
  bool autoPauseMedia;

  // Clock face
  int clockFaceTextColorHex;
  bool clockFaceBlurEnabled;
  String? customImagePath;

  // Idle/reset
  int resetTimerAfterMinutes;

  // Working hours
  bool workingHoursEnabled;
  String workingDaysJson; // Stored as JSON string
  String workStartTime;
  String workEndTime;

  // Smart detection
  bool detectVideoCalls;
  bool detectMeetings;
  bool respectFocusMode;

  // Clock out
  bool enableClockOut;
  String clockOutTime;

  // Exercises
  String exercisesJson; // Stored as JSON string

  // Misc
  bool autoSuggestExercises;
  bool useCursorCountdown;
  bool enableAnimations;
  String trayIconStyle;

  // UX & Onboarding
  bool hasCompletedOnboarding;
  bool quietModeEnabled;
  String quietModePreset;
  int lastSnoozeDurationMinutes;
  String intensityLevel;

  SettingsSnapshot({
    this.id = 0,
    required this.autoStart,
    required this.clockFaceStyle,
    required this.selectedProfileId,
    required this.strictMode,
    required this.remindClockOutEnabled,
    required this.dailyWorkGoalHours,
    required this.pauseTimerAfterMinutes,
    required this.menuBarStyle,
    required this.focusModeEnabled,
    required this.shortBreakIntervalMinutes,
    required this.shortBreakDurationSeconds,
    required this.preBreakWarningSeconds,
    required this.longBreakIntervalMinutes,
    required this.longBreakDurationMinutes,
    required this.soundEnabled,
    required this.notificationsEnabled,
    required this.postureReminderEnabled,
    required this.postureReminderIntervalMinutes,
    required this.postureReminderType,
    required this.eyeBlinkReminderEnabled,
    required this.eyeBlinkReminderIntervalMinutes,
    required this.eyeBlinkReminderType,
    required this.showOnAllDisplays,
    required this.breakTheme,
    required this.breakTemplate,
    required this.showExercisesInBreak,
    required this.lastExerciseDate,
    required this.shownExercisesTodayJson,
    required this.playMusicDuringBreak,
    required this.autoPauseMedia,
    required this.clockFaceTextColorHex,
    required this.clockFaceBlurEnabled,
    this.customImagePath,
    required this.resetTimerAfterMinutes,
    required this.workingHoursEnabled,
    required this.workingDaysJson,
    required this.workStartTime,
    required this.workEndTime,
    required this.detectVideoCalls,
    required this.detectMeetings,
    required this.respectFocusMode,
    required this.enableClockOut,
    required this.clockOutTime,
    required this.exercisesJson,
    required this.autoSuggestExercises,
    required this.useCursorCountdown,
    required this.enableAnimations,
    required this.trayIconStyle,
    this.hasCompletedOnboarding = false,
    this.quietModeEnabled = false,
    this.quietModePreset = 'none',
    this.lastSnoozeDurationMinutes = 5,
    this.intensityLevel = 'standard',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'autoStart': autoStart,
      'clockFaceStyle': clockFaceStyle,
      'selectedProfileId': selectedProfileId,
      'strictMode': strictMode,
      'remindClockOutEnabled': remindClockOutEnabled,
      'dailyWorkGoalHours': dailyWorkGoalHours,
      'pauseTimerAfterMinutes': pauseTimerAfterMinutes,
      'menuBarStyle': menuBarStyle,
      'focusModeEnabled': focusModeEnabled,
      'shortBreakIntervalMinutes': shortBreakIntervalMinutes,
      'shortBreakDurationSeconds': shortBreakDurationSeconds,
      'preBreakWarningSeconds': preBreakWarningSeconds,
      'longBreakIntervalMinutes': longBreakIntervalMinutes,
      'longBreakDurationMinutes': longBreakDurationMinutes,
      'soundEnabled': soundEnabled,
      'notificationsEnabled': notificationsEnabled,
      'postureReminderEnabled': postureReminderEnabled,
      'postureReminderIntervalMinutes': postureReminderIntervalMinutes,
      'postureReminderType': postureReminderType,
      'eyeBlinkReminderEnabled': eyeBlinkReminderEnabled,
      'eyeBlinkReminderIntervalMinutes': eyeBlinkReminderIntervalMinutes,
      'showOnAllDisplays': showOnAllDisplays,
      'breakTheme': breakTheme,
      'breakTemplate': breakTemplate,
      'showExercisesInBreak': showExercisesInBreak,
      'lastExerciseDate': lastExerciseDate,
      'shownExercisesTodayJson': shownExercisesTodayJson,
      'playMusicDuringBreak': playMusicDuringBreak,
      'autoPauseMedia': autoPauseMedia,
      'clockFaceTextColorHex': clockFaceTextColorHex,
      'clockFaceBlurEnabled': clockFaceBlurEnabled,
      'customImagePath': customImagePath,
      'resetTimerAfterMinutes': resetTimerAfterMinutes,
      'workingHoursEnabled': workingHoursEnabled,
      'workingDaysJson': workingDaysJson,
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
      'detectVideoCalls': detectVideoCalls,
      'detectMeetings': detectMeetings,
      'respectFocusMode': respectFocusMode,
      'enableClockOut': enableClockOut,
      'clockOutTime': clockOutTime,
      'exercisesJson': exercisesJson,
      'autoSuggestExercises': autoSuggestExercises,
      'useCursorCountdown': useCursorCountdown,
      'enableAnimations': enableAnimations,
      'trayIconStyle': trayIconStyle,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'quietModeEnabled': quietModeEnabled,
      'quietModePreset': quietModePreset,
      'lastSnoozeDurationMinutes': lastSnoozeDurationMinutes,
      'intensityLevel': intensityLevel,
    };
  }
}
