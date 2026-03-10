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
      longDurationMinutes: 5,
    ),
    BreakProfile(
      id: 'developer',
      name: 'Developer Mode',
      shortIntervalMinutes: 30,
      shortDurationSeconds: 30,
      longIntervalMinutes: 90,
      longDurationMinutes: 10,
    ),
    BreakProfile(
      id: 'deep_work',
      name: 'Deep Work',
      shortIntervalMinutes: 50,
      shortDurationSeconds: 60,
      longIntervalMinutes: 120,
      longDurationMinutes: 15,
    ),
    BreakProfile(
      id: 'pomodoro',
      name: 'Pomodoro',
      shortIntervalMinutes: 25,
      shortDurationSeconds: 300, // 5 min
      longIntervalMinutes: 100, // 4 sessions
      longDurationMinutes: 15,
    ),
  ];
}
