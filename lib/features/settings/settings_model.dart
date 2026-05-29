import 'package:breakmate/features/settings/exercise_model.dart';

class SettingsModel {
  final bool autoStart;
  final String clockFaceStyle;
  final String selectedProfileId;
  final bool strictMode;
  final bool remindClockOutEnabled;
  final int dailyWorkGoalHours;
  final int pauseTimerAfterMinutes;
  final String menuBarStyle;
  final bool focusModeEnabled;

  // Break timings
  final int shortBreakIntervalMinutes;
  final int shortBreakDurationSeconds;
  final int preBreakWarningSeconds;
  final int longBreakIntervalMinutes;
  final int longBreakDurationMinutes;

  // Notifications
  final bool soundEnabled;
  final bool notificationsEnabled;
  final bool postureReminderEnabled;
  final int postureReminderIntervalMinutes;
  final String postureReminderType;
  final bool eyeBlinkReminderEnabled;
  final int eyeBlinkReminderIntervalMinutes;
  final String eyeBlinkReminderType;

  // Break Screen
  final bool showOnAllDisplays;
  final String breakTheme;
  final String breakTemplate;
  final bool showExercisesInBreak;
  final String lastExerciseDate;
  final List<String> shownExercisesToday;
  final bool playMusicDuringBreak;
  final bool autoPauseMedia;

  // Clock face
  final int clockFaceTextColorHex;
  final bool clockFaceBlurEnabled;
  final String? customImagePath;

  // Idle/reset
  final int resetTimerAfterMinutes;

  // Working hours
  final bool workingHoursEnabled;
  final List<int> workingDays; // 1=Mon … 7=Sun
  final String workStartTime; // "HH:mm"
  final String workEndTime; // "HH:mm"

  // Smart detection
  final bool detectVideoCalls;
  final bool detectMeetings;
  final bool respectFocusMode;

  // Clock out
  final bool enableClockOut;
  final String clockOutTime; // "HH:mm"

  // Exercises
  final List<ExerciseModel> exercises;

  // Misc
  final bool autoSuggestExercises;
  final bool useCursorCountdown;
  final bool enableAnimations;
  final String trayIconStyle; // 'default', 'companion', 'minimal', 'countdown'
  final bool companionEnabled;
  final String companionPetTheme;
  final String companionPetName;
  final double companionScale;
  final bool companionClickThrough;
  final bool companionFollowMouse;

  // UX & Onboarding
  final bool hasCompletedOnboarding;
  final bool quietModeEnabled;
  final String
  quietModePreset; // 'none', 'presenting', 'meeting', 'deep_work', 'low_battery'
  final int lastSnoozeDurationMinutes;
  final String intensityLevel; // 'gentle', 'standard', 'strict', 'locked'

  const SettingsModel({
    this.autoStart = true,
    this.clockFaceStyle = 'breakloop',
    this.selectedProfileId = 'default',
    this.strictMode = false,
    this.remindClockOutEnabled = false,
    this.dailyWorkGoalHours = 8,
    this.pauseTimerAfterMinutes = 5,
    this.menuBarStyle = 'countdown',
    this.focusModeEnabled = false,
    this.shortBreakIntervalMinutes = 20,
    this.shortBreakDurationSeconds = 20,
    this.preBreakWarningSeconds = 20,
    this.longBreakIntervalMinutes = 60,
    this.longBreakDurationMinutes = 5,

    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.postureReminderEnabled = false,
    this.postureReminderIntervalMinutes = 30,
    this.postureReminderType = 'overlay',
    this.eyeBlinkReminderEnabled = false,
    this.eyeBlinkReminderIntervalMinutes = 20,
    this.eyeBlinkReminderType = 'overlay',
    this.showOnAllDisplays = true,
    this.breakTheme = 'random',
    this.breakTemplate = 'minimal',
    this.clockFaceTextColorHex = 0xFFFFFFFF,
    this.clockFaceBlurEnabled = true,
    this.customImagePath,
    this.resetTimerAfterMinutes = 15,
    this.workingHoursEnabled = false,
    this.workingDays = const [1, 2, 3, 4, 5],
    this.workStartTime = '09:00',
    this.workEndTime = '18:00',
    this.detectVideoCalls = true,
    this.detectMeetings = true,
    this.respectFocusMode = true,
    this.enableClockOut = false,
    this.clockOutTime = '17:00',
    this.showExercisesInBreak = true,
    this.lastExerciseDate = '',
    this.shownExercisesToday = const [],
    this.playMusicDuringBreak = true,
    this.autoPauseMedia = true,
    this.exercises = const [],
    this.autoSuggestExercises = true,
    this.useCursorCountdown = true,
    this.enableAnimations = true,
    this.trayIconStyle = 'companion',
    this.companionEnabled = false,
    this.companionPetTheme = 'grey_cat',
    this.companionPetName = 'Mochi',
    this.companionScale = 6.0,
    this.companionClickThrough = false,
    this.companionFollowMouse = false,
    this.hasCompletedOnboarding = false,
    this.quietModeEnabled = false,
    this.quietModePreset = 'none',
    this.lastSnoozeDurationMinutes = 5,
    this.intensityLevel = 'standard',
  });

