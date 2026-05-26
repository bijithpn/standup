import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DailyStatsChart extends StatelessWidget {
  final StatsModel stats;
  
  const DailyStatsChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // Get the maximum value for any day to scale the chart correctly
    double maxTotal = 10;
    for (final day in stats.weeklyData) {
      final total = (day.breaksCompleted + day.breaksSkipped).toDouble();
      if (total > maxTotal) maxTotal = total;
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Progress', style: AppTheme.sectionTitle),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxTotal + 2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = stats.weeklyData[groupIndex];
                      return BarTooltipItem(
                        '${day.dayName}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: 'Completed: ${day.breaksCompleted}\n',
                            style: const TextStyle(
                              color: Color(0xFF06B6D4),
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: 'Skipped: ${day.breaksSkipped}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < stats.weeklyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              stats.weeklyData[value.toInt()].dayName,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: stats.weeklyData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: day.breaksCompleted.toDouble(),
                        color: AppTheme.shortBreakColor,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        fromY: day.breaksCompleted.toDouble(),
                        toY: (day.breaksCompleted + day.breaksSkipped)
                            .toDouble(),
                        color: Colors.redAccent.withValues(alpha: 0.6),
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend('Completed', AppTheme.shortBreakColor),
              const SizedBox(width: 16),
              _buildLegend('Skipped', Colors.redAccent.withValues(alpha: 0.6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
