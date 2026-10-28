import 'package:breakmate/core/config/productivity_config.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:breakmate/features/analytics/presentation/widgets/break_statistics_section.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/analytics/presentation/widgets/productivity_trend_chart.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/presentation/widgets/app_usage_section.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_trend.dart';
import 'package:breakmate/features/analytics/presentation/widgets/focus_score_card.dart';
import 'package:breakmate/features/analytics/presentation/widgets/focus_trend_chart.dart';

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

  StatsModel get _stats => widget.stats;

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
    final m = _calculateViewMetrics();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildPeriodBar(),
        const SizedBox(height: 20),
        _buildHero(m),
        const SizedBox(height: 32),

        _groupHeader(
          CupertinoIcons.chart_bar_alt_fill,
          'Activity trend',
          'Breaks taken and skipped $_periodLabel.',
        ),
        _buildTrendSection(),
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

        _groupHeader(
          CupertinoIcons.scope,
          'Focus',
          'Uninterrupted deep-work sessions $_periodLabel.',
        ),
        _buildFocusTab(),
        const SizedBox(height: 32),

        BreakStatisticsSection(stats: _stats, selectedFilter: _selectedFilter),
        const SizedBox(height: 48),
      ],
    );
  }

  /// The top of the page: how well breaks were kept as a ring, with the
  /// numbers behind it as colour-coded tiles.
  Widget _buildHero(_ViewMetrics m) {
    final total = m.breaksCompleted + m.breaksSkipped;
    final rate = m.successRate;
    final (verdict, ringColor) = total == 0
        ? ('No breaks yet', AppTheme.textMuted)
        : rate >= 80
        ? ('Excellent', AppTheme.success)
        : rate >= 60
        ? ('Good', AppTheme.accent)
        : rate >= 40
        ? ('Could be better', AppTheme.warning)
        : ('Skipping a lot', AppTheme.error);

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
                  value: total == 0 ? 0 : (rate / 100).clamp(0.0, 1.0),
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
                    total == 0 ? '–' : '$rate%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'breaks taken',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: ringColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            verdict,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ringColor,
            ),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiles = _buildDetailGrid(m);
          if (constraints.maxWidth <= 640) {
            return Column(children: [ring, const SizedBox(height: 20), tiles]);
          }
          return Row(
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

  Widget _buildFocusTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

            return FocusScoreCard(
              enabled: widget.settings.appUsageTrackingEnabled,
              focusScore: focusScore,
              sessions: sessions,
              focusApps: usageService
                  .topApps(period, limit: null)
                  .where((a) => isFocusCategory(a.category))
                  .toList(),
              footer: widget.settings.appUsageTrackingEnabled
                  ? _buildFocusTrendSection()
                  : null,
            );
          },
        ),
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
        final active = points.where((p) => p.focusScore > 0).toList();
        final avg = active.isEmpty
            ? 0
            : (active.fold<double>(0, (s, p) => s + p.focusScore) /
                      active.length *
                      100)
                  .round();
        final best = active.isEmpty
            ? 0
            : (active.map((p) => p.focusScore).reduce((a, b) => a > b ? a : b) *
                      100)
                  .round();

        Widget stat(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trend',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Daily focus, last $_focusTrendDays days',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                stat('Average', active.isEmpty ? '–' : '$avg%'),
                const SizedBox(width: 20),
                stat('Best day', active.isEmpty ? '–' : '$best%'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 150, child: FocusTrendChart(points: points)),
          ],
        );
      },
    );
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
    final int breaksCompleted;
    final int breaksSkipped;
    final int usageMinutes;
    final int streak;

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
      streak = _stats.currentStreak;
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
      streak = _stats.longestStreak;
    }

    final total = breaksCompleted + breaksSkipped;
    return _ViewMetrics(
      breaksCompleted: breaksCompleted,
      breaksSkipped: breaksSkipped,
      usageMinutes: usageMinutes,
      streak: streak,
      successRate: total > 0 ? (breaksCompleted * 100 ~/ total) : 0,
    );
  }

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Widget _buildDetailGrid(_ViewMetrics m) {
    final total = m.breaksCompleted + m.breaksSkipped;
    final skipShare = total > 0 ? (m.breaksSkipped * 100 / total).round() : 0;
    final streakLabel = _selectedFilter == 0
        ? 'Current streak'
        : 'Longest streak';
    final tiles = [
      _buildStatCard(
        'Breaks taken',
        '${m.breaksCompleted}',
        total == 0 ? 'none offered $_periodLabel' : 'of $total offered',
        CupertinoIcons.checkmark_seal,
        AppTheme.success,
      ),
      _buildStatCard(
        'Breaks skipped',
        '${m.breaksSkipped}',
        total == 0 ? 'nothing skipped' : '$skipShare% of offered',
        CupertinoIcons.arrow_uturn_left,
        m.breaksSkipped == 0 ? AppTheme.textMuted : AppTheme.warning,
      ),
      _buildStatCard(
        'Active time',
        _formatMinutes(m.usageMinutes),
        'at the computer $_periodLabel',
        CupertinoIcons.stopwatch,
        AppTheme.accent,
      ),
      _buildStatCard(
        streakLabel,
        '${m.streak}',
        m.streak == 1 ? 'day in a row' : 'days in a row',
        CupertinoIcons.flame,
        m.streak > 0 ? AppTheme.warning : AppTheme.textMuted,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 420 ? 2 : 1;
        const gap = 12.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
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
    String hint,
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewMetrics {
  final int breaksCompleted;
  final int breaksSkipped;
  final int usageMinutes;
  final int streak;
  final int successRate;

  _ViewMetrics({
    required this.breaksCompleted,
    required this.breaksSkipped,
    required this.usageMinutes,
    required this.streak,
    required this.successRate,
  });
}