  SettingsModel copyWith({
    bool? autoStart,
    String? clockFaceStyle,
    String? selectedProfileId,
    bool? strictMode,
    bool? remindClockOutEnabled,
    int? dailyWorkGoalHours,
    int? pauseTimerAfterMinutes,
    String? menuBarStyle,
    bool? focusModeEnabled,
    int? shortBreakIntervalMinutes,
    int? shortBreakDurationSeconds,
    int? preBreakWarningSeconds,
    int? longBreakIntervalMinutes,
    int? longBreakDurationMinutes,

    bool? soundEnabled,
    bool? notificationsEnabled,
    bool? postureReminderEnabled,
    int? postureReminderIntervalMinutes,
    String? postureReminderType,
    bool? eyeBlinkReminderEnabled,
    int? eyeBlinkReminderIntervalMinutes,
    String? eyeBlinkReminderType,
    bool? showOnAllDisplays,
    String? breakTheme,
    String? breakTemplate,
    bool? showExercisesInBreak,
    String? lastExerciseDate,
    List<String>? shownExercisesToday,
    bool? playMusicDuringBreak,
    bool? autoPauseMedia,
    int? clockFaceTextColorHex,
    bool? clockFaceBlurEnabled,
    String? customImagePath,
    int? resetTimerAfterMinutes,
    bool? workingHoursEnabled,
    List<int>? workingDays,
    String? workStartTime,
    String? workEndTime,
    bool? detectVideoCalls,
    bool? detectMeetings,
    bool? respectFocusMode,
    bool? enableClockOut,
    String? clockOutTime,
    List<ExerciseModel>? exercises,
    bool? autoSuggestExercises,
    bool? useCursorCountdown,
    bool? enableAnimations,
    String? trayIconStyle,
    bool? companionEnabled,
    String? companionPetTheme,
    String? companionPetName,
    double? companionScale,
    bool? companionClickThrough,
    bool? companionFollowMouse,
    bool? hasCompletedOnboarding,
    bool? quietModeEnabled,
    String? quietModePreset,
    int? lastSnoozeDurationMinutes,
    String? intensityLevel,
  }) {
    return SettingsModel(
      autoStart: autoStart ?? this.autoStart,
      clockFaceStyle: clockFaceStyle ?? this.clockFaceStyle,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      strictMode: strictMode ?? this.strictMode,
      remindClockOutEnabled:
          remindClockOutEnabled ?? this.remindClockOutEnabled,
      dailyWorkGoalHours: dailyWorkGoalHours ?? this.dailyWorkGoalHours,
      pauseTimerAfterMinutes:
          pauseTimerAfterMinutes ?? this.pauseTimerAfterMinutes,
      menuBarStyle: menuBarStyle ?? this.menuBarStyle,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      shortBreakIntervalMinutes:
          shortBreakIntervalMinutes ?? this.shortBreakIntervalMinutes,
      shortBreakDurationSeconds:
          shortBreakDurationSeconds ?? this.shortBreakDurationSeconds,
      preBreakWarningSeconds:
          preBreakWarningSeconds ?? this.preBreakWarningSeconds,
      longBreakIntervalMinutes:
          longBreakIntervalMinutes ?? this.longBreakIntervalMinutes,
      longBreakDurationMinutes:
          longBreakDurationMinutes ?? this.longBreakDurationMinutes,

      soundEnabled: soundEnabled ?? this.soundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      postureReminderEnabled:
          postureReminderEnabled ?? this.postureReminderEnabled,
      postureReminderIntervalMinutes:
          postureReminderIntervalMinutes ?? this.postureReminderIntervalMinutes,
      postureReminderType: postureReminderType ?? this.postureReminderType,
      eyeBlinkReminderEnabled:
          eyeBlinkReminderEnabled ?? this.eyeBlinkReminderEnabled,
      eyeBlinkReminderIntervalMinutes:
          eyeBlinkReminderIntervalMinutes ??
          this.eyeBlinkReminderIntervalMinutes,
      eyeBlinkReminderType: eyeBlinkReminderType ?? this.eyeBlinkReminderType,
      showOnAllDisplays: showOnAllDisplays ?? this.showOnAllDisplays,
      breakTheme: breakTheme ?? this.breakTheme,
      breakTemplate: breakTemplate ?? this.breakTemplate,
      showExercisesInBreak: showExercisesInBreak ?? this.showExercisesInBreak,
      lastExerciseDate: lastExerciseDate ?? this.lastExerciseDate,
      shownExercisesToday: shownExercisesToday ?? this.shownExercisesToday,
      playMusicDuringBreak: playMusicDuringBreak ?? this.playMusicDuringBreak,
      autoPauseMedia: autoPauseMedia ?? this.autoPauseMedia,
      clockFaceTextColorHex:
          clockFaceTextColorHex ?? this.clockFaceTextColorHex,
      clockFaceBlurEnabled: clockFaceBlurEnabled ?? this.clockFaceBlurEnabled,
      customImagePath: customImagePath ?? this.customImagePath,
      resetTimerAfterMinutes:
          resetTimerAfterMinutes ?? this.resetTimerAfterMinutes,
      workingHoursEnabled: workingHoursEnabled ?? this.workingHoursEnabled,
      workingDays: workingDays ?? this.workingDays,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      detectVideoCalls: detectVideoCalls ?? this.detectVideoCalls,
      detectMeetings: detectMeetings ?? this.detectMeetings,
      respectFocusMode: respectFocusMode ?? this.respectFocusMode,
      enableClockOut: enableClockOut ?? this.enableClockOut,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      exercises: exercises ?? this.exercises,
      autoSuggestExercises: autoSuggestExercises ?? this.autoSuggestExercises,
      useCursorCountdown: useCursorCountdown ?? this.useCursorCountdown,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      trayIconStyle: trayIconStyle ?? this.trayIconStyle,
      companionEnabled: companionEnabled ?? this.companionEnabled,
      companionPetTheme: companionPetTheme ?? this.companionPetTheme,
      companionPetName: companionPetName ?? this.companionPetName,
      companionScale: companionScale ?? this.companionScale,
      companionClickThrough:
          companionClickThrough ?? this.companionClickThrough,
      companionFollowMouse: companionFollowMouse ?? this.companionFollowMouse,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      quietModeEnabled: quietModeEnabled ?? this.quietModeEnabled,
      quietModePreset: quietModePreset ?? this.quietModePreset,
      lastSnoozeDurationMinutes:
          lastSnoozeDurationMinutes ?? this.lastSnoozeDurationMinutes,
      intensityLevel: intensityLevel ?? this.intensityLevel,
    );
  }

