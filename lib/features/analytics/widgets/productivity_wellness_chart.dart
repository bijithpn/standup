import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class ProductivityWellnessChart extends StatelessWidget {
  final StatsModel stats;

  const ProductivityWellnessChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    // Determine max value for scaling
    double maxValue = 10;
    for (final day in stats.weeklyData) {
      final productivity = day.breaksCompleted.toDouble();
      final wellness = day.wellnessActions.toDouble();
      if (productivity > maxValue) maxValue = productivity;
      if (wellness > maxValue) maxValue = wellness;
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Productivity vs Wellness',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              _buildLegendRow(),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue + 2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) =>
                        Colors.black.withValues(alpha: 0.8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = stats.weeklyData[groupIndex];
                      return BarTooltipItem(
                        '${day.dayName}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: 'Productivity: ${day.breaksCompleted}\n',
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: 'Wellness: ${day.wellnessActions}',
                            style: const TextStyle(
                              color: Color(0xFF10B981), // Success green
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
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
                          return SideTitleWidget(
                            meta: meta,
                            space: 10,
                            child: Text(
                              stats.weeklyData[value.toInt()].dayName,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
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
                      // Productivity Rod (Breaks Completed)
                      BarChartRodData(
                        toY: day.breaksCompleted.toDouble(),
                        color: AppTheme.accentColor,
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      // Wellness Rod (Wellness Actions)
                      BarChartRodData(
                        toY: day.wellnessActions.toDouble(),
                        color: const Color(0xFF10B981), // Success green
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendItem('Productivity', AppTheme.accentColor),
        const SizedBox(width: 12),
        _legendItem('Wellness', const Color(0xFF10B981)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
