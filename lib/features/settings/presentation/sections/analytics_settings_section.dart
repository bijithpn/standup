import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/presentation/widgets/break_statistics_section.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/analytics/presentation/widgets/wellness_score_card.dart';
import 'package:breakmate/features/analytics/presentation/widgets/productivity_trend_chart.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/presentation/widgets/app_usage_section.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/calendar_focus_insight.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/analytics/focus_trend.dart';
import 'package:breakmate/features/analytics/insights_overview.dart';
import 'package:breakmate/features/analytics/presentation/widgets/focus_score_card.dart';
import 'package:breakmate/features/analytics/presentation/widgets/insights_overview_card.dart';
import 'package:breakmate/features/analytics/presentation/widgets/focus_trend_chart.dart';
import 'package:breakmate/features/analytics/weekly_digest_service.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/core/services/error_toast_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class AnalyticsSettingsSection extends StatefulWidget {
  final StatsModel stats;
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;

  const AnalyticsSettingsSection({
    super.key,
    required this.stats,
    required this.settings,
    required this.onSave,
  });

  @override
  State<AnalyticsSettingsSection> createState() =>
      _AnalyticsSettingsSectionState();
}

class _AnalyticsSettingsSectionState extends State<AnalyticsSettingsSection> {
  int _selectedFilter = 0; // 0: Today, 1: Week, 2: Month
  int _selectedTab = 0; // 0: Overview, 1: Focus, 2: App Usage, 3: Breaks

  /// How many days back the calendar-vs-focus comparison (§7.4) looks —
  /// computed once per widget lifetime via [_loadCalendarComparison], not
  /// on every rebuild, since it's a native calendar round-trip.
  static const int _calendarComparisonLookbackDays = 14;
  Future<CalendarFocusComparison?>? _calendarComparisonFuture;

  StatsModel get _stats => widget.stats;

  @override
  void initState() {
    super.initState();
    _calendarComparisonFuture = _loadCalendarComparison();
  }

