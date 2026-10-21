import 'package:flutter/foundation.dart';
import 'package:breakmate/features/settings/settings_model.dart';

/// Read-only, per-feature groupings over [SettingsModel]'s flat field list.
///
/// `SettingsModel` remains the single persisted source of truth — these
/// slices change nothing about storage, `copyWith`, or the ~50 existing
/// `settings.xxx` call sites across the app, which all keep working
/// unchanged. What they add is a scoped, readable view for *new* code that
/// only cares about one feature area (e.g. the companion settings screen),
/// without needing to know which of SettingsModel's other ~40 fields belong
/// to break timing, appearance, smart detection, etc.
///
/// Each slice has value equality (`==`/`hashCode`), so a
/// `Selector<SettingsRepository, CompanionSettingsSlice>` correctly dedupes
/// rebuilds when unrelated fields change elsewhere in the model — without
/// that, a fresh `.companion` instance on every access would compare
/// unequal every time and silently defeat the whole point of scoping.
///
/// The deeper "rebuild scoping" and "persistence-key separation" concerns
/// from the original audit were investigated directly rather than assumed:
/// across the whole app there are exactly two widgets that reactively
/// listen to `SettingsRepository` at all (found via a `grep` for
/// `Consumer` and `watch` calls on it), and both
/// are cheap (one is gated by a `const` subtree that Flutter already skips
/// rebuilding; the other is a single settings-page section). Every other
/// one of `settings_model.dart`'s 54 graph edges is a plain field read
/// inside a service method, not a widget subscription — so there is no
/// actual excess-rebuild problem in this codebase today for the `Selector`
/// pattern above to fix; it's provided so the concern *can't* recur as new
/// reactive settings UI gets added; not a hidden bug it needed to fix now.
/// Persistence-key separation was also reconsidered and rejected on
/// purpose: the whole settings blob is a few KB, so splitting storage keys
/// buys no measurable I/O benefit, while permanently committing to reading
/// a legacy single-blob format for already-installed users is a real,
/// disproportionate migration cost for that non-benefit. See
/// `PROJECT_ANALYSIS_AND_IMPROVEMENTS.md` §3.4 for the full writeup.
class CompanionSettingsSlice {
  final bool enabled;
  final bool pipModeEnabled;
  final String petTheme;
  final String petName;
  final double scale;
  final bool clickThrough;
  final bool followMouse;
  final bool wanderingEnabled;
  final String previewBackground;
  final List<String> unlockedPets;
  final double windowWidth;
  final double windowHeight;
  final double? windowX;
  final double? windowY;
  final String pipBackgroundStyle;
  final double pipOpacity;
  final bool pipDraggableClickable;
  final String toyType;
  final String treatType;
  final bool pettingEnabled;
  final bool ballThrowEnabled;
  final bool treatEnabled;
  final bool developerReactions;
  final bool quietModeAutoActivate;

  const CompanionSettingsSlice._({
    required this.enabled,
    required this.pipModeEnabled,
    required this.petTheme,
    required this.petName,
    required this.scale,
    required this.clickThrough,
    required this.followMouse,
    required this.wanderingEnabled,
    required this.previewBackground,
    required this.unlockedPets,
    required this.windowWidth,
    required this.windowHeight,
    required this.windowX,
    required this.windowY,
    required this.pipBackgroundStyle,
    required this.pipOpacity,
    required this.pipDraggableClickable,
    required this.toyType,
    required this.treatType,
    required this.pettingEnabled,
    required this.ballThrowEnabled,
    required this.treatEnabled,
    required this.developerReactions,
    required this.quietModeAutoActivate,
  });

  factory CompanionSettingsSlice.from(SettingsModel s) => CompanionSettingsSlice._(
    enabled: s.companionEnabled,
    pipModeEnabled: s.pipModeEnabled,
    petTheme: s.companionPetTheme,
    petName: s.companionPetName,
    scale: s.companionScale,
    clickThrough: s.companionClickThrough,
    followMouse: s.companionFollowMouse,
    wanderingEnabled: s.companionWanderingEnabled,
    previewBackground: s.companionPreviewBackground,
    unlockedPets: s.unlockedPets,
    windowWidth: s.companionWindowWidth,
    windowHeight: s.companionWindowHeight,
    windowX: s.companionWindowX,
    windowY: s.companionWindowY,
    pipBackgroundStyle: s.pipBackgroundStyle,
    pipOpacity: s.pipOpacity,
    pipDraggableClickable: s.pipDraggableClickable,
    toyType: s.companionToyType,
    treatType: s.companionTreatType,
    pettingEnabled: s.pettingEnabled,
    ballThrowEnabled: s.ballThrowEnabled,
    treatEnabled: s.treatEnabled,
    developerReactions: s.developerReactions,
    quietModeAutoActivate: s.quietModeAutoActivate,
  );

