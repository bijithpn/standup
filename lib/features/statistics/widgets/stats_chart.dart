import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/statistics/stats_model.dart';
import 'package:standup/ui/theme/app_theme.dart';

class DailyStatsChart extends StatelessWidget {
  final StatsModel stats;
  
  const DailyStatsChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Progress', style: AppTheme.sectionTitle),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (stats.breaksCompleted + stats.breaksSkipped).toDouble() + 5,
                barTouchData: BarTouchData(enabled: false),
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: stats.breaksCompleted.toDouble(),
                        color: AppTheme.shortBreakColor,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: stats.breaksSkipped.toDouble(),
                        color: Colors.redAccent.withValues(alpha: 0.6),
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