  Map<String, dynamic> toMap() => {
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
    'eyeBlinkReminderType': eyeBlinkReminderType,
    'showOnAllDisplays': showOnAllDisplays,
    'breakTheme': breakTheme,
    'breakTemplate': breakTemplate,
    'showExercisesInBreak': showExercisesInBreak,
    'lastExerciseDate': lastExerciseDate,
    'shownExercisesToday': shownExercisesToday,
    'playMusicDuringBreak': playMusicDuringBreak,
    'autoPauseMedia': autoPauseMedia,
    'clockFaceTextColorHex': clockFaceTextColorHex,
    'clockFaceBlurEnabled': clockFaceBlurEnabled,
    'customImagePath': customImagePath,
    'resetTimerAfterMinutes': resetTimerAfterMinutes,
    'workingHoursEnabled': workingHoursEnabled,
    'workingDays': workingDays,
    'workStartTime': workStartTime,
    'workEndTime': workEndTime,
    'detectVideoCalls': detectVideoCalls,
    'detectMeetings': detectMeetings,
    'respectFocusMode': respectFocusMode,
    'enableClockOut': enableClockOut,
    'clockOutTime': clockOutTime,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'autoSuggestExercises': autoSuggestExercises,
    'useCursorCountdown': useCursorCountdown,
    'enableAnimations': enableAnimations,
    'trayIconStyle': trayIconStyle,
    'companionEnabled': companionEnabled,
    'companionPetTheme': companionPetTheme,
    'companionPetName': companionPetName,
    'companionScale': companionScale,
    'companionClickThrough': companionClickThrough,
    'companionFollowMouse': companionFollowMouse,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'quietModeEnabled': quietModeEnabled,
    'quietModePreset': quietModePreset,
    'lastSnoozeDurationMinutes': lastSnoozeDurationMinutes,
    'intensityLevel': intensityLevel,
  };

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    List<ExerciseModel> exercises = [];
    final rawExercises = map['exercises'];
    if (rawExercises is List) {
      exercises = rawExercises
          .whereType<Map<String, dynamic>>()
          .map(ExerciseModel.fromMap)
          .toList();
    }

