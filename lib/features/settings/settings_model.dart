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

  // Missing Original Features
  final bool soundEnabled;
  final bool notificationsEnabled;
  final int clockFaceTextColorHex;
  final bool clockFaceBlurEnabled;
  final String? customImagePath;
  final int resetTimerAfterMinutes;
  final bool workingHoursEnabled;
  final bool autoSuggestExercises;

  // New Features
  final bool detectVideoCalls;
  final bool detectMeetings;
  final bool respectFocusMode;
  final List<String> customExercises;
  final bool enableClockOut;
  final String clockOutTime;
  final bool useCursorCountdown;

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
    this.flashMessage = 'Take a deep breath',
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
    this.autoSuggestExercises = false,

    this.detectVideoCalls = true,
    this.detectMeetings = true,
    this.respectFocusMode = true,
    this.customExercises = const [],
    this.enableClockOut = false,
    this.clockOutTime = '17:00',
    this.useCursorCountdown = true,
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
    bool? autoSuggestExercises,

    bool? detectVideoCalls,
    bool? detectMeetings,
    bool? respectFocusMode,
    List<String>? customExercises,
    bool? enableClockOut,
    String? clockOutTime,
    bool? useCursorCountdown,
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
      autoSuggestExercises: autoSuggestExercises ?? this.autoSuggestExercises,

      detectVideoCalls: detectVideoCalls ?? this.detectVideoCalls,
      detectMeetings: detectMeetings ?? this.detectMeetings,
      respectFocusMode: respectFocusMode ?? this.respectFocusMode,
      customExercises: customExercises ?? this.customExercises,
      enableClockOut: enableClockOut ?? this.enableClockOut,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      useCursorCountdown: useCursorCountdown ?? this.useCursorCountdown,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'autoSuggestExercises': autoSuggestExercises,

      'detectVideoCalls': detectVideoCalls,
      'detectMeetings': detectMeetings,
      'respectFocusMode': respectFocusMode,
      'customExercises': customExercises,
      'enableClockOut': enableClockOut,
      'clockOutTime': clockOutTime,
      'useCursorCountdown': useCursorCountdown,
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
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
      flashMessage: map['flashMessage'] as String? ?? 'Take a deep breath',
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
      autoSuggestExercises: map['autoSuggestExercises'] as bool? ?? false,

      detectVideoCalls: map['detectVideoCalls'] as bool? ?? true,
      detectMeetings: map['detectMeetings'] as bool? ?? true,
      respectFocusMode: map['respectFocusMode'] as bool? ?? true,
      customExercises: (map['customExercises'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      enableClockOut: map['enableClockOut'] as bool? ?? false,
      clockOutTime: map['clockOutTime'] as String? ?? '17:00',
      useCursorCountdown: map['useCursorCountdown'] as bool? ?? true,
    );
  }
}
