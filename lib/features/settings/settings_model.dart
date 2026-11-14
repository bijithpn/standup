import 'experience_preferences.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'work_schedule.dart';

/// Immutable snapshot of every user setting; changed via [copyWith] and persisted by [SettingsRepository].
class SettingsModel {
  final ExperiencePreferences experience;
  final bool autoStart;
  final String clockFaceStyle;
  final String selectedProfileId;
  final bool strictMode;
  final bool remindClockOutEnabled;
  final int dailyWorkGoalHours;
  final int pauseTimerAfterMinutes;
  final String menuBarStyle;

  final int shortBreakIntervalMinutes;
  final int shortBreakDurationSeconds;
  final int preBreakWarningSeconds;
  final int longBreakIntervalMinutes;
  final int longBreakDurationMinutes;

  final bool soundEnabled;
  final bool notificationsEnabled;
  final bool postureReminderEnabled;
  final String postureReminderType;
  final bool eyeBlinkReminderEnabled;
  final String eyeBlinkReminderType;

  final bool showOnAllDisplays;
  final String breakTheme;
  final String breakTemplate;
  final bool showExercisesInBreak;
  final String lastExerciseDate;
  final List<String> shownExercisesToday;
  final bool playMusicDuringBreak;
  final bool autoPauseMedia;

  final int clockFaceTextColorHex;
  final bool clockFaceBlurEnabled;

  final String overlayThemeMode;

  final String breathPreset;

  final bool breakChimeEnabled;

  final List<CustomReminder> customReminders;

  final bool reduceMotion;

  final bool eveningEyeCare;

  final bool focusDndEnabled;

  final bool blinkRemindersEnabled;
  final bool dismissReminderOnMouseMove;

  final int avoidBreakHour;

  final bool largeOverlayText;

  final bool lookedAwayPromptEnabled;
  final String? customImagePath;

  final int resetTimerAfterMinutes;

  final Map<int, WorkSchedule> weeklySchedule;
  final bool workingHoursEnabled;
  final List<int> workingDays;
  final String workStartTime;
  final String workEndTime;

  final bool detectVideoCalls;
  final bool detectMeetings;
  final bool globalHotkeyEnabled;
  final bool presentationPauseEnabled;

  final bool enableClockOut;
  final String clockOutTime;

  final List<ExerciseModel> exercises;

  final bool autoSuggestExercises;
  final bool useCursorCountdown;
  final bool enableAnimations;
  final String trayIconStyle;
  final bool companionEnabled;
  final bool pipModeEnabled;
  final String companionPetTheme;
  final String companionPetName;
  final double companionScale;
  final bool companionClickThrough;
  final bool companionFollowMouse;

  final bool companionWanderingEnabled;
  final String companionPreviewBackground;
  final List<String> unlockedPets;

  final String? companionAvatarDefinition;

  final bool companionKeepOnScreen;

  final double companionWindowWidth;
  final double companionWindowHeight;
  final double? companionWindowX;
  final double? companionWindowY;

  final String pipBackgroundStyle;
  final double pipOpacity;
  final bool pipDraggableClickable;
  final bool hydrationReminderEnabled;
  final bool stretchReminderEnabled;
  final bool standUpReminderEnabled;

  bool get healthRemindersEnabled =>
      eyeBlinkReminderEnabled ||
      postureReminderEnabled ||
      hydrationReminderEnabled ||
      stretchReminderEnabled ||
      standUpReminderEnabled;

  final String companionToyType;
  final String companionTreatType;

  final Map<String, int> templateAccentOverrides;

  final bool pettingEnabled;

  final bool companionGazeEnabled;

  final double companionGazeSensitivity;

  final bool companionIdleAnimation;

  final bool companionReactions;

  final bool companionReducedMotion;
  final bool ballThrowEnabled;
  final bool treatEnabled;
  final bool developerReactions;
  final bool quietModeAutoActivate;

