import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/features/analytics/stats_service.dart';

class ProductivityTrendChart extends StatelessWidget {
  final List<DailyStats> weeklyData;

  const ProductivityTrendChart({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final spots = weeklyData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.breaksCompleted.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),

        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,

              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index >= weeklyData.length) {
                  return const SizedBox();
                }

                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    weeklyData[index].dayName,
                    style: AppTheme.sectionTitle.copyWith(
                      fontSize: 9,
                      color: AppTheme.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        borderData: FlBorderData(show: false),

        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 5,
              color: AppTheme.textMuted.withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ],
        ),

        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.accentColor,
            barWidth: 3,
            isStrokeCapRound: true,

            dotData: FlDotData(
              show: true,

              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.accentColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),

            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.accentColor.withValues(alpha: 0.15),
                  AppTheme.accentColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.black.withValues(alpha: 0.8),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.all(8),

            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final day = weeklyData[spot.x.toInt()];

                return LineTooltipItem(
                  '${day.dayName}: ${spot.y.toInt()} breaks',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
