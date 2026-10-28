import 'package:breakmate/core/config/productivity_config.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
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
import 'package:breakmate/features/analytics/habits_summary.dart';
import 'package:breakmate/features/analytics/insights_overview.dart';
import 'package:breakmate/features/analytics/meeting_break_insight.dart';
import 'package:breakmate/features/analytics/presentation/widgets/habits_summary_card.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';
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
  bool _focusExpanded = false;

  /// How many days back the calendar-vs-focus comparison (§7.4) looks —
  /// computed once per widget lifetime via [_loadCalendarComparison], not
  /// on every rebuild, since it's a native calendar round-trip.
  static const int _calendarComparisonLookbackDays = 14;
  Future<_CalendarInsightData>? _calendarComparisonFuture;

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
    final viewMetrics = _calculateViewMetrics();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildPeriodBar(),
        const SizedBox(height: 20),
        // Headline numbers first: what the period added up to.
        _buildHero(viewMetrics),
        const SizedBox(height: 32),

        _groupHeader(
          CupertinoIcons.sparkles,
          'Overview',
          'How your productivity and wellbeing balance out $_periodLabel.',
        ),
        _buildOverviewTab(),
        const SizedBox(height: 32),

        // Time spent per app lives on the Productivity screen; only when that
        // screen is switched off do we fall back to a short summary here.
        if (!ProductivityConfig.current.enabled) ...[
          _groupHeader(
            CupertinoIcons.time,
            'Where your time goes',
            'Your apps and what the activity shows.',
          ),
          _buildAppUsageTab(),
          const SizedBox(height: 32),
        ],

        // Focus is the longest block, so it starts folded.
        _groupHeader(
          CupertinoIcons.scope,
          'Focus',
          'Uninterrupted deep-work sessions $_periodLabel.',
          trailing: _foldButton(
            expanded: _focusExpanded,
            onTap: () => setState(() => _focusExpanded = !_focusExpanded),
          ),
        ),
        if (_focusExpanded) _buildFocusTab(),
        const SizedBox(height: 32),

        _groupHeader(
          CupertinoIcons.checkmark_seal,
          'Breaks',
          'Breaks you took, skipped and how they add up.',
        ),
        BreakStatisticsSection(stats: _stats, selectedFilter: _selectedFilter),
        const SizedBox(height: 48),
      ],
    );
  }

  /// The top of the page: one overall score as a ring, with the numbers it is
  /// made of next to it.
  Widget _buildHero(_ViewMetrics m) {
    final overall = ((m.productivityScore + m.wellnessScore) / 2).round();
    final verdict = overall >= 80
        ? 'Great balance'
        : overall >= 60
        ? 'Going well'
        : overall > 0
        ? 'Room to improve'
        : 'Just getting started';
    final ringColor = overall >= 80
        ? AppTheme.success
        : overall >= 60
        ? AppTheme.accent
        : AppTheme.warning;

    final ring = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CircularProgressIndicator(
                  value: (overall / 100).clamp(0.0, 1.0),
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  color: ringColor,
                  backgroundColor: AppTheme.border,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$overall',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'of 100',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          verdict,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ringColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Productivity ${m.productivityScore} · Wellness ${m.wellnessScore}',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentColor.withValues(alpha: 0.14),
            AppTheme.surfaceCard,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 640;
          final tiles = _buildDetailGrid(m);
          if (!wide) {
            return Column(children: [ring, const SizedBox(height: 20), tiles]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ring,
              const SizedBox(width: 28),
              Expanded(child: tiles),
            ],
          );
        },
      ),
    );
  }

  /// A clear heading for each part of the one-page view.
  Widget _groupHeader(
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _foldButton({required bool expanded, required VoidCallback onTap}) {
    return TapTarget(
      semanticLabel: expanded ? 'Collapse' : 'Expand',
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expanded ? 'Hide' : 'Show',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 12,
                color: AppTheme.accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One period selector for the whole page — every section follows it.
  Widget _buildPeriodBar() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $_periodLabel',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        segmentedControl(
          ['Today', 'This Week', 'Month'],
          _selectedFilter,
          (i) => setState(() => _selectedFilter = i),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final viewMetrics = _calculateViewMetrics();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WellnessScoreCard(
          productivityScore: viewMetrics.productivityScore,
          wellnessScore: viewMetrics.wellnessScore,
        ),
        const SizedBox(height: 20),
        _buildInsightsCard(),
        const SizedBox(height: 20),
        _buildHabitsSummaryCard(),
        const SizedBox(height: 28),
        sectionHeader('Activity Trend'),
        const SizedBox(height: 12),
        _buildTrendSection(),
      ],
    );
  }

  /// Deliberately period-independent (always today's budgets + this week's
  /// break/focus history), unlike the rest of the Overview tab — an insight
  /// card that changes meaning under "This Month" would be confusing. Reads
  /// the same data the Focus and App Usage tabs already compute
  /// individually; see [buildOverviewInsights].
  Widget _buildInsightsCard() {
    return FutureBuilder<_CalendarInsightData>(
      future: _calendarComparisonFuture,
      builder: (context, calendarSnapshot) {
        return AnimatedBuilder(
          animation: sl<FocusStreakService>(),
          builder: (context, _) {
            return Consumer3<
              AppUsageService,
              FocusSessionService,
              BreakHistoryService
            >(
              builder: (context, usageService, focusService, breakHistory, _) {
                final correlation = BreakFocusCorrelation.compute(
                  events: breakHistory.events,
                  allSessions: focusService.sessionsForPeriod(
                    UsagePeriod.month,
                  ),
                );
                final week = _thisWeekBreakTotals();
                final meetingStartTimes =
                    calendarSnapshot.data?.meetingStartTimes ?? const [];

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
                    calendarComparison: calendarSnapshot.data?.comparison,
                    meetingBreakCorrelation: meetingStartTimes.isEmpty
                        ? null
                        : MeetingBreakCorrelation.compute(
                            breakEvents: breakHistory.events,
                            meetingStartTimes: meetingStartTimes,
                          ),
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
  /// Break-taking consistency ([CompanionStreakService]) and focus-day
  /// consistency ([FocusStreakService]) live on two different settings
  /// screens today — this puts both numbers, plus whether they're in sync,
  /// in the one place a user already checks their overall stats. See
  /// [HabitsSummary].
  Widget _buildHabitsSummaryCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        sl<CompanionStreakService>(),
        sl<FocusStreakService>(),
      ]),
      builder: (context, _) {
        return HabitsSummaryCard(
          summary: HabitsSummary(
            breakStreakDays: sl<CompanionStreakService>().currentStreakDays,
            focusStreakDays: sl<FocusStreakService>().currentStreakDays(),
          ),
        );
      },
    );
  }

  /// [CalendarFocusComparison] — plus the raw meeting start times, reused by
  /// [MeetingBreakCorrelation] (§7.6) so there's only one calendar
  /// round-trip. Empty/`null` fields whenever calendar access isn't enabled
  /// or the native call fails; never throws.
  Future<_CalendarInsightData> _loadCalendarComparison() async {
    if (!widget.settings.calendarEnabled) return const _CalendarInsightData();

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
      return const _CalendarInsightData();
    }

    final meetingCountByDate = <String, int>{};
    final meetingStartTimes = <DateTime>[];
    for (final event in events) {
      if (event.isAllDay) continue;
      final key = _dateKeyFor(event.start);
      meetingCountByDate[key] = (meetingCountByDate[key] ?? 0) + 1;
      meetingStartTimes.add(event.start);
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

    return _CalendarInsightData(
      comparison: CalendarFocusComparison.compute(
        meetingCountByDate: meetingCountByDate,
        focusScoreByDate: focusScoreByDate,
      ),
      meetingStartTimes: meetingStartTimes,
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
            subtitle: 'Daily focus score over the last $_focusTrendDays days.',
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

  /// 30 days on "Month" (matching how [ProductivityTrendChart] reshapes
  /// itself per period), 7 otherwise — see the workflow-analysis plan doc
  /// §3.2/PROJECT_ANALYSIS_AND_IMPROVEMENTS.md §3.2.
  int get _focusTrendDays => _selectedFilter == 2 ? 30 : 7;

  Widget _buildFocusTrendSection() {
    return Consumer2<AppUsageService, FocusSessionService>(
      builder: (context, usageService, focusService, _) {
        final points = computeFocusTrend(
          focusSessionService: focusService,
          usageService: usageService,
          days: _focusTrendDays,
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
                      if (next != null &&
                          daysToNext != null &&
                          daysToNext > 0) ...[
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
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 12),
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
            height: 190,
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
        final crossAxisCount = 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 360 ? 2.1 : 1.6,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
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
                    if (unit.isNotEmpty) ...[
                      SizedBox(width: unit == '%' ? 1 : 4),
                      Flexible(
                        child: Text(
                          unit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of one calendar round-trip, shared by [CalendarFocusComparison]
/// and [MeetingBreakCorrelation] so there's only one native call per widget
/// lifetime.
class _CalendarInsightData {
  final CalendarFocusComparison? comparison;
  final List<DateTime> meetingStartTimes;

  const _CalendarInsightData({
    this.comparison,
    this.meetingStartTimes = const [],
  });
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
