import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/features/analytics/presentation/widgets/wellness_score_card.dart';
import 'package:breakmate/features/analytics/widgets/productivity_wellness_chart.dart';

class AnalyticsSettingsSection extends StatefulWidget {
  final StatsModel stats;

  const AnalyticsSettingsSection({super.key, required this.stats});

  @override
  State<AnalyticsSettingsSection> createState() =>
      _AnalyticsSettingsSectionState();
}

class _AnalyticsSettingsSectionState extends State<AnalyticsSettingsSection> {
  int _statsSubTab = 0;
  int _selectedStatsTab = 0;

  StatsModel get _stats => widget.stats;

  @override
  Widget build(BuildContext context) {
    return _buildStatistics();
  }

  Widget _buildStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Statistics',
          subtitle: 'Detailed insights into your rest and work balance.',
        ),

        // Tab-like segmented control for stats
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              _subTabButton(
                'Overview',
                0,
                currentTab: _statsSubTab,
                onTabChanged: (i) => setState(() => _statsSubTab = i),
              ),
              _subTabButton(
                'Wellness Dashboard',
                1,
                currentTab: _statsSubTab,
                onTabChanged: (i) => setState(() => _statsSubTab = i),
              ),
            ],
          ),
        ),

        if (_statsSubTab == 0) ...[
          // ΓöÇΓöÇ Break Activity heatmap ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cleanCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Break Activity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Satoshi',
                  ),
                ),
                const SizedBox(height: 16),
                _buildHeatmapMonthLabels(),
                const SizedBox(height: 6),
                _buildHeatmapGrid(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Less',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        const SizedBox(width: 4),
                        _heatSquare(AppTheme.cardBackgroundElevated),
                        const SizedBox(width: 3),
                        _heatSquare(
                          AppTheme.shortBreakColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 3),
                        _heatSquare(
                          AppTheme.shortBreakColor.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 3),
                        _heatSquare(AppTheme.shortBreakColor),
                        const SizedBox(width: 4),
                        const Text(
                          'More',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_calculatedBreaks breaks completed',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ΓöÇΓöÇ Break Statistics card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
          _buildBreakStatisticsCard(),
        ] else
          _buildWellnessDashboard(),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWellnessDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WellnessScoreCard(
          productivityScore: _stats.productivityScore,
          wellnessScore: _stats.wellnessScore,
        ),
        const SizedBox(height: 24),
        ProductivityWellnessChart(stats: _stats),
        const SizedBox(height: 24),
        buildCard([
          _statsMetricRow(
            CupertinoIcons.heart_circle,
            const Color(0xFF10B981),
            'Wellness Actions',
            'Stretches and eye rests recorded',
            '${_stats.totalWellnessActions}',
          ),
          divider(),
          _statsMetricRow(
            CupertinoIcons.graph_square,
            AppTheme.accentColor,
            'Productivity Focus',
            'Estimated active work minutes',
            '${_stats.dailyUsageMinutes}',
          ),
        ]),
      ],
    );
  }

  Widget _buildHeatmapMonthLabels() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: months
          .map(
            (m) => Text(
              m,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textMuted,
                fontFamily: 'Satoshi',
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildHeatmapGrid() {
    // 5 rows ├ù 52 columns
    final weeklyStats = _stats.weeklyData;
    // Pre-map for O(1) lookup performance (avoids O(N^2) total lookups in the grid)
    final statsMap = {for (var s in weeklyStats) s.date: s};

    final now = DateTime.now();
    return Column(
      children: List.generate(5, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: List.generate(52, (col) {
              final dayOffset = (51 - col) * 5 + (4 - row);
              final cellDate = now.subtract(Duration(days: dayOffset));
              final dateStr =
                  '${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}';

              final dayStats = statsMap[dateStr];
              final hasActivity =
                  dayStats != null && dayStats.breaksCompleted > 0;
              final intensity = dayStats != null
                  ? (dayStats.breaksCompleted / 8).clamp(0.2, 1.0)
                  : 0.0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: hasActivity
                          ? AppTheme.shortBreakColor.withValues(
                              alpha: intensity,
                            )
                          : AppTheme.cardBackgroundElevated.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildBreakStatisticsCard() {
    return Container(
      decoration: AppTheme.cleanCardDecoration.copyWith(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Performance Metrics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Satoshi',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildSegmentedFilter(
                  ['Today', 'Week', 'Month', 'All'],
                  _selectedStatsTab,
                  (i) => setState(() => _selectedStatsTab = i),
                ),
              ],
            ),
          ),
          _statsMetricRow(
            CupertinoIcons.check_mark_circled,
            AppTheme.accentColor,
            'Total Breaks',
            'Completed rest sessions',
            '$_calculatedBreaks',
          ),
          divider(),
          _statsMetricRow(
            CupertinoIcons.clock,
            AppTheme.shortBreakColor,
            'Short Breaks',
            'Quick micro-breaks',
            '${(_calculatedBreaks * 0.8).round()}',
          ),
          divider(),
          _statsMetricRow(
            CupertinoIcons.pause_circle,
            AppTheme.longBreakColor,
            'Long Breaks',
            'Extended recovery rest',
            '${(_calculatedBreaks * 0.2).round()}',
          ),
          divider(),
          _statsMetricRow(
            CupertinoIcons.chart_pie,
            AppTheme.upcomingBreakColor,
            'Completion Rate',
            'Success frequency',
            '${(_calculatedCompletionRate * 100).toInt()}%',
          ),
          const SizedBox(height: 8),
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: options.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          return GestureDetector(
            onTap: () => onSelected(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontFamily: 'Satoshi',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _subTabButton(
    String label,
    int index, {
    bool isSmall = false,
    int? currentTab,
    ValueChanged<int>? onTabChanged,
  }) {
    final selectedIdx = currentTab ?? _statsSubTab;
    final isSelected = selectedIdx == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (onTabChanged != null) {
            onTabChanged(index);
          } else {
            setState(() => _statsSubTab = index);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: isSmall ? 10 : 12,
                letterSpacing: -0.1,
                fontFamily: 'Satoshi',
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _heatSquare(Color color) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _statsMetricRow(
    IconData icon,
    Color color,
    String label,
    String subtitle,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Satoshi',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontFamily: 'Satoshi',
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontFamily: 'Satoshi',
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  int get _calculatedBreaks {
    switch (_selectedStatsTab) {
      case 0: // Today
        if (_stats.weeklyData.isNotEmpty) {
          final now = DateTime.now();
          final today =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          return _stats.weeklyData
              .firstWhere(
                (d) => d.date == today,
                orElse: () => _stats.weeklyData.last,
              )
              .breaksCompleted;
        }
        return 0;
      case 1: // Week
        return _stats.weeklyData.fold<int>(
          0,
          (sum, day) => sum + day.breaksCompleted,
        );
      case 2: // Month
      case 3: // All
      default:
        return _stats.breaksCompleted;
    }
  }

  int get _calculatedSkipped {
    switch (_selectedStatsTab) {
      case 0: // Today
        if (_stats.weeklyData.isNotEmpty) {
          final now = DateTime.now();
          final today =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          return _stats.weeklyData
              .firstWhere(
                (d) => d.date == today,
                orElse: () => _stats.weeklyData.last,
              )
              .breaksSkipped;
        }
        return 0;
      case 1: // Week
        return _stats.weeklyData.fold<int>(
          0,
          (sum, day) => sum + day.breaksSkipped,
        );
      case 2: // Month
      case 3: // All
      default:
        return _stats.breaksSkipped;
    }
  }

  double get _calculatedCompletionRate {
    final total = _calculatedBreaks + _calculatedSkipped;
    if (total == 0) return 0.0;
    return _calculatedBreaks / total;
  }
}
