import 'package:standup/features/settings/exercise_model.dart';

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
  final int longBreakIntervalMinutes;
  final int longBreakDurationMinutes;

  // Flash settings
  final int flashColorHex;
  final String flashStyle;
  final String flashMessage;
  final String flashAnimationType;
  final double flashIntensity;
  final int flashDurationMs;

  // Notifications
  final bool soundEnabled;
  final bool notificationsEnabled;

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
  final String workEndTime;   // "HH:mm"

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
  final String trayIconStyle; // 'default', 'cat', 'minimal', 'countdown'
  final bool companionEnabled;
  final String companionCatTheme;
  final String companionPetName;
  final double companionScale;
  final bool companionClickThrough;

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
    this.longBreakIntervalMinutes = 60,
    this.longBreakDurationMinutes = 3,
    this.flashColorHex = 0xFFF87171,
    this.flashStyle = 'default',
    this.flashMessage = 'Look 20 feet away for 20 seconds',
    this.flashAnimationType = 'pulse',
    this.flashIntensity = 0.5,
    this.flashDurationMs = 2500,
    this.soundEnabled = true,
    this.notificationsEnabled = true,
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
    this.exercises = const [],
    this.autoSuggestExercises = true,
    this.useCursorCountdown = true,
    this.enableAnimations = true,
    this.trayIconStyle = 'cat',
    this.companionEnabled = false,
    this.companionCatTheme = 'grey_cat',
    this.companionPetName = 'Mochi',
    this.companionScale = 6.0,
    this.companionClickThrough = false,
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
    int? longBreakIntervalMinutes,
    int? longBreakDurationMinutes,
    int? flashColorHex,
    String? flashStyle,
    String? flashMessage,
    String? flashAnimationType,
    double? flashIntensity,
    int? flashDurationMs,
    bool? soundEnabled,
    bool? notificationsEnabled,
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
    String? companionCatTheme,
    String? companionPetName,
    double? companionScale,
    bool? companionClickThrough,
  }) {
    return SettingsModel(
      autoStart: autoStart ?? this.autoStart,
      clockFaceStyle: clockFaceStyle ?? this.clockFaceStyle,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      strictMode: strictMode ?? this.strictMode,
      remindClockOutEnabled: remindClockOutEnabled ?? this.remindClockOutEnabled,
      dailyWorkGoalHours: dailyWorkGoalHours ?? this.dailyWorkGoalHours,
      pauseTimerAfterMinutes: pauseTimerAfterMinutes ?? this.pauseTimerAfterMinutes,
      menuBarStyle: menuBarStyle ?? this.menuBarStyle,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      shortBreakIntervalMinutes: shortBreakIntervalMinutes ?? this.shortBreakIntervalMinutes,
      shortBreakDurationSeconds: shortBreakDurationSeconds ?? this.shortBreakDurationSeconds,
      longBreakIntervalMinutes: longBreakIntervalMinutes ?? this.longBreakIntervalMinutes,
      longBreakDurationMinutes: longBreakDurationMinutes ?? this.longBreakDurationMinutes,
      flashColorHex: flashColorHex ?? this.flashColorHex,
      flashStyle: flashStyle ?? this.flashStyle,
      flashMessage: flashMessage ?? this.flashMessage,
      flashAnimationType: flashAnimationType ?? this.flashAnimationType,
      flashIntensity: flashIntensity ?? this.flashIntensity,
      flashDurationMs: flashDurationMs ?? this.flashDurationMs,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      clockFaceTextColorHex: clockFaceTextColorHex ?? this.clockFaceTextColorHex,
      clockFaceBlurEnabled: clockFaceBlurEnabled ?? this.clockFaceBlurEnabled,
      customImagePath: customImagePath ?? this.customImagePath,
      resetTimerAfterMinutes: resetTimerAfterMinutes ?? this.resetTimerAfterMinutes,
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
      companionCatTheme: companionCatTheme ?? this.companionCatTheme,
      companionPetName: companionPetName ?? this.companionPetName,
      companionScale: companionScale ?? this.companionScale,
      companionClickThrough: companionClickThrough ?? this.companionClickThrough,
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
        'longBreakIntervalMinutes': longBreakIntervalMinutes,
        'longBreakDurationMinutes': longBreakDurationMinutes,
        'flashColorHex': flashColorHex,
        'flashStyle': flashStyle,
        'flashMessage': flashMessage,
        'flashAnimationType': flashAnimationType,
        'flashIntensity': flashIntensity,
        'flashDurationMs': flashDurationMs,
        'soundEnabled': soundEnabled,
        'notificationsEnabled': notificationsEnabled,
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
        'companionCatTheme': companionCatTheme,
        'companionPetName': companionPetName,
        'companionScale': companionScale,
        'companionClickThrough': companionClickThrough,
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
      longBreakIntervalMinutes: map['longBreakIntervalMinutes'] as int? ?? 60,
      longBreakDurationMinutes: map['longBreakDurationMinutes'] as int? ?? 3,
      flashColorHex: map['flashColorHex'] as int? ?? 0xFFF87171,
      flashStyle: map['flashStyle'] as String? ?? 'default',
      flashMessage: map['flashMessage'] as String? ?? 'Look 20 feet away for 20 seconds',
      flashAnimationType: map['flashAnimationType'] as String? ?? 'pulse',
      flashIntensity: (map['flashIntensity'] as num?)?.toDouble() ?? 0.5,
      flashDurationMs: map['flashDurationMs'] as int? ?? 2500,
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      clockFaceTextColorHex: map['clockFaceTextColorHex'] as int? ?? 0xFFFFFFFF,
      clockFaceBlurEnabled: map['clockFaceBlurEnabled'] as bool? ?? true,
      customImagePath: map['customImagePath'] as String?,
      resetTimerAfterMinutes: map['resetTimerAfterMinutes'] as int? ?? 15,
      workingHoursEnabled: map['workingHoursEnabled'] as bool? ?? false,
      workingDays: (map['workingDays'] as List<dynamic>?)
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
      trayIconStyle: map['trayIconStyle'] as String? ?? 'cat',
      companionEnabled: map['companionEnabled'] as bool? ?? false,
      companionCatTheme: map['companionCatTheme'] as String? ?? 'grey_cat',
      companionPetName: map['companionPetName'] as String? ?? 'Mochi',
      companionScale: (map['companionScale'] as num?)?.toDouble() ?? 6.0,
      companionClickThrough: map['companionClickThrough'] as bool? ?? false,
    );
  }
}
