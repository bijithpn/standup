import '../settings/settings_model.dart';

/// An explicit proposal, never an automatic edit. Applying uses current settings
/// so a dialog cannot overwrite unrelated changes made since it was opened.
class TimingSuggestion {
  final String title;
  final String explanation;
  final int? warningSeconds;
  final int? intervalMinutes;
  const TimingSuggestion({
    required this.title,
    required this.explanation,
    this.warningSeconds,
    this.intervalMinutes,
  });

  static TimingSuggestion? badTiming(SettingsModel settings) =>
      settings.preBreakWarningSeconds >= 30
      ? null
      : TimingSuggestion(
          title: 'More time to wrap up',
          explanation:
              'Increase your warning from ${settings.preBreakWarningSeconds} to 30 seconds. Your break frequency stays the same.',
          warningSeconds: 30,
        );
  static TimingSuggestion? tooFrequent(SettingsModel settings) {
    final next = (settings.shortBreakIntervalMinutes + 5).clamp(1, 180);
    if (next <= settings.shortBreakIntervalMinutes) return null;
    return TimingSuggestion(
      title: 'Try a little more focus time',
      explanation:
          'Change short breaks from every ${settings.shortBreakIntervalMinutes} to every $next minutes. Durations stay the same; the long-break interval will be at least $next minutes.',
      intervalMinutes: next,
    );
  }

  SettingsModel apply(SettingsModel current) => current.copyWith(
    preBreakWarningSeconds: warningSeconds ?? current.preBreakWarningSeconds,
    shortBreakIntervalMinutes:
        intervalMinutes ?? current.shortBreakIntervalMinutes,
    longBreakIntervalMinutes:
        intervalMinutes != null &&
            current.longBreakIntervalMinutes < intervalMinutes!
        ? intervalMinutes
        : current.longBreakIntervalMinutes,
    selectedProfileId: intervalMinutes == null
        ? current.selectedProfileId
        : 'custom',
  );
}