  UsagePeriod get _usagePeriod {
    switch (_selectedFilter) {
      case 1:
        return UsagePeriod.week;
      case 2:
        return UsagePeriod.month;
      default:
        return UsagePeriod.today;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildControlsRow(),
        const SizedBox(height: 24),
        switch (_selectedTab) {
          0 => _buildOverviewTab(),
          1 => _buildFocusTab(),
          2 => _buildAppUsageTab(),
          _ => BreakStatisticsSection(
            stats: _stats,
            selectedFilter: _selectedFilter,
          ),
        },
        const SizedBox(height: 48),
      ],
    );
  }

  /// The tab selector (what to look at) and the period filter (what range),
  /// as two independent controls — every tab still respects the selected
  /// period, so this stays visible everywhere rather than being nested per
  /// tab.
  Widget _buildControlsRow() {
    final tabs = segmentedControl(
      ['Overview', 'Focus', 'App Usage', 'Breaks'],
      _selectedTab,
      (i) => setState(() => _selectedTab = i),
    );
    final period = segmentedControl(
      ['Today', 'This Week', 'Month'],
      _selectedFilter,
      (i) => setState(() => _selectedFilter = i),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [tabs, const SizedBox(height: 12), period],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [tabs, period],
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    final viewMetrics = _calculateViewMetrics();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Overview',
          subtitle: 'Your productivity and wellness balance for $_periodLabel.',
        ),
        const SizedBox(height: 12),
        WellnessScoreCard(
          productivityScore: viewMetrics.productivityScore,
          wellnessScore: viewMetrics.wellnessScore,
        ),
        const SizedBox(height: 20),
        _buildInsightsCard(),
        const SizedBox(height: 28),
        sectionHeader('Activity Trend'),
        const SizedBox(height: 12),
        _buildTrendSection(),
        const SizedBox(height: 28),
        sectionHeader('At a Glance'),
        const SizedBox(height: 12),
        _buildDetailGrid(viewMetrics),
      ],
    );
  }

  /// Deliberately period-independent (always today's budgets + this week's
  /// break/focus history), unlike the rest of the Overview tab — an insight
  /// card that changes meaning under "This Month" would be confusing. Reads
  /// the same data the Focus and App Usage tabs already compute
  /// individually; see [buildOverviewInsights].
  Widget _buildInsightsCard() {
    return FutureBuilder<CalendarFocusComparison?>(
      future: _calendarComparisonFuture,
      builder: (context, calendarSnapshot) {
        return AnimatedBuilder(
          animation: sl<FocusStreakService>(),
          builder: (context, _) {
            return Consumer3<AppUsageService, FocusSessionService, BreakHistoryService>(
              builder: (context, usageService, focusService, breakHistory, _) {
                final correlation = BreakFocusCorrelation.compute(
                  events: breakHistory.events,
                  allSessions: focusService.sessionsForPeriod(
                    UsagePeriod.month,
                  ),
                );
                final week = _thisWeekBreakTotals();

                return InsightsOverviewCard(
                  insights: buildOverviewInsights(
                    todayCategoryTotals: usageService.categoryTotals(
                      UsagePeriod.today,
                    ),
                    budgetMinutes: widget.settings.categoryDailyBudgetMinutes,
                    correlation: correlation,
                    focusStreakDays: sl<FocusStreakService>()
                        .currentStreakDays(),
                    breaksCompletedThisWeek: week.completed,
                    breaksSkippedThisWeek: week.skipped,
                    currentLongBreakIntervalMinutes:
                        widget.settings.longBreakIntervalMinutes,
                    breakEvents: breakHistory.events,
                    focusSessions: focusService.sessionsForPeriod(
                      UsagePeriod.month,
                    ),
                    calendarComparison: calendarSnapshot.data,
                  ),
                  onApply: (action) =>
                      widget.onSave(action.apply(widget.settings)),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Fetches the last [_calendarComparisonLookbackDays] of calendar events
  /// and pairs each day's meeting count against its focus score — see
  /// [CalendarFocusComparison]. `null` (no comparison shown) whenever
  /// calendar access isn't enabled or the native call fails; never throws.
  Future<CalendarFocusComparison?> _loadCalendarComparison() async {
    if (!widget.settings.calendarEnabled) return null;

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: _calendarComparisonLookbackDays));

    List<CalendarEvent> events;
    try {
      events = await sl<CalendarService>().getEvents(start, now);
    } catch (_) {
      return null;
    }

    final meetingCountByDate = <String, int>{};
    for (final event in events) {
      if (event.isAllDay) continue;
      final key = _dateKeyFor(event.start);
      meetingCountByDate[key] = (meetingCountByDate[key] ?? 0) + 1;
    }

    final usageService = sl<AppUsageService>();
    final focusService = sl<FocusSessionService>();
    final focusScoreByDate = <String, double>{};
    for (var i = 0; i < _calendarComparisonLookbackDays; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKeyFor(date);
      final totalActiveSeconds = usageService
          .categoryTotals(UsagePeriod.today, now: date)
          .values
          .fold<int>(0, (sum, s) => sum + s);
      if (totalActiveSeconds <= 0) continue;
      focusScoreByDate[key] = focusService.focusScore(
        key,
        totalActiveSeconds: totalActiveSeconds,
      );
    }

    return CalendarFocusComparison.compute(
      meetingCountByDate: meetingCountByDate,
      focusScoreByDate: focusScoreByDate,
    );
  }

  String _dateKeyFor(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  ({int completed, int skipped}) _thisWeekBreakTotals() {
    final rangeData = _stats.weeklyData.length > 7
        ? _stats.weeklyData.sublist(_stats.weeklyData.length - 7)
        : _stats.weeklyData;
    return (
      completed: rangeData.fold(0, (sum, d) => sum + d.breaksCompleted),
      skipped: rangeData.fold(0, (sum, d) => sum + d.breaksSkipped),
    );
  }

  Widget _buildFocusTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Focus Score',
          subtitle:
              'Share of $_periodLabel spent in an uninterrupted deep-work session.',
        ),
        const SizedBox(height: 12),
        Consumer3<AppUsageService, FocusSessionService, BreakHistoryService>(
          builder: (context, usageService, focusService, breakHistory, _) {
            final period = _usagePeriod;
            final totalActiveSeconds = usageService
                .categoryTotals(period)
                .values
                .fold<int>(0, (sum, s) => sum + s);
            final sessions = focusService.sessionsForPeriod(period);
            final focusSeconds = sessions.fold<int>(
              0,
              (sum, s) => sum + s.durationSeconds,
            );
            final focusScore = totalActiveSeconds > 0
                ? (focusSeconds / totalActiveSeconds).clamp(0.0, 1.0)
                : 0.0;

            final correlation = BreakFocusCorrelation.compute(
              events: breakHistory.events,
              allSessions: focusService.sessionsForPeriod(UsagePeriod.month),
            );

            return FocusScoreCard(
              enabled: widget.settings.appUsageTrackingEnabled,
              focusScore: focusScore,
              sessions: sessions,
              correlation: correlation,
            );
          },
        ),
        if (widget.settings.appUsageTrackingEnabled) ...[
          const SizedBox(height: 28),
          sectionHeader(
            'Focus Trend',
            subtitle: 'Daily focus score over the last 7 days.',
          ),
          const SizedBox(height: 12),
          _buildFocusTrendSection(),
          const SizedBox(height: 20),
          _buildFocusStreakCard(),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: MinimalButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              onPressed: _exportWeeklyDigest,
              child: Text(
                'Export This Week',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppUsageTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'App Usage',
          subtitle: 'Where your screen time is going, like Digital Wellbeing.',
        ),
        const SizedBox(height: 12),
        Consumer<AppUsageService>(
          builder: (context, usageService, _) {
            final period = _usagePeriod;
            return AppUsageSection(
              enabled: widget.settings.appUsageTrackingEnabled,
              topApps: usageService.topApps(period),
              categoryTotals: usageService.categoryTotals(period),
              iconCache: sl(),
              onEnable: () => widget.onSave(
                widget.settings.copyWith(appUsageTrackingEnabled: true),
              ),
              // Daily budgets only mean something against today's totals.
              budgetMinutes: period == UsagePeriod.today
                  ? widget.settings.categoryDailyBudgetMinutes
                  : const {},
            );
          },
        ),
      ],
    );
  }

  Widget _buildFocusTrendSection() {
    return Consumer2<AppUsageService, FocusSessionService>(
      builder: (context, usageService, focusService, _) {
        final points = computeFocusTrend(
          focusSessionService: focusService,
          usageService: usageService,
        );
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(),
          child: SizedBox(height: 160, child: FocusTrendChart(points: points)),
        );
      },
    );
  }

  /// Mirrors the companion streak card's exact layout
  /// (`companion_settings_section.dart`'s `_buildStreakCard`) — a second,
  /// non-competing progression axis alongside break-taking consistency.
  Widget _buildFocusStreakCard() {
    return AnimatedBuilder(
      animation: sl<FocusStreakService>(),
      builder: (context, _) {
        final streakService = sl<FocusStreakService>();
        final current = streakService.currentStreakDays();
        final highest = streakService.highestMilestone;
        final next = streakService.nextMilestone;
        final daysToNext = next != null ? next.days - current : null;

        return buildCard([
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.bolt_fill,
                  size: 18,
                  color: current > 0 ? AppTheme.accent : AppTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current > 0
                            ? '$current-day focus streak'
                                '${highest != null ? ' · ${highest.label}' : ''}'
                            : 'No focus streak yet',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (next != null && daysToNext != null && daysToNext > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$daysToNext day${daysToNext == 1 ? '' : 's'} to '
                          '"${next.label}"',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]);
      },
    );
  }

  /// Saves this week's [WeeklyDigest] as a local Markdown file — fully
  /// local, no cloud call, reusing the same composition the scheduled
  /// notification uses.
  Future<void> _exportWeeklyDigest() async {
    final digest = sl<WeeklyDigestService>().buildDigest();
    final markdown = digest.toMarkdown();

    final now = DateTime.now();
    final fileName =
        'breakmate-week-in-review-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.md';

    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export This Week',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['md'],
      );
      if (path == null) return; // user cancelled

      await File(path).writeAsString(markdown);
      ErrorToastService.showInfo('Saved to $path');
    } catch (e) {
      ErrorToastService.showError('Could not save the export: $e');
    }
  }

  String get _periodLabel {
    switch (_selectedFilter) {
      case 1:
        return 'this week';
      case 2:
        return 'this month';
      default:
        return 'today';
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            CupertinoIcons.chart_bar_alt_fill,
            size: 18,
            color: AppTheme.accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.analytics,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.analyticsSubtitle,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendSection() {
    final isMonth = _selectedFilter == 2;
    final periodLabel = isMonth
        ? 'This Month'
        : _selectedFilter == 1
        ? 'This Week'
        : 'Today';
    final chartPeriod = isMonth
        ? ChartPeriod.month
        : _selectedFilter == 1
        ? ChartPeriod.week
        : ChartPeriod.today;
    final chartTitle = _selectedFilter == 0
        ? "Today's Breakdown"
        : _selectedFilter == 1
        ? 'Weekly Completion'
        : 'Monthly Overview';
    final chartSubtitle = _selectedFilter == 0
        ? 'Completed vs skipped breaks today.'
        : _selectedFilter == 1
        ? 'Break completions for each day this week.'
        : 'Total breaks completed per week this month.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chartTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chartSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  periodLabel,
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: ProductivityTrendChart(
              weeklyData: _stats.weeklyData,
              period: chartPeriod,
            ),
          ),
        ],
      ),
    );
  }

  _ViewMetrics _calculateViewMetrics() {
    int breaksCompleted;
    int breaksSkipped;
    int usageMinutes;
    int wellnessActions;
    int streak;
    int successRate;

    if (_selectedFilter == 0) {
      final today = _stats.weeklyData.lastWhere(
        (d) => d.date == _todayString(),
        orElse: () => DailyStats(
          date: _todayString(),
          breaksCompleted: 0,
          breaksSkipped: 0,
          usageMinutes: 0,
          wellnessActions: 0,
        ),
      );
      breaksCompleted = today.breaksCompleted;
      breaksSkipped = today.breaksSkipped;
      usageMinutes = today.usageMinutes;
      wellnessActions = today.wellnessActions;
      streak = _stats.currentStreak;
      final total = today.breaksCompleted + today.breaksSkipped;
      successRate = total > 0 ? (today.breaksCompleted * 100 ~/ total) : 0;
    } else {
      final List<DailyStats> rangeData;
      if (_selectedFilter == 2) {
        final now = DateTime.now();
        rangeData = _stats.weeklyData.where((d) {
          final parts = d.date.split('-');
          if (parts.length < 2) return false;
          return int.tryParse(parts[0]) == now.year &&
              int.tryParse(parts[1]) == now.month;
        }).toList();
      } else {
        rangeData = _stats.weeklyData.length > 7
            ? _stats.weeklyData.sublist(_stats.weeklyData.length - 7)
            : _stats.weeklyData;
      }

      breaksCompleted = rangeData.fold(0, (sum, d) => sum + d.breaksCompleted);
      breaksSkipped = rangeData.fold(0, (sum, d) => sum + d.breaksSkipped);
      usageMinutes = rangeData.fold(0, (sum, d) => sum + d.usageMinutes);
      wellnessActions = rangeData.fold(0, (sum, d) => sum + d.wellnessActions);
      streak = _stats.longestStreak;

      final total = breaksCompleted + breaksSkipped;
      successRate = total > 0 ? (breaksCompleted * 100 ~/ total) : 0;
    }

    final completionRate = successRate / 100.0;

    int productivityScore = (completionRate * 60).round();
    if (_selectedFilter == 0) {
      const dailyTarget = 6;
      final targetCompletion = (breaksCompleted / dailyTarget).clamp(0.0, 1.0);
      productivityScore += (targetCompletion * 40).round();
    } else {
      productivityScore += (streak.clamp(0, 7) / 7 * 40).round();
    }
    productivityScore = productivityScore.clamp(5, 100);

    int wellnessScore = (completionRate * 40).round();
    final targetActions = _selectedFilter == 0 ? 5 : 30;
    final actionCompletion = (wellnessActions / targetActions).clamp(0.0, 1.0);
    wellnessScore += (actionCompletion * 60).round();
    wellnessScore = wellnessScore.clamp(5, 100);

    return _ViewMetrics(
      breaksCompleted: breaksCompleted,
      usageMinutes: usageMinutes,
      streak: streak,
      successRate: successRate,
      productivityScore: productivityScore,
      wellnessScore: wellnessScore,
    );
  }

  Widget _buildDetailGrid(_ViewMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 600 ? 1.4 : 1.3,
          children: [
            _buildStatCard(
              AppStrings.completed,
              '${metrics.breaksCompleted}',
              AppStrings.statsSessions,
              CupertinoIcons.checkmark_seal,
              AppTheme.success,
            ),
            _buildStatCard(
              'Active Time',
              '${metrics.usageMinutes}',
              'MIN',
              CupertinoIcons.stopwatch,
              AppTheme.accent,
            ),
            _buildStatCard(
              _selectedFilter == 0 ? 'Current Streak' : 'Longest Streak',
              '${metrics.streak}',
              'DAYS',
              CupertinoIcons.flame,
              AppTheme.warning,
            ),
            _buildStatCard(
              'Success Rate',
              '${metrics.successRate}',
              '%',
              CupertinoIcons.graph_circle,
              AppTheme.info,
            ),
          ],
        );
      },
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Widget _buildStatCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewMetrics {
  final int breaksCompleted;
  final int usageMinutes;
  final int streak;
  final int successRate;
  final int productivityScore;
  final int wellnessScore;

  _ViewMetrics({
    required this.breaksCompleted,
    required this.usageMinutes,
    required this.streak,
    required this.successRate,
    required this.productivityScore,
    required this.wellnessScore,
  });
}
