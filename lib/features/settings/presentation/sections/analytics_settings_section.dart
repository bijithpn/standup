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
  int _selectedFilter = 0; // 0: Today, 1: Week

  StatsModel get _stats => widget.stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        WellnessScoreCard(
          productivityScore: _stats.productivityScore,
          wellnessScore: _stats.wellnessScore,
        ),
        const SizedBox(height: 24),
        _buildTrendSection(),
        const SizedBox(height: 24),
        _buildDetailGrid(),
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
              Text(
                AppStrings.analytics,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.analyticsSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        segmentedControl(
          ['Today', 'This Week'],
          _selectedFilter,
          (i) => setState(() => _selectedFilter = i),
        ),
      ],
    );
  }

  Widget _buildTrendSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                  const Text(
                    AppStrings.completionTrend,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.completionTrendSubtitle,
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
                  'Last 7 Days',
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
            child: ProductivityTrendChart(weeklyData: _stats.weeklyData),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailGrid() {
    // Determine which stats to show based on filter
    int breaksCompleted;
    int usageMinutes;
    int streak;
    int successRate;

    if (_selectedFilter == 0) {
      // TODAY
      final today = _stats.weeklyData.lastWhere(
        (d) => d.date == _todayString(),
        orElse: () => DailyStats(
          date: _todayString(),
          breaksCompleted: 0,
          breaksSkipped: 0,
          usageMinutes: 0,
        ),
      );
      breaksCompleted = today.breaksCompleted;
      usageMinutes = today.usageMinutes;
      streak = _stats.currentStreak;
      final total = today.breaksCompleted + today.breaksSkipped;
      successRate = total > 0 ? (today.breaksCompleted * 100 ~/ total) : 0;
    } else {
      // THIS WEEK
      breaksCompleted = _stats.weeklyData.fold(
        0,
        (sum, d) => sum + d.breaksCompleted,
      );
      usageMinutes = _stats.weeklyData.fold(
        0,
        (sum, d) => sum + d.usageMinutes,
      );
      streak = _stats.longestStreak;
      successRate = (_stats.completionRate * 100).toInt();
    }

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
              '$breaksCompleted',
              AppStrings.statsSessions,
              CupertinoIcons.checkmark_seal,
              AppTheme.success,
            ),
            _buildStatCard(
              'Active Time',
              '$usageMinutes',
              'MIN',
              CupertinoIcons.stopwatch,
              AppTheme.accent,
            ),
            _buildStatCard(
              _selectedFilter == 0 ? 'Current Streak' : 'Longest Streak',
              '$streak',
              'DAYS',
              CupertinoIcons.flame,
              AppTheme.warning,
            ),
            _buildStatCard(
              'Success Rate',
              '$successRate%',
              '%',
              CupertinoIcons.graph_circle,
              AppTheme.info,
            ),
          ],
        );
      }
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