    return SettingsModel(
      autoStart: map['autoStart'] as bool? ?? true,
      clockFaceStyle: map['clockFaceStyle'] as String? ?? 'breakloop',
      selectedProfileId: map['selectedProfileId'] as String? ?? 'default',
      strictMode: map['strictMode'] as bool? ?? false,
      remindClockOutEnabled: map['remindClockOutEnabled'] as bool? ?? false,
      dailyWorkGoalHours: map['dailyWorkGoalHours'] as int? ?? 8,
      pauseTimerAfterMinutes: map['pauseTimerAfterMinutes'] as int? ?? 5,
      menuBarStyle: map['menuBarStyle'] as String? ?? 'countdown',
      focusModeEnabled: map['focusModeEnabled'] as bool? ?? false,
      shortBreakIntervalMinutes: map['shortBreakIntervalMinutes'] as int? ?? 20,
      shortBreakDurationSeconds: map['shortBreakDurationSeconds'] as int? ?? 20,
      preBreakWarningSeconds: map['preBreakWarningSeconds'] as int? ?? 20,
      longBreakIntervalMinutes: map['longBreakIntervalMinutes'] as int? ?? 60,
      longBreakDurationMinutes: map['longBreakDurationMinutes'] as int? ?? 5,

      soundEnabled: map['soundEnabled'] as bool? ?? true,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      postureReminderEnabled: map['postureReminderEnabled'] as bool? ?? false,
      postureReminderIntervalMinutes:
          map['postureReminderIntervalMinutes'] as int? ?? 30,
      postureReminderType: map['postureReminderType'] as String? ?? 'overlay',
      eyeBlinkReminderEnabled: map['eyeBlinkReminderEnabled'] as bool? ?? false,
      eyeBlinkReminderIntervalMinutes:
          map['eyeBlinkReminderIntervalMinutes'] as int? ?? 20,
      eyeBlinkReminderType: map['eyeBlinkReminderType'] as String? ?? 'overlay',
      showOnAllDisplays: map['showOnAllDisplays'] as bool? ?? true,
      breakTheme: map['breakTheme'] as String? ?? 'random',
      breakTemplate: map['breakTemplate'] as String? ?? 'minimal',
      showExercisesInBreak: map['showExercisesInBreak'] as bool? ?? true,
      lastExerciseDate: map['lastExerciseDate'] as String? ?? '',
      shownExercisesToday:
          (map['shownExercisesToday'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      playMusicDuringBreak: map['playMusicDuringBreak'] as bool? ?? true,
      autoPauseMedia: map['autoPauseMedia'] as bool? ?? true,
      clockFaceTextColorHex: map['clockFaceTextColorHex'] as int? ?? 0xFFFFFFFF,
      clockFaceBlurEnabled: map['clockFaceBlurEnabled'] as bool? ?? true,
      customImagePath: map['customImagePath'] as String?,
      resetTimerAfterMinutes: map['resetTimerAfterMinutes'] as int? ?? 15,
      workingHoursEnabled: map['workingHoursEnabled'] as bool? ?? false,
      workingDays:
          (map['workingDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [1, 2, 3, 4, 5],
      workStartTime: map['workStartTime'] as String? ?? '09:00',
      workEndTime: map['workEndTime'] as String? ?? '18:00',
      detectVideoCalls: map['detectVideoCalls'] as bool? ?? true,
      detectMeetings: map['detectMeetings'] as bool? ?? true,
      respectFocusMode: map['respectFocusMode'] as bool? ?? true,
      enableClockOut: map['enableClockOut'] as bool? ?? false,
      clockOutTime: map['clockOutTime'] as String? ?? '17:00',
      exercises: exercises,
      autoSuggestExercises: map['autoSuggestExercises'] as bool? ?? true,
      useCursorCountdown: map['useCursorCountdown'] as bool? ?? true,
      enableAnimations: map['enableAnimations'] as bool? ?? true,
      trayIconStyle: (map['trayIconStyle'] as String? ?? 'companion') == 'cat'
          ? 'companion'
          : (map['trayIconStyle'] as String? ?? 'companion'),
      companionEnabled: map['companionEnabled'] as bool? ?? false,
      companionPetTheme:
          (map['companionPetTheme'] ?? map['companionCatTheme']) as String? ??
          'grey_cat',
      companionPetName: map['companionPetName'] as String? ?? 'Mochi',
      companionScale: (map['companionScale'] as num?)?.toDouble() ?? 6.0,
      companionClickThrough: map['companionClickThrough'] as bool? ?? false,
      companionFollowMouse: map['companionFollowMouse'] as bool? ?? false,
      hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? false,
      quietModeEnabled: map['quietModeEnabled'] as bool? ?? false,
      quietModePreset: map['quietModePreset'] as String? ?? 'none',
      lastSnoozeDurationMinutes: map['lastSnoozeDurationMinutes'] as int? ?? 5,
      intensityLevel: map['intensityLevel'] as String? ?? 'standard',
    );
  }
}
