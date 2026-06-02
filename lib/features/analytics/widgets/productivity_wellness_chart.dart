import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class ProductivityWellnessChart extends StatelessWidget {
  final StatsModel stats;

  const ProductivityWellnessChart({super.key, required this.stats});

  /// Build a Sun–Sat grid for the current week, mapped by date.
  List<_WeekSlot> _buildWeekSlots() {
    final now = DateTime.now();
    final daysFromSunday = now.weekday % 7;
    final sunday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysFromSunday));

    final Map<String, DailyStats> byDate = {
      for (final d in stats.weeklyData) d.date: d,
    };

    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return List.generate(7, (i) {
      final day = sunday.add(Duration(days: i));
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final s = byDate[dateStr];
      final isToday = day.year == now.year &&
          day.month == now.month &&
          day.day == now.day;
      return _WeekSlot(
        label: labels[i],
        breaksCompleted: s?.breaksCompleted ?? 0,
        wellnessActions: s?.wellnessActions ?? 0,
        isToday: isToday,
        isFuture: day.isAfter(now),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slots = _buildWeekSlots();

    double maxValue = 5;
    for (final s in slots) {
      if (s.breaksCompleted > maxValue) maxValue = s.breaksCompleted.toDouble();
      if (s.wellnessActions > maxValue) maxValue = s.wellnessActions.toDouble();
    }
    maxValue += 2;

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
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Colors.black.withValues(alpha: 0.85),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final slot = slots[groupIndex];
                      return BarTooltipItem(
                        '${slot.label}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: 'Breaks: ${slot.breaksCompleted}\n',
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: 'Wellness: ${slot.wellnessActions}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
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
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= slots.length) {
                          return const SizedBox.shrink();
                        }
                        final slot = slots[i];
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            slot.label,
                            style: TextStyle(
                              color: slot.isToday
                                  ? AppTheme.accentColor
                                  : AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: slot.isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        );
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 10 ? 5 : 2,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.textMuted.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: slots.asMap().entries.map((e) {
                  final i = e.key;
                  final slot = e.value;
                  final opacity = slot.isFuture ? 0.25 : 1.0;
                  return BarChartGroupData(
                    x: i,
                    groupVertically: false,
                    barRods: [
                      BarChartRodData(
                        toY: slot.breaksCompleted.toDouble(),
                        color: AppTheme.accentColor.withValues(alpha: opacity),
                        width: 9,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: slot.wellnessActions.toDouble(),
                        color: const Color(0xFF10B981).withValues(alpha: opacity),
                        width: 9,
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
        _legendItem('Breaks', AppTheme.accentColor),
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

class _WeekSlot {
  final String label;
  final int breaksCompleted;
  final int wellnessActions;
  final bool isToday;
  final bool isFuture;

  const _WeekSlot({
    required this.label,
    required this.breaksCompleted,
    required this.wellnessActions,
    required this.isToday,
    required this.isFuture,
  });
}
