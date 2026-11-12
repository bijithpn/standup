import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:breakmate/features/analytics/focus_trend.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Daily Focus Score over [points]: a smooth line with a soft gradient fill,
/// faint 0/50/100 guides, and a marker only on the latest day. Touch a point
/// for its exact value.
class FocusTrendChart extends StatelessWidget {
  final List<FocusTrendPoint> points;

  const FocusTrendChart({super.key, required this.points});

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final accent = AppTheme.accentColor;
    final last = points.length - 1;
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), (points[i].focusScore * 100).clamp(0, 100)),
    ];
    // Weekday names crowd the axis past ~10 points; fall back to day numbers.
    final weekly = points.length <= 10;
    final step = weekly ? 1 : (points.length / 6).ceil();
    String label(int i) => weekly
        ? _weekdays[points[i].date.weekday % 7]
        : '${points[i].date.day}';

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: last.toDouble(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.border.withValues(alpha: 0.7),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 50,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  '${v.toInt()}%',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (v != i.toDouble() || i < 0 || i > last) {
                  return const SizedBox.shrink();
                }
                if (i != last && (i % step != 0 || last - i < step ~/ 2 + 1)) {
                  return const SizedBox.shrink();
                }
                final today = i == last;
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    today ? 'Today' : label(i),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: today ? FontWeight.w700 : FontWeight.w500,
                      color: today ? accent : AppTheme.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: accent.withValues(alpha: 0.4), strokeWidth: 1),
                FlDotData(
                  getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                    radius: 5,
                    color: accent,
                    strokeWidth: 2,
                    strokeColor: AppTheme.surfaceCard,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.surfaceElevated,
            tooltipBorder: BorderSide(color: AppTheme.border),
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItems: (touched) => [
              for (final s in touched)
                LineTooltipItem(
                  '${points[s.x.toInt()].date.day} '
                  '${_months[points[s.x.toInt()].date.month - 1]}\n',
                  TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  children: [
                    TextSpan(
                      text: '${s.y.round()}% focus',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: accent,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (s, _) => s.x == last.toDouble(),
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                radius: 4.5,
                color: accent,
                strokeWidth: 2.5,
                strokeColor: AppTheme.surfaceCard,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
