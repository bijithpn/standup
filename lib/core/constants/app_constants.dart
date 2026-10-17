class AppConstants {
  AppConstants._();

  static const String appName = 'BreakMate';
  static const String appVersion = '1.0.0';

  /// Wellness slideshow images — removed in avatar-main asset migration.
  /// Reserved for future content; currently unused.
  static const List<String> wellnessSlideshow = [];

  static const int defaultShortBreakIntervalMinutes = 20;
  static const int defaultShortBreakDurationSeconds = 20;
  static const int defaultPreBreakWarningSeconds = 60;

  static const int defaultLongBreakIntervalMinutes = 60;
  static const int defaultLongBreakDurationMinutes = 5;

  static const int idleThresholdMinutes = 3;

  /// How long a quick health-reminder overlay (posture/eye-rest nudge) stays
  /// on screen before auto-dismissing. Deliberately its own constant,
  /// separate from break-timer durations — a health reminder is a brief
  /// nudge, not a countdown, and must never share a clock with the real
  /// break overlay's `BreakTimerManager` countdown or with the pre-break
  /// warning's own dismiss delay.
  static const Duration healthReminderDismissDuration = Duration(seconds: 4);

  static const int maxRetries = 3;
  static const int initialRetryDelayMs = 500;

  static const String notificationChannelId = 'breakloop_breaks';
  static const String notificationChannelName = 'Break Reminders';

  static const int backupSchemaVersion = 1;

  static const String keyShortBreakInterval = 'short_break_interval';
  static const String keyShortBreakDuration = 'short_break_duration';
  static const String keyPreBreakWarningSeconds = 'pre_break_warning_seconds';
  static const String keyLongBreakInterval = 'long_break_interval';
  static const String keyLongBreakDuration = 'long_break_duration';
  static const String keySoundEnabled = 'sound_enabled';
  static const String keyAutoStart = 'auto_start';
  static const String keyStrictMode = 'strict_mode';
  static const String keyBreaksCompleted = 'breaks_completed';
  static const String keyBreaksSkipped = 'breaks_skipped';
  static const String keyDailyUsageMinutes = 'daily_usage_minutes';
  static const String keyLastActiveDate = 'last_active_date';
  static const String keyCurrentStreak = 'current_streak';
  static const String keyLongestStreak = 'longest_streak';
  static const String keyWeeklyStats = 'weekly_stats';
  static const String keyAppUsageData = 'app_usage_data';
  static const String keyFocusSessionData = 'focus_session_data';
  static const String keyBreakHistoryData = 'break_history_data';
  static const String keyLastWeeklyDigestWeekKey = 'last_weekly_digest_week_key';
  static const String keyFocusInsightShown = 'focus_insight_shown';
  static const String keyLastDailyInsightDateKey = 'last_daily_insight_date_key';
  static const String keyTotalWorkSessions = 'total_work_sessions';
  static const String keyPostponeCount = 'postpone_count';
  static const String keyActivityPatterns = 'activity_patterns';
  static const String keyCompanionPetTheme = 'companion_pet_theme';
  static const String keyCompanionAvatarUrlParams = 'companion_avatar_url_params';
  static const String legacyKeyCompanionCatTheme = 'companion_cat_theme';

  static const int breaksPerDayForStreak = 5;

  static const List<String> shortBreakTips = [
    'Look at something 20 feet away for 20 seconds',
    'Blink your eyes slowly 5 times',
    'Close your eyes and breathe deeply',
    'Focus on a distant object outside',
    'Drink a sip of water',
  ];

  static const List<String> longBreakTips = [
    'Stretch your shoulders and neck',
    'Stand up and walk for 1 minute',
    'Do a slow deep breathing exercise',
    'Adjust your sitting posture',
    'Roll your wrists and ankles',
  ];

  static const List<String> eyeExercises = [
    'Blink rapidly for 10 seconds',
    'Look top-left then bottom-right 5 times',
    'Focus on your thumb then the wall',
    'Gently massage your temples',
  ];

  static const List<String> stretchExercises = [
    'Interlace fingers and push palms forward',
    'Tilt head to shoulder for 10s each side',
    'Squeeze shoulder blades together',
    'Stand up and touch your toes',
  ];

  static const List<String> motivationalQuotes = [
    'Rest is not idleness, and to lie sometimes on the grass under trees is by no means a waste of time.',
    'A refreshed mind is a productive mind.',
    'Your health is your greatest wealth.',
    'Taking a break is a form of discipline.',
    'Sometimes the most productive thing you can do is relax.',
  ];

  /// Tray icon — points to raster PNG with alpha suitable for tray template extraction.
  static const String trayIconPath = 'assets/icons/app_icon_bg.png';
}

