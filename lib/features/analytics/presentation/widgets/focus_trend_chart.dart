import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:breakmate/features/analytics/focus_trend.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// A line chart of daily Focus Score over [points] — the trend view the
/// single "today" percentage on [FocusScoreCard] doesn't give: is focus
/// improving or slipping, not just what it is right now. Mirrors
/// [ProductivityTrendChart]'s visual language (accent color, no grid,
/// bordered tooltips) so the two read as one system.
class FocusTrendChart extends StatelessWidget {
  final List<FocusTrendPoint> points;

  const FocusTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value.focusScore * 100).clamp(0, 100));
    }).toList();

    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.black.withValues(alpha: 0.8),
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final point = points[spot.x.toInt()];
                return LineTooltipItem(
                  '${labels[point.date.weekday % 7]}\n${spot.y.round()}% focus',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final isToday = i == points.length - 1;
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    labels[points[i].date.weekday % 7],
                    style: AppTheme.sectionTitle.copyWith(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? AppTheme.accentColor
                          : AppTheme.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.accentColor,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.accentColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
