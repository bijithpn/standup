import 'settings_model.dart';

/// Applies a bundle without changing the user's break cadence or visual theme.
enum NotificationIntensity {
  gentle('Gentle', 'Silent, 30-second warning, primary display only.'),
  balanced('Balanced', 'Sound, 20-second warning, primary display only.'),
  firm(
    'Firm',
    'Sound, 10-second warning, all displays. Breaks remain skippable.',
  );

  const NotificationIntensity(this.label, this.description);
  final String label;
  final String description;

  SettingsModel apply(SettingsModel settings) => settings.copyWith(
    soundEnabled: this != gentle,
    notificationsEnabled: true,
    preBreakWarningSeconds: switch (this) {
      gentle => 30,
      balanced => 20,
      firm => 10,
    },
    showOnAllDisplays: this == firm,
    strictMode: false,
    intensityLevel: 'standard',
  );

  bool matches(SettingsModel settings) {
    final preset = apply(settings);
    return settings.soundEnabled == preset.soundEnabled &&
        settings.notificationsEnabled == preset.notificationsEnabled &&
        settings.preBreakWarningSeconds == preset.preBreakWarningSeconds &&
        settings.showOnAllDisplays == preset.showOnAllDisplays &&
        !settings.strictMode &&
        settings.intensityLevel == 'standard';
  }
}
