import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Break-taking statistics: a handful of period-scoped metric rows plus a
/// GitHub-style yearly heatmap built from [StatsModel.weeklyData] (which
/// retains up to 365 daily entries — see `StatsService._refreshStatsAsync`).
class BreakStatisticsSection extends StatelessWidget {
  final StatsModel stats;

  /// 0 = Today, 1 = This Week, 2 = Month — same convention as
  /// `AnalyticsSettingsSection._selectedFilter`.
  final int selectedFilter;

  const BreakStatisticsSection({
    super.key,
    required this.stats,
    required this.selectedFilter,
  });

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  ({int completed, int skipped}) _periodTotals() {
    if (selectedFilter == 0) {
      final matches = stats.weeklyData.where((d) => d.date == _todayKey());
      if (matches.isEmpty) return (completed: 0, skipped: 0);
      final today = matches.first;
      return (completed: today.breaksCompleted, skipped: today.breaksSkipped);
    }

    final now = DateTime.now();
    final rangeData = selectedFilter == 2
        ? stats.weeklyData.where((d) {
            final parts = d.date.split('-');
            return parts.length == 3 &&
                int.tryParse(parts[0]) == now.year &&
                int.tryParse(parts[1]) == now.month;
          }).toList()
        : (stats.weeklyData.length > 7
              ? stats.weeklyData.sublist(stats.weeklyData.length - 7)
              : stats.weeklyData);

    final completed = rangeData.fold<int>(0, (s, d) => s + d.breaksCompleted);
    final skipped = rangeData.fold<int>(0, (s, d) => s + d.breaksSkipped);
    return (completed: completed, skipped: skipped);
  }

  @override
  Widget build(BuildContext context) {
    final totals = _periodTotals();
    final total = totals.completed + totals.skipped;
    final skipRate = total > 0 ? totals.skipped / total : 0.0;
    final daysWithBreaks = stats.weeklyData
        .where((d) => d.breaksCompleted > 0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Break Statistics'),
        const SizedBox(height: 16),
        buildCard([
          _metricRow(
            CupertinoIcons.person_alt,
            'Total Breaks',
            'completed this period',
            '$total',
          ),
          divider(),
          _metricRow(
            CupertinoIcons.arrow_uturn_left,
            'Skip Rate',
            'breaks skipped this period',
            '${(skipRate * 100).round()}%',
          ),
          divider(),
          _metricRow(
            CupertinoIcons.flame_fill,
            'Current Streak',
            'consecutive days',
            '${stats.currentStreak}',
          ),
          divider(),
          _metricRow(
            CupertinoIcons.rosette,
            'Best Streak',
            'days without skip',
            '${stats.longestStreak}',
          ),
          divider(),
          _metricRow(
            CupertinoIcons.chart_bar,
            'Avg Breaks/Day',
            'last 7 days',
            stats.averageBreaksPerDay.toStringAsFixed(1),
          ),
        ]),
        const SizedBox(height: 32),
        sectionHeader(
          'Break Activity',
          subtitle: 'Your break consistency this year',
        ),
        const SizedBox(height: 16),
        buildCard([
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _YearlyHeatmap(days: stats.weeklyData),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'How it works: ',
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                            fontFamily: 'Inter',
                          ),
                        ),
                        _legendDot(Colors.white.withValues(alpha: 0.06)),
                        const SizedBox(width: 4),
                        _legendDot(const Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        _legendDot(const Color(0xFF4ADE80)),
                      ],
                    ),
                    Text(
                      '$daysWithBreaks days with breaks this year',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _metricRow(
    IconData icon,
    String label,
    String sublabel,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.accentColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyHeatmap extends StatelessWidget {
  final List<DailyStats> days;

  const _YearlyHeatmap({required this.days});

  static const _monthLabels = [
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

  Color _colorFor(DailyStats? stat) {
    final total = (stat?.breaksCompleted ?? 0) + (stat?.breaksSkipped ?? 0);
    if (stat == null || total == 0) return Colors.white.withValues(alpha: 0.06);
    final rate = stat.breaksCompleted / total;
    return rate >= 0.85 ? const Color(0xFF4ADE80) : const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in days) d.date: d};
    final year = DateTime.now().year;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(12, (monthIndex) {
          final month = monthIndex + 1;
          final daysInMonth = DateTime(year, month + 1, 0).day;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthLabels[monthIndex],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 91,
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: List.generate(daysInMonth, (dayIndex) {
                      final day = dayIndex + 1;
                      final key =
                          '${year.toString().padLeft(4, '0')}-'
                          '${month.toString().padLeft(2, '0')}-'
                          '${day.toString().padLeft(2, '0')}';
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorFor(byDate[key]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
