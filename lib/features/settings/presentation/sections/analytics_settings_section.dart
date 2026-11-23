import 'package:breakmate/features/analytics/presentation/widgets/weekly_actionable_insight_card.dart';
import 'package:breakmate/core/config/productivity_config.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator, InkWell;
import 'package:breakmate/features/analytics/presentation/widgets/break_statistics_section.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/analytics/presentation/widgets/productivity_trend_chart.dart';
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

/// Settings > Analytics page: period-filtered (today/week/month) break, focus and app-usage stats.
class AnalyticsSettingsSection extends StatefulWidget {
  final StatsModel stats;
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;
  final Future<void> Function(SettingsModel)? onApplySuggestion;
  final SettingsModel Function()? currentSettings;

  const AnalyticsSettingsSection({
    super.key,
    required this.stats,
    required this.settings,
    required this.onSave,
    this.onApplySuggestion,
    this.currentSettings,
  });

  @override
  State<AnalyticsSettingsSection> createState() =>
      _AnalyticsSettingsSectionState();
}

class _AnalyticsSettingsSectionState extends State<AnalyticsSettingsSection> {
  int _selectedFilter = 0;
  bool _focusOpen = false;

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
        WeeklyActionableInsightCard(
          days: _stats.weeklyData,
          settings: widget.settings,
          currentSettings: widget.currentSettings ?? () => widget.settings,
          onApply:
              widget.onApplySuggestion ?? (value) async => widget.onSave(value),
        ),
        const SizedBox(height: AppTheme.space32),
        segmentedControl(
          ['Today', 'This Week', 'Month'],
          _selectedFilter,
          (i) => setState(() => _selectedFilter = i),
          expand: false,
        ),
        const SizedBox(height: AppTheme.space24),
        _buildHero(m),
        const SizedBox(height: 48),

        _heading('Breaks per day', note: _trendNote),
        _buildTrendSection(),
        const SizedBox(height: 48),

        if (!ProductivityConfig.current.enabled) ...[
          _heading('Where your time goes'),
          _buildAppUsageTab(),
          const SizedBox(height: 48),
        ],

        _heading(
          'Focus',
          note: 'Uninterrupted deep-work sessions $_periodLabel',
        ),
        _buildFocusDisclosure(),
        const SizedBox(height: 48),

        BreakStatisticsSection(stats: _stats, selectedFilter: _selectedFilter),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _heading(String title, {String? note}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: AppTheme.space12),
            Flexible(
              child: Text(
                note,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHero(_ViewMetrics m) {
    final total = m.breaksCompleted + m.breaksSkipped;
    final ring = SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: total == 0 ? 0 : m.breaksCompleted / total,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: AppTheme.accent,
              backgroundColor: AppTheme.border,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total == 0 ? '–' : '${m.breaksCompleted} of $total',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  fontFeatures: AppTheme.tabular,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'breaks taken',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );

    final figures = Column(
      children: [
        _figure('Breaks skipped', '${m.breaksSkipped}', first: true),
        _figure('Active time', _formatMinutes(m.usageMinutes)),
        _figure(
          _selectedFilter == 0 ? 'Current streak' : 'Longest streak',
          m.streak == 1 ? '1 day' : '${m.streak} days',
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ring,
              const SizedBox(height: AppTheme.space24),
              figures,
            ],
          );
        }
        return Row(
          children: [
            ring,
            const SizedBox(width: 56),
            Expanded(child: figures),
          ],
        );
      },
    );
  }

  Widget _figure(String label, String value, {bool first = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              fontFeatures: AppTheme.tabular,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusDisclosure() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _focusOpen = !_focusOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Focus details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Icon(
                  _focusOpen
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_focusOpen) ...[
          const SizedBox(height: AppTheme.space16),
          _buildFocusTab(),
        ],
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

              budgetMinutes: period == UsagePeriod.today
                  ? widget.settings.categoryDailyBudgetMinutes
                  : const {},
            );
          },
        ),
      ],
    );
  }

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
                fontWeight: FontWeight.w500,
                fontFeatures: AppTheme.tabular,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
                          fontWeight: FontWeight.w500,
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

  String get _trendNote => _selectedFilter == 2
      ? 'Taken per week, this month'
      : 'Taken and skipped, this week';

  Widget _buildTrendSection() {
    return SizedBox(
      height: 220,
      child: ProductivityTrendChart(
        weeklyData: _stats.weeklyData,
        period: _selectedFilter == 2 ? ChartPeriod.month : ChartPeriod.week,
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

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// Per-period totals derived from [StatsModel] for the selected filter.
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