  final bool hasCompletedOnboarding;
  final bool quietModeEnabled;
  final String quietModePreset;
  final int lastSnoozeDurationMinutes;
  final String intensityLevel;

  final int dailyBreakGoalCount;
  final int maxContinuousSittingMinutes;
  final int weeklyConsistencyTargetDays;
  final bool calendarEnabled;

  final bool enableSessionResume;

  final bool appUsageTrackingEnabled;

  final int activityHistoryRetentionDays;

  final Map<String, int> categoryDailyBudgetMinutes;

  const SettingsModel({
    this.experience = const ExperiencePreferences(),
    this.autoStart = true,
    this.clockFaceStyle = 'breakloop',
    this.selectedProfileId = 'default',
    this.strictMode = false,
    this.remindClockOutEnabled = false,
    this.dailyWorkGoalHours = 8,
    this.pauseTimerAfterMinutes = 5,
    this.menuBarStyle = 'countdown',
    this.shortBreakIntervalMinutes = 20,
    this.shortBreakDurationSeconds = 20,
    this.preBreakWarningSeconds = 3,
    this.longBreakIntervalMinutes = 60,
    this.longBreakDurationMinutes = 1,

    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.postureReminderEnabled = false,
    this.postureReminderType = 'overlay',
    this.eyeBlinkReminderEnabled = false,
    this.eyeBlinkReminderType = 'overlay',
    this.showOnAllDisplays = true,
    this.breakTheme = 'random',
    this.breakTemplate = 'minimal',
    this.clockFaceTextColorHex = 0xFFFFFFFF,
    this.clockFaceBlurEnabled = true,
    this.overlayThemeMode = 'dark',
    this.breathPreset = 'box',
    this.breakChimeEnabled = false,
    this.customReminders = const [],
    this.reduceMotion = false,
    this.eveningEyeCare = false,
    this.focusDndEnabled = false,
    this.blinkRemindersEnabled = false,
    this.dismissReminderOnMouseMove = false,
    this.avoidBreakHour = -1,
    this.largeOverlayText = false,
    this.lookedAwayPromptEnabled = false,
    this.customImagePath,
    this.resetTimerAfterMinutes = 15,
    this.weeklySchedule = const {},
    this.workingHoursEnabled = false,
    this.workingDays = const [1, 2, 3, 4, 5],
    this.workStartTime = '09:00',
    this.workEndTime = '18:00',
    this.detectVideoCalls = true,
    this.detectMeetings = true,
    this.globalHotkeyEnabled = true,
    this.presentationPauseEnabled = false,
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
    this.pipModeEnabled = true,
    this.companionPetTheme = 'grey_cat',
    this.companionPetName = 'Mochi',
    this.companionScale = 6.0,
    this.companionClickThrough = false,
    this.companionFollowMouse = false,
    this.companionWanderingEnabled = true,
    this.companionPreviewBackground = '',
    this.unlockedPets = const ['grey_cat', 'orange_cat', 'black_cat'],
    this.companionAvatarDefinition,
    this.companionKeepOnScreen = true,
    this.companionWindowWidth = 280.0,
    this.companionWindowHeight = 320.0,
    this.companionWindowX,
    this.companionWindowY,
    this.pipBackgroundStyle = 'scene',
    this.pipOpacity = 1.0,
    this.pipDraggableClickable = true,
    this.hydrationReminderEnabled = false,
    this.stretchReminderEnabled = false,
    this.standUpReminderEnabled = false,
    this.companionToyType = 'tennis_ball',
    this.companionTreatType = 'sushi',
    this.templateAccentOverrides = const {},
    this.pettingEnabled = true,
    this.companionGazeEnabled = true,
    this.companionGazeSensitivity = 0.5,
    this.companionIdleAnimation = true,
    this.companionReactions = true,
    this.companionReducedMotion = false,
    this.ballThrowEnabled = true,
    this.treatEnabled = true,
    this.developerReactions = true,
    this.quietModeAutoActivate = true,
    this.hasCompletedOnboarding = false,
    this.quietModeEnabled = false,
    this.quietModePreset = 'none',
    this.lastSnoozeDurationMinutes = 5,
    this.intensityLevel = 'standard',

    this.dailyBreakGoalCount = 10,
    this.maxContinuousSittingMinutes = 60,
    this.weeklyConsistencyTargetDays = 5,
    this.calendarEnabled = false,
    this.enableSessionResume = true,
    this.appUsageTrackingEnabled = false,
    this.activityHistoryRetentionDays = 30,
    this.categoryDailyBudgetMinutes = const {},
  });

