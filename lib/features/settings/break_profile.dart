/// Named preset of short/long break intervals and durations (see [presets]); picked in onboarding and settings.
class BreakProfile {
  final String id;
  final String name;
  final int shortIntervalMinutes;
  final int shortDurationSeconds;
  final int longIntervalMinutes;
  final int longDurationMinutes;

  const BreakProfile({
    required this.id,
    required this.name,
    required this.shortIntervalMinutes,
    required this.shortDurationSeconds,
    required this.longIntervalMinutes,
    required this.longDurationMinutes,
  });

  static const List<BreakProfile> presets = [
    BreakProfile(
      id: 'health',
      name: 'Health Mode',
      shortIntervalMinutes: 20,
      shortDurationSeconds: 20,
      longIntervalMinutes: 60,
      longDurationMinutes: 1,
    ),
    BreakProfile(
      id: 'developer',
      name: 'Developer Mode',
      shortIntervalMinutes: 30,
      shortDurationSeconds: 30,
      longIntervalMinutes: 90,
      longDurationMinutes: 2,
    ),
    BreakProfile(
      id: 'deep_work',
      name: 'Deep Work',
      shortIntervalMinutes: 50,
      shortDurationSeconds: 60,
      longIntervalMinutes: 120,
      longDurationMinutes: 3,
    ),
    BreakProfile(
      id: 'pomodoro',
      name: 'Pomodoro',
      shortIntervalMinutes: 25,
      shortDurationSeconds: 300,
      longIntervalMinutes: 100,
      longDurationMinutes: 15,
    ),
  ];

  /// Maps the onboarding answers (work type, daily hours) to a preset.
  static BreakProfile recommend({required String work, required int hours}) {
    final id = switch (work) {
      'coding' => 'developer',
      'meetings' => 'health',
      'study' => 'pomodoro',
      _ => hours >= 8 ? 'developer' : 'deep_work',
    };
    return presets.firstWhere((p) => p.id == id);
  }
}
