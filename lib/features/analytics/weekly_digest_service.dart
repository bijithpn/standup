import 'dart:async';
import 'package:clock/clock.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_insights.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/weekly_digest.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Shows the weekly digest notification once per week, on Sunday at or after 18:00.
class WeeklyDigestService {
  static const int _digestWeekday = DateTime.sunday;
  static const int _digestHour = 18;
  static const _checkInterval = Duration(minutes: 15);

  final StorageService _storage;
  final StatsService _statsService;
  final FocusSessionService _focusSessionService;
  final CompanionStreakService _streakService;
  final NotificationService _notificationService;
  final AppUsageService _usageService;
  final SettingsRepository _settingsRepository;

  Timer? _checkTimer;

  WeeklyDigestService({
    required StorageService storage,
    required StatsService statsService,
    required FocusSessionService focusSessionService,
    required CompanionStreakService streakService,
    required NotificationService notificationService,
    required AppUsageService usageService,
    required SettingsRepository settingsRepository,
  }) : _storage = storage,
       _statsService = statsService,
       _focusSessionService = focusSessionService,
       _streakService = streakService,
       _notificationService = notificationService,
       _usageService = usageService,
       _settingsRepository = settingsRepository;

  void start() {
    _checkTimer ??= Timer.periodic(_checkInterval, (_) => checkAndMaybeShow());
    checkAndMaybeShow();
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void checkAndMaybeShow({DateTime? now}) {
    final today = now ?? clock.now();
    if (today.weekday != _digestWeekday || today.hour < _digestHour) return;

    final weekKey = _weekKey(today);
    final lastShown = _storage.getString(
      AppConstants.keyLastWeeklyDigestWeekKey,
    );
    if (lastShown == weekKey) return;

    _notificationService.showWeeklyDigest(buildDigest(now: today));
    _storage.setString(AppConstants.keyLastWeeklyDigestWeekKey, weekKey);
  }

  /// Aggregates the last 7 days of break stats, focus sessions and budget overruns.
  WeeklyDigest buildDigest({DateTime? now}) {
    final today = now ?? clock.now();

    final weeklyData = _statsService.stats.weeklyData;
    final last7 = weeklyData.length > 7
        ? weeklyData.sublist(weeklyData.length - 7)
        : weeklyData;
    final completed = last7.fold<int>(0, (sum, d) => sum + d.breaksCompleted);
    final skipped = last7.fold<int>(0, (sum, d) => sum + d.breaksSkipped);
    final total = completed + skipped;
    final adherenceRate = total > 0 ? completed / total : 0.0;

    final categorySeconds = <AppCategory, int>{};
    var longestSessionSeconds = 0;
    for (var i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      for (final session in _focusSessionService.sessionsForDate(
        _dateKey(date),
      )) {
        categorySeconds[session.category] =
            (categorySeconds[session.category] ?? 0) + session.durationSeconds;
        if (session.durationSeconds > longestSessionSeconds) {
          longestSessionSeconds = session.durationSeconds;
        }
      }
    }

    AppCategory? topCategory;
    var topSeconds = 0;
    categorySeconds.forEach((category, seconds) {
      if (seconds > topSeconds) {
        topSeconds = seconds;
        topCategory = category;
      }
    });

    return WeeklyDigest(
      breakAdherenceRate: adherenceRate,
      breaksCompleted: completed,
      breaksSkipped: skipped,
      topFocusCategory: topCategory,
      longestDeepWorkSessionSeconds: longestSessionSeconds,
      companionMilestoneLabel: _streakService.highestMilestone?.label,
      daysOverBudgetByCategory: _daysOverBudget(today),
      trailingAverageAdherenceRate: _trailingAverageAdherence(
        weeklyData,
        today,
      ),
    );
  }

  // Average of days 7-34 back; null unless at least 7 of those days have data.
  double? _trailingAverageAdherence(
    List<DailyStats> weeklyData,
    DateTime today,
  ) {
    final trailingKeys = <String>{
      for (var i = 7; i < 35; i++) _dateKey(today.subtract(Duration(days: i))),
    };
    final trailingDays = weeklyData
        .where((d) => trailingKeys.contains(d.date))
        .toList();
    if (trailingDays.length < 7) return null;

    final completed = trailingDays.fold<int>(
      0,
      (sum, d) => sum + d.breaksCompleted,
    );
    final skipped = trailingDays.fold<int>(
      0,
      (sum, d) => sum + d.breaksSkipped,
    );
    final total = completed + skipped;
    return total > 0 ? completed / total : null;
  }

  Map<AppCategory, int> _daysOverBudget(DateTime today) {
    final budgetMinutes =
        _settingsRepository.currentSettings.categoryDailyBudgetMinutes;
    if (budgetMinutes.isEmpty) return const {};

    final counts = <AppCategory, int>{};
    for (var i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final totals = _usageService.categoryTotals(UsagePeriod.today, now: date);
      for (final category in categoriesOverBudget(
        todayCategorySeconds: totals,
        budgetMinutes: budgetMinutes,
      )) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    return counts;
  }

  String _weekKey(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceYearStart = date.difference(firstDayOfYear).inDays;
    final weekNumber = ((daysSinceYearStart + firstDayOfYear.weekday - 1) / 7)
        .floor();
    return '${date.year}-W$weekNumber';
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
