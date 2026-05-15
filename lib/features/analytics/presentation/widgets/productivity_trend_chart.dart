import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:standup/shared/theme/app_theme.dart';

class ProductivityTrendChart extends StatelessWidget {
  const ProductivityTrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 3),
              const FlSpot(1, 4),
              const FlSpot(2, 3.5),
              const FlSpot(3, 5),
              const FlSpot(4, 4.2),
              const FlSpot(5, 6),
              const FlSpot(6, 5.5),
            ],
            isCurved: true,
            color: AppTheme.accentColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.accentColor.withValues(alpha: 0.2),
                  AppTheme.accentColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
