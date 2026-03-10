class AppConstants {
  AppConstants._();

  static const String appName = 'DeskRest';
  static const String appVersion = '1.0.0';

  // Short break defaults
  static const int defaultShortBreakIntervalMinutes = 20;
  static const int defaultShortBreakDurationSeconds = 20;

  // Long break defaults
  static const int defaultLongBreakIntervalMinutes = 60;
  static const int defaultLongBreakDurationMinutes = 5;

  // Activity detection
  static const int idleThresholdMinutes = 3;

  // Retry policy
  static const int maxRetries = 3;
  static const int initialRetryDelayMs = 500;

  // Notification channels
  static const String notificationChannelId = 'deskrest_breaks';
  static const String notificationChannelName = 'Break Reminders';

  // Storage keys
  static const String keyShortBreakInterval = 'short_break_interval';
  static const String keyShortBreakDuration = 'short_break_duration';
  static const String keyLongBreakInterval = 'long_break_interval';
  static const String keyLongBreakDuration = 'long_break_duration';
  static const String keySoundEnabled = 'sound_enabled';
  static const String keyAutoStart = 'auto_start';
  static const String keyStrictMode = 'strict_mode';
  static const String keyBreaksCompleted = 'breaks_completed';
  static const String keyBreaksSkipped = 'breaks_skipped';
  static const String keyDailyUsageMinutes = 'daily_usage_minutes';
  static const String keyLastActiveDate = 'last_active_date';

  // Health tips shown during breaks
  static const List<String> shortBreakTips = [
    'Look at something 20 feet away',
    'Blink your eyes slowly',
    'Close your eyes and relax',
    'Focus on a distant object',
    'Roll your eyes gently',
    'Cup your palms over your eyes',
  ];

  static const List<String> longBreakTips = [
    'Stretch your shoulders and neck',
    'Stand up and walk around',
    'Do some light stretching',
    'Hydrate — drink some water',
    'Take a few deep breaths',
    'Adjust your posture',
    'Stretch your wrists and fingers',
    'Look out the window for a moment',
  ];

  static const String trayIconPath = 'assets/icons/tray_icon.png';
}
