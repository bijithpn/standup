import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          WellnessScoreCard(
            productivityScore: _stats.productivityScore,
            wellnessScore: _stats.wellnessScore,
          ),
          const SizedBox(height: 32),
          _buildTrendSection(),
          const SizedBox(height: 32),
          _buildDetailGrid(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        sectionHeader(
          AppStrings.analytics,
          subtitle: AppStrings.analyticsSubtitle,
        ),
        _buildSegmentedFilter(
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
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.completionTrend,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.completionTrendSubtitle,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: ProductivityTrendChart(weeklyData: _stats.weeklyData),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          AppStrings.completed,
          '${_stats.breaksCompleted}',
          AppStrings.statsSessions,
          Icons.check_circle_outline_rounded,
          AppTheme.success,
        ),
        _buildStatStatCard(
          'Usage',
          '${_stats.dailyUsageMinutes}',
          AppStrings.statsMinutes,
          Icons.timer_outlined,
          AppTheme.accent,
        ),
        _buildStatStatCard(
          'Streak',
          '${_stats.currentStreak}',
          AppStrings.statsDays,
          Icons.local_fire_department_rounded,
          AppTheme.warning,
        ),
        _buildStatStatCard(
          'Rate',
          '${(_stats.completionRate * 100).toInt()}%',
          AppStrings.statsSuccess,
          Icons.analytics_outlined,
          AppTheme.info,
        ),
      ],
    );
  }

  Widget _buildStatStatCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return _buildStatCard(label, value, unit, icon, color);
  }

  Widget _buildStatCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedFilter(
    List<String> options,
    int selected,
    ValueChanged<int> onSelected,
  ) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: options.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          return GestureDetector(
            onTap: () => onSelected(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.gray800 : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
