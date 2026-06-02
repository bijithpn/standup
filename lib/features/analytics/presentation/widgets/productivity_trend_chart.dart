import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/analytics/stats_service.dart';

enum ChartPeriod { today, week, month }

class ProductivityTrendChart extends StatelessWidget {
  final List<DailyStats> weeklyData;
  final ChartPeriod period;

  const ProductivityTrendChart({
    super.key,
    required this.weeklyData,
    this.period = ChartPeriod.week,
  });

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Week: Sun–Sat of the current week ──────────────────────────────────────

  List<_BarSlot> _weekSlots() {
    final now = DateTime.now();
    final sunday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));
    final byDate = <String, DailyStats>{for (final d in weeklyData) d.date: d};
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return List.generate(7, (i) {
      final day = sunday.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final isFuture = day.isAfter(now);
      final isToday = key == _todayStr();
      return _BarSlot(
        label: labels[i],
        value: isFuture ? 0 : (byDate[key]?.breaksCompleted ?? 0),
        isToday: isToday,
        isFuture: isFuture,
      );
    });
  }

  // ── Month: week-by-week totals for the current month ───────────────────────

  List<_BarSlot> _monthSlots() {
    final now = DateTime.now();
    final byDate = <String, DailyStats>{for (final d in weeklyData) d.date: d};
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final lastOfMonth = DateTime(now.year, now.month + 1, 0);
    final todayStr = _todayStr();

    final slots = <_BarSlot>[];
    DateTime cursor = firstOfMonth;
    int weekNum = 1;

    while (!cursor.isAfter(lastOfMonth)) {
      final end = cursor.add(const Duration(days: 6));
      final bucketEnd = end.isAfter(lastOfMonth) ? lastOfMonth : end;

      int total = 0;
      bool isCurrent = false;
      for (var d = cursor; !d.isAfter(bucketEnd); d = d.add(const Duration(days: 1))) {
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        total += byDate[key]?.breaksCompleted ?? 0;
        if (key == todayStr) isCurrent = true;
      }

      slots.add(_BarSlot(
        label: 'Wk $weekNum',
        value: total,
        isToday: isCurrent,
        isFuture: cursor.isAfter(now),
      ));

      cursor = bucketEnd.add(const Duration(days: 1));
      weekNum++;
    }

    return slots;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (period == ChartPeriod.today) return _buildTodayChart();
    final slots = period == ChartPeriod.week ? _weekSlots() : _monthSlots();
    return _buildWeekMonthChart(slots, period == ChartPeriod.week ? 22 : 32);
  }

  // Today: pie chart (Done vs Skipped) + usage minutes ─────────────────────

  Widget _buildTodayChart() {
    final today = _todayStr();
    final d = weeklyData.firstWhere(
      (s) => s.date == today,
      orElse: () => DailyStats(
          date: today, breaksCompleted: 0, breaksSkipped: 0, usageMinutes: 0),
    );

    final done = d.breaksCompleted;
    final skipped = d.breaksSkipped;
    final total = done + skipped;

    // If no data yet, show an empty-state ring
    final sections = total == 0
        ? [
            PieChartSectionData(
              value: 1,
              color: AppTheme.accentColor.withValues(alpha: 0.12),
              radius: 38,
              showTitle: false,
            ),
          ]
        : [
            PieChartSectionData(
              value: done.toDouble(),
              color: AppTheme.accentColor,
              radius: 38,
              showTitle: false,
            ),
            PieChartSectionData(
              value: skipped.toDouble(),
              color: const Color(0xFFEF4444),
              radius: 38,
              showTitle: false,
            ),
          ];

    return Row(
      children: [
        // Pie / donut
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 38,
                  sectionsSpace: total == 0 ? 0 : 3,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total == 0 ? '—' : '$done',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    'of $total',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Legend + minutes
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PieLegendRow(
                color: AppTheme.accentColor,
                label: 'Completed',
                value: '$done',
              ),
              const SizedBox(height: 10),
              _PieLegendRow(
                color: const Color(0xFFEF4444),
                label: 'Skipped',
                value: '$skipped',
              ),
              const SizedBox(height: 14),
              Container(
                height: 1,
                color: AppTheme.textMuted.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 14),
              _PieLegendRow(
                color: const Color(0xFFF59E0B),
                label: 'Active mins',
                value: '${d.usageMinutes}',
                icon: Icons.timer_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Week / Month: breaks-per-day or per-week bars ────────────────────────────

  Widget _buildWeekMonthChart(List<_BarSlot> slots, double barWidth) {
    double maxY = 5;
    for (final s in slots) {
      if (s.value > maxY) maxY = s.value.toDouble();
    }
    maxY = (maxY + 2).ceilToDouble();

    final groups = slots.asMap().entries.map((e) {
      final slot = e.value;
      final color = slot.isFuture
          ? AppTheme.accentColor.withValues(alpha: 0.15)
          : slot.isToday
              ? AppTheme.accentColor
              : AppTheme.accentColor.withValues(alpha: 0.55);

      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: slot.value.toDouble(),
            color: color,
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: AppTheme.accentColor.withValues(alpha: 0.05),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(BarChartData(
      maxY: maxY,
      barGroups: groups,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.black.withValues(alpha: 0.8),
          tooltipBorderRadius: BorderRadius.circular(8),
          getTooltipItem: (group, gi, rod, ri) {
            final slot = slots[group.x];
            return BarTooltipItem(
              '${slot.label}\n${rod.toY.toInt()} breaks',
              const TextStyle(color: Colors.white, fontSize: 12),
            );
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
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= slots.length) return const SizedBox.shrink();
              final slot = slots[i];
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  slot.label,
                  style: AppTheme.sectionTitle.copyWith(
                    fontSize: 11,
                    fontWeight: slot.isToday ? FontWeight.w700 : FontWeight.w500,
                    color: slot.isToday
                        ? AppTheme.accentColor
                        : AppTheme.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ));
  }
}

class _BarSlot {
  final String label;
  final int value;
  final bool isToday;
  final bool isFuture;
  const _BarSlot({
    required this.label,
    required this.value,
    required this.isToday,
    required this.isFuture,
  });
}

class _PieLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final IconData? icon;

  const _PieLegendRow({
    required this.color,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon != null
            ? Icon(icon, size: 12, color: color)
            : Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