  // Value equality so a `Selector<SettingsRepository, CompanionSettingsSlice>`
  // actually dedupes rebuilds — without this, `.companion` returning a fresh
  // instance on every access would compare unequal (identity) every time
  // and defeat the point of scoping.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanionSettingsSlice &&
          enabled == other.enabled &&
          pipModeEnabled == other.pipModeEnabled &&
          petTheme == other.petTheme &&
          petName == other.petName &&
          scale == other.scale &&
          clickThrough == other.clickThrough &&
          followMouse == other.followMouse &&
          wanderingEnabled == other.wanderingEnabled &&
          previewBackground == other.previewBackground &&
          listEquals(unlockedPets, other.unlockedPets) &&
          windowWidth == other.windowWidth &&
          windowHeight == other.windowHeight &&
          windowX == other.windowX &&
          windowY == other.windowY &&
          pipBackgroundStyle == other.pipBackgroundStyle &&
          pipOpacity == other.pipOpacity &&
          pipDraggableClickable == other.pipDraggableClickable &&
          toyType == other.toyType &&
          treatType == other.treatType &&
          pettingEnabled == other.pettingEnabled &&
          ballThrowEnabled == other.ballThrowEnabled &&
          treatEnabled == other.treatEnabled &&
          developerReactions == other.developerReactions &&
          quietModeAutoActivate == other.quietModeAutoActivate;

  @override
  int get hashCode => Object.hash(
    enabled,
    pipModeEnabled,
    petTheme,
    petName,
    scale,
    clickThrough,
    followMouse,
    wanderingEnabled,
    previewBackground,
    Object.hashAll(unlockedPets),
    windowWidth,
    windowHeight,
    windowX,
    Object.hash(
      windowY,
      pipBackgroundStyle,
      pipOpacity,
      pipDraggableClickable,
      toyType,
      treatType,
      pettingEnabled,
      ballThrowEnabled,
      treatEnabled,
      developerReactions,
      quietModeAutoActivate,
    ),
  );
}

/// Break-timing fields: intervals, durations, and daily/weekly goals.
class BreakTimingSettingsSlice {
  final int shortBreakIntervalMinutes;
  final int shortBreakDurationSeconds;
  final int preBreakWarningSeconds;
  final int longBreakIntervalMinutes;
  final int longBreakDurationMinutes;
  final int resetTimerAfterMinutes;
  final int pauseTimerAfterMinutes;
  final int dailyBreakGoalCount;
  final int maxContinuousSittingMinutes;
  final int weeklyConsistencyTargetDays;

  const BreakTimingSettingsSlice._({
    required this.shortBreakIntervalMinutes,
    required this.shortBreakDurationSeconds,
    required this.preBreakWarningSeconds,
    required this.longBreakIntervalMinutes,
    required this.longBreakDurationMinutes,
    required this.resetTimerAfterMinutes,
    required this.pauseTimerAfterMinutes,
    required this.dailyBreakGoalCount,
    required this.maxContinuousSittingMinutes,
    required this.weeklyConsistencyTargetDays,
  });