  SettingsModel copyWith({
    ExperiencePreferences? experience,
    bool? autoStart,
    String? clockFaceStyle,
    String? selectedProfileId,
    bool? strictMode,
    bool? remindClockOutEnabled,
    int? dailyWorkGoalHours,
    int? pauseTimerAfterMinutes,
    String? menuBarStyle,
    int? shortBreakIntervalMinutes,
    int? shortBreakDurationSeconds,
    int? preBreakWarningSeconds,
    int? longBreakIntervalMinutes,
    int? longBreakDurationMinutes,

    bool? soundEnabled,
    bool? notificationsEnabled,
    bool? postureReminderEnabled,
    String? postureReminderType,
    bool? eyeBlinkReminderEnabled,
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
    String? overlayThemeMode,
    String? breathPreset,
    bool? breakChimeEnabled,
    List<CustomReminder>? customReminders,
    bool? reduceMotion,
    bool? eveningEyeCare,
    bool? focusDndEnabled,
    bool? blinkRemindersEnabled,
    bool? dismissReminderOnMouseMove,
    int? avoidBreakHour,
    bool? largeOverlayText,
    bool? lookedAwayPromptEnabled,
    String? customImagePath,
    int? resetTimerAfterMinutes,
    Map<int, WorkSchedule>? weeklySchedule,
    bool? workingHoursEnabled,
    List<int>? workingDays,
    String? workStartTime,
    String? workEndTime,
    bool? detectVideoCalls,
    bool? detectMeetings,
    bool? globalHotkeyEnabled,
    bool? presentationPauseEnabled,
    bool? enableClockOut,
    String? clockOutTime,
    List<ExerciseModel>? exercises,
    bool? autoSuggestExercises,
    bool? useCursorCountdown,
    bool? enableAnimations,
    String? trayIconStyle,
    bool? companionEnabled,
    bool? pipModeEnabled,
    String? companionPetTheme,
    String? companionPetName,
    double? companionScale,
    bool? companionClickThrough,
    bool? companionFollowMouse,
    bool? companionWanderingEnabled,
    String? companionPreviewBackground,
    List<String>? unlockedPets,
    String? companionAvatarDefinition,
    bool? companionKeepOnScreen,
    double? companionWindowWidth,
    double? companionWindowHeight,
    double? companionWindowX,
    double? companionWindowY,
    bool? pettingEnabled,
    bool? companionGazeEnabled,
    double? companionGazeSensitivity,
    bool? companionIdleAnimation,
    bool? companionReactions,
    bool? companionReducedMotion,
    bool? ballThrowEnabled,
    bool? treatEnabled,
    bool? developerReactions,
    bool? quietModeAutoActivate,
    bool? hasCompletedOnboarding,
    bool? quietModeEnabled,
    String? quietModePreset,
    int? lastSnoozeDurationMinutes,
    String? intensityLevel,
    int? dailyBreakGoalCount,
    int? maxContinuousSittingMinutes,
    int? weeklyConsistencyTargetDays,
    bool? calendarEnabled,
    bool? enableSessionResume,
    bool? appUsageTrackingEnabled,
    int? activityHistoryRetentionDays,
    Map<String, int>? categoryDailyBudgetMinutes,
    String? pipBackgroundStyle,
    double? pipOpacity,
    bool? pipDraggableClickable,
    bool? healthRemindersEnabled,
    bool? hydrationReminderEnabled,
    bool? stretchReminderEnabled,
    bool? standUpReminderEnabled,
    String? companionToyType,
    String? companionTreatType,
    Map<String, int>? templateAccentOverrides,
  }) {
    return SettingsModel(
      experience: experience ?? this.experience,
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
          healthRemindersEnabled ??
          postureReminderEnabled ??
          this.postureReminderEnabled,
      postureReminderType: postureReminderType ?? this.postureReminderType,
      eyeBlinkReminderEnabled:
          healthRemindersEnabled ??
          eyeBlinkReminderEnabled ??
          this.eyeBlinkReminderEnabled,
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
      overlayThemeMode: overlayThemeMode ?? this.overlayThemeMode,
      breathPreset: breathPreset ?? this.breathPreset,
      breakChimeEnabled: breakChimeEnabled ?? this.breakChimeEnabled,
      customReminders: customReminders ?? this.customReminders,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      eveningEyeCare: eveningEyeCare ?? this.eveningEyeCare,
      focusDndEnabled: focusDndEnabled ?? this.focusDndEnabled,
      blinkRemindersEnabled:
          blinkRemindersEnabled ?? this.blinkRemindersEnabled,
      dismissReminderOnMouseMove:
          dismissReminderOnMouseMove ?? this.dismissReminderOnMouseMove,
      avoidBreakHour: avoidBreakHour ?? this.avoidBreakHour,
      largeOverlayText: largeOverlayText ?? this.largeOverlayText,
      lookedAwayPromptEnabled:
          lookedAwayPromptEnabled ?? this.lookedAwayPromptEnabled,
      customImagePath: customImagePath != null
          ? (customImagePath == "" ? null : customImagePath)
          : this.customImagePath,
      resetTimerAfterMinutes:
          resetTimerAfterMinutes ?? this.resetTimerAfterMinutes,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      workingHoursEnabled: workingHoursEnabled ?? this.workingHoursEnabled,
      workingDays: workingDays ?? this.workingDays,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      detectVideoCalls: detectVideoCalls ?? this.detectVideoCalls,
      detectMeetings: detectMeetings ?? this.detectMeetings,
      globalHotkeyEnabled: globalHotkeyEnabled ?? this.globalHotkeyEnabled,
      presentationPauseEnabled:
          presentationPauseEnabled ?? this.presentationPauseEnabled,
      enableClockOut: enableClockOut ?? this.enableClockOut,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      exercises: exercises ?? this.exercises,
      autoSuggestExercises: autoSuggestExercises ?? this.autoSuggestExercises,
      useCursorCountdown: useCursorCountdown ?? this.useCursorCountdown,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      trayIconStyle: trayIconStyle ?? this.trayIconStyle,
      companionEnabled: companionEnabled ?? this.companionEnabled,
      pipModeEnabled: pipModeEnabled ?? this.pipModeEnabled,
      companionPetTheme: companionPetTheme ?? this.companionPetTheme,
      companionPetName: companionPetName ?? this.companionPetName,
      companionScale: companionScale ?? this.companionScale,
      companionClickThrough:
          companionClickThrough ?? this.companionClickThrough,
      companionFollowMouse: companionFollowMouse ?? this.companionFollowMouse,
      companionWanderingEnabled:
          companionWanderingEnabled ?? this.companionWanderingEnabled,
      companionPreviewBackground:
          companionPreviewBackground ?? this.companionPreviewBackground,
      unlockedPets: unlockedPets ?? this.unlockedPets,
      companionAvatarDefinition:
          companionAvatarDefinition ?? this.companionAvatarDefinition,
      companionKeepOnScreen:
          companionKeepOnScreen ?? this.companionKeepOnScreen,
      companionWindowWidth: companionWindowWidth ?? this.companionWindowWidth,
      companionWindowHeight:
          companionWindowHeight ?? this.companionWindowHeight,
      companionWindowX: companionWindowX ?? this.companionWindowX,
      companionWindowY: companionWindowY ?? this.companionWindowY,
      pettingEnabled: pettingEnabled ?? this.pettingEnabled,
      companionGazeEnabled: companionGazeEnabled ?? this.companionGazeEnabled,
      companionGazeSensitivity:
          companionGazeSensitivity ?? this.companionGazeSensitivity,
      companionIdleAnimation:
          companionIdleAnimation ?? this.companionIdleAnimation,
      companionReactions: companionReactions ?? this.companionReactions,
      companionReducedMotion:
          companionReducedMotion ?? this.companionReducedMotion,
      ballThrowEnabled: ballThrowEnabled ?? this.ballThrowEnabled,
      treatEnabled: treatEnabled ?? this.treatEnabled,
      developerReactions: developerReactions ?? this.developerReactions,
      quietModeAutoActivate:
          quietModeAutoActivate ?? this.quietModeAutoActivate,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      quietModeEnabled: quietModeEnabled ?? this.quietModeEnabled,
      quietModePreset: quietModePreset ?? this.quietModePreset,
      lastSnoozeDurationMinutes:
          lastSnoozeDurationMinutes ?? this.lastSnoozeDurationMinutes,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      dailyBreakGoalCount: dailyBreakGoalCount ?? this.dailyBreakGoalCount,
      maxContinuousSittingMinutes:
          maxContinuousSittingMinutes ?? this.maxContinuousSittingMinutes,
      weeklyConsistencyTargetDays:
          weeklyConsistencyTargetDays ?? this.weeklyConsistencyTargetDays,
      calendarEnabled: calendarEnabled ?? this.calendarEnabled,
      enableSessionResume: enableSessionResume ?? this.enableSessionResume,
      appUsageTrackingEnabled:
          appUsageTrackingEnabled ?? this.appUsageTrackingEnabled,
      activityHistoryRetentionDays:
          activityHistoryRetentionDays ?? this.activityHistoryRetentionDays,
      categoryDailyBudgetMinutes:
          categoryDailyBudgetMinutes ?? this.categoryDailyBudgetMinutes,
      pipBackgroundStyle: pipBackgroundStyle ?? this.pipBackgroundStyle,
      pipOpacity: pipOpacity ?? this.pipOpacity,
      pipDraggableClickable:
          pipDraggableClickable ?? this.pipDraggableClickable,
      hydrationReminderEnabled:
          healthRemindersEnabled ??
          hydrationReminderEnabled ??
          this.hydrationReminderEnabled,
      stretchReminderEnabled:
          healthRemindersEnabled ??
          stretchReminderEnabled ??
          this.stretchReminderEnabled,
      standUpReminderEnabled:
          healthRemindersEnabled ??
          standUpReminderEnabled ??
          this.standUpReminderEnabled,
      companionToyType: companionToyType ?? this.companionToyType,
      companionTreatType: companionTreatType ?? this.companionTreatType,
      templateAccentOverrides:
          templateAccentOverrides ?? this.templateAccentOverrides,
    );
  }

