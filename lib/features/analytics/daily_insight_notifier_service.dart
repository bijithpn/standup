import 'dart:async';
import 'package:clock/clock.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/analytics/insights_overview.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Delivers the single highest-priority [OverviewInsight] once per day via
/// a local notification, so the most useful finding reaches the user
/// without a Statistics-screen visit — workflow-analysis plan doc §7.5.
///
/// Originally scoped to route through the Desktop Companion's reaction
/// channel (`CompanionInteractionEvent`), but that channel only drives an
/// animation state — it carries no text payload the companion UI can
/// display, so there's no way to actually show a finding's sentence
/// through it without new companion UI (a speech bubble) that doesn't
/// exist yet. This uses the same local-notification mechanism
/// [FocusInsightService] already established instead, generalized from
/// "the correlation insight" to "whatever ranks first today" across every
/// finding type [buildOverviewInsights] knows about. A true
/// companion-delivered version remains future work, gated on that UI
/// capability existing.
///
/// Deliberately excludes the calendar-focus comparison (§7.4) — that needs
/// a native calendar round-trip better suited to the Statistics screen's
/// one-shot `FutureBuilder` than a periodic background timer; this service
/// only reads data already held in memory, same as [FocusInsightService].
class DailyInsightNotifierService {
  static const _checkInterval = Duration(minutes: 15);

  final StorageService _storage;
  final AppUsageService _usageService;
  final FocusSessionService _focusSessionService;
  final BreakHistoryService _breakHistoryService;
  final FocusStreakService _streakService;
  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;

  Timer? _checkTimer;

  DailyInsightNotifierService({
    required StorageService storage,
    required AppUsageService usageService,
    required FocusSessionService focusSessionService,
    required BreakHistoryService breakHistoryService,
    required FocusStreakService streakService,
    required SettingsRepository settingsRepository,
    required NotificationService notificationService,
  }) : _storage = storage,
       _usageService = usageService,
       _focusSessionService = focusSessionService,
       _breakHistoryService = breakHistoryService,
       _streakService = streakService,
       _settingsRepository = settingsRepository,
       _notificationService = notificationService;

  void start() {
    _checkTimer ??= Timer.periodic(_checkInterval, (_) => checkAndMaybeShow());
    checkAndMaybeShow();
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Shows the day's top insight once, if one exists and none has been
  /// shown today yet. Public (not test-only) since [start] also calls it
  /// directly on launch.
  void checkAndMaybeShow({DateTime? now}) {
    final today = now ?? clock.now();
    final todayKey = _dateKey(today);
    final lastShown = _storage.getString(
      AppConstants.keyLastDailyInsightDateKey,
    );
    if (lastShown == todayKey) return;

    final insight = _topInsight(today);
    if (insight == null) return;

    _notificationService.showDailyInsight(insight.text);
    _storage.setString(AppConstants.keyLastDailyInsightDateKey, todayKey);
  }

  OverviewInsight? _topInsight(DateTime today) {
    final settings = _settingsRepository.currentSettings;

    final weeklyBreaks = _breakHistoryService.eventsBetween(
      today.subtract(const Duration(days: 7)),
      today,
    );
    final completed = weeklyBreaks.where((e) => e.completed).length;
    final skipped = weeklyBreaks.length - completed;

    final correlation = BreakFocusCorrelation.compute(
      events: _breakHistoryService.events,
      allSessions: _focusSessionService.sessionsForPeriod(
        UsagePeriod.month,
        now: today,
      ),
    );

    final insights = buildOverviewInsights(
      todayCategoryTotals: _usageService.categoryTotals(
        UsagePeriod.today,
        now: today,
      ),
      budgetMinutes: settings.categoryDailyBudgetMinutes,
      correlation: correlation,
      focusStreakDays: _streakService.currentStreakDays(now: today),
      breaksCompletedThisWeek: completed,
      breaksSkippedThisWeek: skipped,
      breakEvents: _breakHistoryService.events,
      focusSessions: _focusSessionService.sessionsForPeriod(
        UsagePeriod.month,
        now: today,
      ),
      limit: 1,
    );
    return insights.isEmpty ? null : insights.first;
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