  factory BreakTimingSettingsSlice.from(SettingsModel s) =>
      BreakTimingSettingsSlice._(
        shortBreakIntervalMinutes: s.shortBreakIntervalMinutes,
        shortBreakDurationSeconds: s.shortBreakDurationSeconds,
        preBreakWarningSeconds: s.preBreakWarningSeconds,
        longBreakIntervalMinutes: s.longBreakIntervalMinutes,
        longBreakDurationMinutes: s.longBreakDurationMinutes,
        resetTimerAfterMinutes: s.resetTimerAfterMinutes,
        pauseTimerAfterMinutes: s.pauseTimerAfterMinutes,
        dailyBreakGoalCount: s.dailyBreakGoalCount,
        maxContinuousSittingMinutes: s.maxContinuousSittingMinutes,
        weeklyConsistencyTargetDays: s.weeklyConsistencyTargetDays,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreakTimingSettingsSlice &&
          shortBreakIntervalMinutes == other.shortBreakIntervalMinutes &&
          shortBreakDurationSeconds == other.shortBreakDurationSeconds &&
          preBreakWarningSeconds == other.preBreakWarningSeconds &&
          longBreakIntervalMinutes == other.longBreakIntervalMinutes &&
          longBreakDurationMinutes == other.longBreakDurationMinutes &&
          resetTimerAfterMinutes == other.resetTimerAfterMinutes &&
          pauseTimerAfterMinutes == other.pauseTimerAfterMinutes &&
          dailyBreakGoalCount == other.dailyBreakGoalCount &&
          maxContinuousSittingMinutes == other.maxContinuousSittingMinutes &&
          weeklyConsistencyTargetDays == other.weeklyConsistencyTargetDays;

  @override
  int get hashCode => Object.hash(
    shortBreakIntervalMinutes,
    shortBreakDurationSeconds,
    preBreakWarningSeconds,
    longBreakIntervalMinutes,
    longBreakDurationMinutes,
    resetTimerAfterMinutes,
    pauseTimerAfterMinutes,
    dailyBreakGoalCount,
    maxContinuousSittingMinutes,
    weeklyConsistencyTargetDays,
  );
}

/// Visual/appearance fields for the break overlay and menu bar.
class AppearanceSettingsSlice {
  final String breakTheme;
  final String breakTemplate;
  final String clockFaceStyle;
  final int clockFaceTextColorHex;
  final bool clockFaceBlurEnabled;
  final String? customImagePath;
  final bool showOnAllDisplays;
  final bool enableAnimations;
  final bool useCursorCountdown;
  final String trayIconStyle;

  const AppearanceSettingsSlice._({
    required this.breakTheme,
    required this.breakTemplate,
    required this.clockFaceStyle,
    required this.clockFaceTextColorHex,
    required this.clockFaceBlurEnabled,
    required this.customImagePath,
    required this.showOnAllDisplays,
    required this.enableAnimations,
    required this.useCursorCountdown,
    required this.trayIconStyle,
  });

  factory AppearanceSettingsSlice.from(SettingsModel s) =>
      AppearanceSettingsSlice._(
        breakTheme: s.breakTheme,
        breakTemplate: s.breakTemplate,
        clockFaceStyle: s.clockFaceStyle,
        clockFaceTextColorHex: s.clockFaceTextColorHex,
        clockFaceBlurEnabled: s.clockFaceBlurEnabled,
        customImagePath: s.customImagePath,
        showOnAllDisplays: s.showOnAllDisplays,
        enableAnimations: s.enableAnimations,
        useCursorCountdown: s.useCursorCountdown,
        trayIconStyle: s.trayIconStyle,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppearanceSettingsSlice &&
          breakTheme == other.breakTheme &&
          breakTemplate == other.breakTemplate &&
          clockFaceStyle == other.clockFaceStyle &&
          clockFaceTextColorHex == other.clockFaceTextColorHex &&
          clockFaceBlurEnabled == other.clockFaceBlurEnabled &&
          customImagePath == other.customImagePath &&
          showOnAllDisplays == other.showOnAllDisplays &&
          enableAnimations == other.enableAnimations &&
          useCursorCountdown == other.useCursorCountdown &&
          trayIconStyle == other.trayIconStyle;

  @override
  int get hashCode => Object.hash(
    breakTheme,
    breakTemplate,
    clockFaceStyle,
    clockFaceTextColorHex,
    clockFaceBlurEnabled,
    customImagePath,
    showOnAllDisplays,
    enableAnimations,
    useCursorCountdown,
    trayIconStyle,
  );
}

/// Adds `.companion`, `.breakTiming`, and `.appearance` grouped views to
/// every [SettingsModel] instance without modifying the class itself.
extension SettingsModelSlices on SettingsModel {
  CompanionSettingsSlice get companion => CompanionSettingsSlice.from(this);
  BreakTimingSettingsSlice get breakTiming =>
      BreakTimingSettingsSlice.from(this);
  AppearanceSettingsSlice get appearance => AppearanceSettingsSlice.from(this);
}
