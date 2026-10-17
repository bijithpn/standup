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

  final int shortBreakIntervalMinutes;
  final int shortBreakDurationSeconds;
  final int preBreakWarningSeconds;
  final int longBreakIntervalMinutes;
  final int longBreakDurationMinutes;

  final bool soundEnabled;
  final bool notificationsEnabled;
  final bool postureReminderEnabled;
  final int postureReminderIntervalMinutes;
  final String postureReminderType;
  final bool eyeBlinkReminderEnabled;
  final int eyeBlinkReminderIntervalMinutes;
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
  final String? customImagePath;

  final int resetTimerAfterMinutes;

  final bool workingHoursEnabled;
  final List<int> workingDays; // 1=Mon … 7=Sun
  final String workStartTime; // "HH:mm"
  final String workEndTime; // "HH:mm"

  final bool detectVideoCalls;
  final bool detectMeetings;
  final bool respectFocusMode;
  final bool globalHotkeyEnabled;
  final bool presentationPauseEnabled;

  final bool enableClockOut;
  final String clockOutTime; // "HH:mm"

  final List<ExerciseModel> exercises;

  final bool autoSuggestExercises;
  final bool useCursorCountdown;
  final bool enableAnimations;
  final String trayIconStyle; // 'default', 'companion', 'minimal', 'countdown'
  final bool companionEnabled;
  final bool pipModeEnabled;
  final String companionPetTheme;
  final String companionPetName;
  final double companionScale;
  final bool companionClickThrough;
  final bool companionFollowMouse;

  /// Whether the companion may move its own window around the screen.
  ///
  /// On by default: a pet that only ever sits where it was dropped reads as a
  /// widget. Off is for anyone who wants the window exactly where they put it
  /// and nowhere else.
  final bool companionWanderingEnabled;
  final String companionPreviewBackground;
  final List<String> unlockedPets;
  final String? companionAvatarUrlParams;

  /// The companion's full appearance as JSON-encoded `AvatarDefinition`.
  ///
  /// Held alongside [companionPetTheme] because a theme id only names a
  /// species: the breed, palette, and seed the customizer produced have
  /// nowhere else to live, and the overlay windows need all of it.
  final String? companionAvatarDefinition;

  /// Whether the floating companion stays on screen all the time.
  ///
  /// When false it appears when a break starts and hides when the break ends,
  /// so the desktop stays clear during focused work.
  final bool companionKeepOnScreen;

  final double companionWindowWidth;
  final double companionWindowHeight;
  final double? companionWindowX; // null = use platform default
  final double? companionWindowY; // null = use platform default

  final String pipBackgroundStyle;
  final double pipOpacity;
  final bool pipDraggableClickable;

  final String companionToyType;
  final String companionTreatType;

  /// Per-break-template accent color overrides, keyed by template id (e.g.
  /// 'warm_amber') with values as 0xAARRGGBB ints. A template not present
  /// here falls back to its built-in [BreakOverlayTheme] accent.
  final Map<String, int> templateAccentOverrides;

  final bool pettingEnabled;
  final bool ballThrowEnabled;
  final bool treatEnabled;
  final bool developerReactions;
  final bool quietModeAutoActivate;

  final bool hasCompletedOnboarding;
  final bool quietModeEnabled;
  final String
  quietModePreset; // 'none', 'presenting', 'meeting', 'deep_work', 'low_battery'
  final int lastSnoozeDurationMinutes;
  final String intensityLevel; // 'gentle', 'standard', 'strict', 'locked'

  final int dailyBreakGoalCount;
  final int maxContinuousSittingMinutes;
  final int weeklyConsistencyTargetDays;
  final bool calendarEnabled;

  final bool enableSessionResume;

  final bool appUsageTrackingEnabled;

  /// How many days of activity history to keep, or 0 for no limit.
  ///
  /// Matches the 30-day window app usage has always pruned to, so upgrading
  /// does not silently change how much history a user has.
  final int activityHistoryRetentionDays;

  /// Opt-in, local-only daily time budgets per [AppCategory] name (e.g.
  /// `{'browsing': 120}` for a 2h/day soft cap). A category absent from the
  /// map has no budget. Purely a UI nudge threshold — never enforced by
  /// blocking anything, consistent with the app's non-punitive tone.
  final Map<String, int> categoryDailyBudgetMinutes;

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
    this.companionAvatarUrlParams,
    this.companionAvatarDefinition,
    this.companionKeepOnScreen = true,
    this.companionWindowWidth = 280.0,
    this.companionWindowHeight = 320.0,
    this.companionWindowX,
    this.companionWindowY,
    this.pipBackgroundStyle = 'scene',
    this.pipOpacity = 1.0,
    this.pipDraggableClickable = true,
    this.companionToyType = 'tennis_ball',
    this.companionTreatType = 'sushi',
    this.templateAccentOverrides = const {},
    this.pettingEnabled = true,
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
    String? companionAvatarUrlParams,
    String? companionAvatarDefinition,
    bool? companionKeepOnScreen,
    double? companionWindowWidth,
    double? companionWindowHeight,
    double? companionWindowX,
    double? companionWindowY,
    bool? pettingEnabled,
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
    String? companionToyType,
    String? companionTreatType,
    Map<String, int>? templateAccentOverrides,
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
      customImagePath: customImagePath != null
          ? (customImagePath == "" ? null : customImagePath)
          : this.customImagePath,
      resetTimerAfterMinutes:
          resetTimerAfterMinutes ?? this.resetTimerAfterMinutes,
      workingHoursEnabled: workingHoursEnabled ?? this.workingHoursEnabled,
      workingDays: workingDays ?? this.workingDays,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      detectVideoCalls: detectVideoCalls ?? this.detectVideoCalls,
      detectMeetings: detectMeetings ?? this.detectMeetings,
      respectFocusMode: respectFocusMode ?? this.respectFocusMode,
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
      companionAvatarUrlParams:
          companionAvatarUrlParams ?? this.companionAvatarUrlParams,
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
      companionToyType: companionToyType ?? this.companionToyType,
      companionTreatType: companionTreatType ?? this.companionTreatType,
      templateAccentOverrides:
          templateAccentOverrides ?? this.templateAccentOverrides,
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
    'companionAvatarUrlParams': companionAvatarUrlParams,
    'companionAvatarDefinition': companionAvatarDefinition,
    'companionKeepOnScreen': companionKeepOnScreen,
    'pettingEnabled': pettingEnabled,
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
          map['companionPreviewBackground'] as String? ??
          '',
      unlockedPets:
          (map['unlockedPets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['grey_cat', 'orange_cat', 'black_cat'],
      companionAvatarUrlParams: map['companionAvatarUrlParams'] as String?,
      companionAvatarDefinition:
          map['companionAvatarDefinition'] as String?,
      companionKeepOnScreen:
          map['companionKeepOnScreen'] as bool? ?? true,
      pettingEnabled: map['pettingEnabled'] as bool? ?? true,
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
