import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/analytics/presentation/widgets/wellness_score_card.dart';
import 'package:breakmate/features/analytics/presentation/widgets/productivity_trend_chart.dart';
import 'package:breakmate/core/constants/app_strings.dart';

class AnalyticsSettingsSection extends StatefulWidget {
  final StatsModel stats;

  const AnalyticsSettingsSection({super.key, required this.stats});

  @override
  State<AnalyticsSettingsSection> createState() =>
      _AnalyticsSettingsSectionState();
}

class _AnalyticsSettingsSectionState extends State<AnalyticsSettingsSection> {
  int _selectedFilter = 0; // 0: Today, 1: Week, 2: Month

  StatsModel get _stats => widget.stats;

  @override
  Widget build(BuildContext context) {
    final viewMetrics = _calculateViewMetrics();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        WellnessScoreCard(
          productivityScore: viewMetrics.productivityScore,
          wellnessScore: viewMetrics.wellnessScore,
        ),
        const SizedBox(height: 24),
        _buildTrendSection(),
        const SizedBox(height: 24),
        _buildDetailGrid(viewMetrics),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.analytics,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.analyticsSubtitle,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chartSubtitle,
                    style: const TextStyle(
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
            style: const TextStyle(
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
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