  Map<String, dynamic> toMap() => {
    'experience': experience.toMap(),
    'autoStart': autoStart,
    'clockFaceStyle': clockFaceStyle,
    'selectedProfileId': selectedProfileId,
    'strictMode': strictMode,
    'remindClockOutEnabled': remindClockOutEnabled,
    'dailyWorkGoalHours': dailyWorkGoalHours,
    'pauseTimerAfterMinutes': pauseTimerAfterMinutes,
    'menuBarStyle': menuBarStyle,
    'shortBreakIntervalMinutes': shortBreakIntervalMinutes,
    'shortBreakDurationSeconds': shortBreakDurationSeconds,
    'preBreakWarningSeconds': preBreakWarningSeconds,
    'longBreakIntervalMinutes': longBreakIntervalMinutes,
    'longBreakDurationMinutes': longBreakDurationMinutes,

    'soundEnabled': soundEnabled,
    'notificationsEnabled': notificationsEnabled,
    'postureReminderEnabled': postureReminderEnabled,
    'postureReminderType': postureReminderType,
    'eyeBlinkReminderEnabled': eyeBlinkReminderEnabled,
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
    'overlayThemeMode': overlayThemeMode,
    'breathPreset': breathPreset,
    'breakChimeEnabled': breakChimeEnabled,
    'customReminders': [for (final r in customReminders) r.toJson()],
    'reduceMotion': reduceMotion,
    'eveningEyeCare': eveningEyeCare,
    'focusDndEnabled': focusDndEnabled,
    'blinkRemindersEnabled': blinkRemindersEnabled,
    'dismissReminderOnMouseMove': dismissReminderOnMouseMove,
    'avoidBreakHour': avoidBreakHour,
    'largeOverlayText': largeOverlayText,
    'lookedAwayPromptEnabled': lookedAwayPromptEnabled,
    'customImagePath': customImagePath,
    'resetTimerAfterMinutes': resetTimerAfterMinutes,
    'weeklySchedule': weeklySchedule.map(
      (day, shift) => MapEntry('$day', shift.toJson()),
    ),
    'workingHoursEnabled': workingHoursEnabled,
    'workingDays': workingDays,
    'workStartTime': workStartTime,
    'workEndTime': workEndTime,
    'detectVideoCalls': detectVideoCalls,
    'detectMeetings': detectMeetings,
    'globalHotkeyEnabled': globalHotkeyEnabled,
    'presentationPauseEnabled': presentationPauseEnabled,
    'enableClockOut': enableClockOut,
    'clockOutTime': clockOutTime,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'autoSuggestExercises': autoSuggestExercises,
    'useCursorCountdown': useCursorCountdown,
    'enableAnimations': enableAnimations,
    'trayIconStyle': trayIconStyle,
    'companionEnabled': companionEnabled,
    'pipModeEnabled': pipModeEnabled,
    'companionPetTheme': companionPetTheme,
    'companionPetName': companionPetName,
    'companionScale': companionScale,
    'companionClickThrough': companionClickThrough,
    'companionFollowMouse': companionFollowMouse,
    'companionWanderingEnabled': companionWanderingEnabled,
    'companionPreviewBackground': companionPreviewBackground,
    'unlockedPets': unlockedPets,
    'companionAvatarDefinition': companionAvatarDefinition,
    'companionKeepOnScreen': companionKeepOnScreen,
    'pettingEnabled': pettingEnabled,
    'companionGazeEnabled': companionGazeEnabled,
    'companionGazeSensitivity': companionGazeSensitivity,
    'companionIdleAnimation': companionIdleAnimation,
    'companionReactions': companionReactions,
    'companionReducedMotion': companionReducedMotion,
    'ballThrowEnabled': ballThrowEnabled,
    'treatEnabled': treatEnabled,
    'developerReactions': developerReactions,
    'quietModeAutoActivate': quietModeAutoActivate,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'quietModeEnabled': quietModeEnabled,
    'quietModePreset': quietModePreset,
    'lastSnoozeDurationMinutes': lastSnoozeDurationMinutes,
    'intensityLevel': intensityLevel,
    'dailyBreakGoalCount': dailyBreakGoalCount,
    'maxContinuousSittingMinutes': maxContinuousSittingMinutes,
    'weeklyConsistencyTargetDays': weeklyConsistencyTargetDays,
    'calendarEnabled': calendarEnabled,
    'enableSessionResume': enableSessionResume,
    'appUsageTrackingEnabled': appUsageTrackingEnabled,
    'activityHistoryRetentionDays': activityHistoryRetentionDays,
    'categoryDailyBudgetMinutes': categoryDailyBudgetMinutes,
    'pipBackgroundStyle': pipBackgroundStyle,
    'pipOpacity': pipOpacity,
    'pipDraggableClickable': pipDraggableClickable,
    'hydrationReminderEnabled': hydrationReminderEnabled,
    'stretchReminderEnabled': stretchReminderEnabled,
    'standUpReminderEnabled': standUpReminderEnabled,
    'companionToyType': companionToyType,
    'companionTreatType': companionTreatType,
    'templateAccentOverrides': templateAccentOverrides,
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
      experience: ExperiencePreferences.fromMap(map['experience']),
      autoStart: map['autoStart'] as bool? ?? true,
      clockFaceStyle: map['clockFaceStyle'] as String? ?? 'breakloop',
      selectedProfileId: map['selectedProfileId'] as String? ?? 'default',
      strictMode: map['strictMode'] as bool? ?? false,
      remindClockOutEnabled: map['remindClockOutEnabled'] as bool? ?? false,
      dailyWorkGoalHours: map['dailyWorkGoalHours'] as int? ?? 8,
      pauseTimerAfterMinutes: map['pauseTimerAfterMinutes'] as int? ?? 5,
      menuBarStyle: map['menuBarStyle'] as String? ?? 'countdown',
      shortBreakIntervalMinutes: map['shortBreakIntervalMinutes'] as int? ?? 20,
      shortBreakDurationSeconds: map['shortBreakDurationSeconds'] as int? ?? 20,
      preBreakWarningSeconds: map['preBreakWarningSeconds'] as int? ?? 3,
      longBreakIntervalMinutes: map['longBreakIntervalMinutes'] as int? ?? 60,
      longBreakDurationMinutes: map['longBreakDurationMinutes'] as int? ?? 1,

      soundEnabled: map['soundEnabled'] as bool? ?? true,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      postureReminderEnabled: map['postureReminderEnabled'] as bool? ?? false,
      postureReminderType: map['postureReminderType'] as String? ?? 'overlay',
      eyeBlinkReminderEnabled: map['eyeBlinkReminderEnabled'] as bool? ?? false,
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
      overlayThemeMode: map['overlayThemeMode'] as String? ?? 'dark',
      breathPreset: map['breathPreset'] as String? ?? 'box',
      breakChimeEnabled: map['breakChimeEnabled'] as bool? ?? false,
      reduceMotion: map['reduceMotion'] as bool? ?? false,
      eveningEyeCare: map['eveningEyeCare'] as bool? ?? false,
      focusDndEnabled: map['focusDndEnabled'] as bool? ?? false,
      blinkRemindersEnabled: map['blinkRemindersEnabled'] as bool? ?? false,
      dismissReminderOnMouseMove:
          map['dismissReminderOnMouseMove'] as bool? ?? false,
      avoidBreakHour: map['avoidBreakHour'] as int? ?? -1,
      largeOverlayText: map['largeOverlayText'] as bool? ?? false,
      customReminders: [
        for (final r in map['customReminders'] as List? ?? const [])
          CustomReminder.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
      lookedAwayPromptEnabled: map['lookedAwayPromptEnabled'] as bool? ?? false,
      customImagePath: map['customImagePath'] as String?,
      resetTimerAfterMinutes: map['resetTimerAfterMinutes'] as int? ?? 15,
      weeklySchedule: WorkSchedule.decode(map['weeklySchedule']),
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
      globalHotkeyEnabled: map['globalHotkeyEnabled'] as bool? ?? true,
      presentationPauseEnabled:
          map['presentationPauseEnabled'] as bool? ?? false,
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
      pipModeEnabled: map['pipModeEnabled'] as bool? ?? true,
      companionPetTheme:
          (map['companionPetTheme'] ?? map['companionCatTheme']) as String? ??
          'grey_cat',
      companionPetName: map['companionPetName'] as String? ?? 'Mochi',
      companionScale: (map['companionScale'] as num?)?.toDouble() ?? 6.0,
      companionClickThrough: map['companionClickThrough'] as bool? ?? false,
      companionFollowMouse: map['companionFollowMouse'] as bool? ?? false,
      companionWanderingEnabled:
          map['companionWanderingEnabled'] as bool? ?? true,
      companionPreviewBackground:
          map['companionPreviewBackground'] as String? ?? '',
      unlockedPets:
          (map['unlockedPets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['grey_cat', 'orange_cat', 'black_cat'],
      companionAvatarDefinition: map['companionAvatarDefinition'] as String?,
      companionKeepOnScreen: map['companionKeepOnScreen'] as bool? ?? true,
      pettingEnabled: map['pettingEnabled'] as bool? ?? true,
      companionGazeEnabled: map['companionGazeEnabled'] as bool? ?? true,
      companionGazeSensitivity:
          (map['companionGazeSensitivity'] as num?)?.toDouble() ?? 0.5,
      companionIdleAnimation: map['companionIdleAnimation'] as bool? ?? true,
      companionReactions: map['companionReactions'] as bool? ?? true,
      companionReducedMotion: map['companionReducedMotion'] as bool? ?? false,
      ballThrowEnabled: map['ballThrowEnabled'] as bool? ?? true,
      treatEnabled: map['treatEnabled'] as bool? ?? true,
      developerReactions: map['developerReactions'] as bool? ?? true,
      quietModeAutoActivate: map['quietModeAutoActivate'] as bool? ?? true,
      hasCompletedOnboarding: map['hasCompletedOnboarding'] as bool? ?? false,
      quietModeEnabled: map['quietModeEnabled'] as bool? ?? false,
      quietModePreset: map['quietModePreset'] as String? ?? 'none',
      lastSnoozeDurationMinutes: map['lastSnoozeDurationMinutes'] as int? ?? 5,
      intensityLevel: map['intensityLevel'] as String? ?? 'standard',
      dailyBreakGoalCount: map['dailyBreakGoalCount'] as int? ?? 10,
      maxContinuousSittingMinutes:
          map['maxContinuousSittingMinutes'] as int? ?? 60,
      weeklyConsistencyTargetDays:
          map['weeklyConsistencyTargetDays'] as int? ?? 5,
      calendarEnabled: map['calendarEnabled'] as bool? ?? false,
      enableSessionResume: map['enableSessionResume'] as bool? ?? true,
      appUsageTrackingEnabled: map['appUsageTrackingEnabled'] as bool? ?? false,
      activityHistoryRetentionDays:
          (map['activityHistoryRetentionDays'] as num?)?.toInt() ?? 30,
      categoryDailyBudgetMinutes:
          (map['categoryDailyBudgetMinutes'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          const {},
      pipBackgroundStyle: map['pipBackgroundStyle'] as String? ?? 'transparent',
      pipOpacity: (map['pipOpacity'] as num?)?.toDouble() ?? 1.0,
      pipDraggableClickable: map['pipDraggableClickable'] as bool? ?? true,
      hydrationReminderEnabled:
          map['hydrationReminderEnabled'] as bool? ?? false,
      stretchReminderEnabled: map['stretchReminderEnabled'] as bool? ?? false,
      standUpReminderEnabled: map['standUpReminderEnabled'] as bool? ?? false,
      companionToyType: map['companionToyType'] as String? ?? 'tennis_ball',
      companionTreatType: map['companionTreatType'] as String? ?? 'sushi',
      templateAccentOverrides:
          (map['templateAccentOverrides'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          const {},
    );
  }
}

/// User-defined recurring reminder (title + interval in minutes), stored as JSON.
class CustomReminder {
  final String title;
  final int minutes;

  const CustomReminder({required this.title, required this.minutes});

  Map<String, dynamic> toJson() => {'title': title, 'minutes': minutes};

  factory CustomReminder.fromJson(Map<String, dynamic> j) => CustomReminder(
    title: j['title'] as String? ?? '',
    minutes: j['minutes'] as int? ?? 60,
  );
}
