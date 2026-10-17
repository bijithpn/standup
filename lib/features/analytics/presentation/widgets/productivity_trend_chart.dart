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

  static String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static const _monthNames = [
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

  List<_BarSlot> _weekSlots() {
    final now = DateTime.now();
    final sunday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    final byDate = <String, DailyStats>{for (final d in weeklyData) d.date: d};
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return List.generate(7, (i) {
      final day = sunday.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final isFuture = day.isAfter(now);
      final isToday = key == _todayStr();
      final stats = byDate[key];
      return _BarSlot(
        label: labels[i],
        dateStr: '${_monthNames[day.month - 1]} ${day.day}',
        value: isFuture ? 0 : (stats?.breaksCompleted ?? 0),
        breaksSkipped: isFuture ? 0 : (stats?.breaksSkipped ?? 0),
        usageMinutes: isFuture ? 0 : (stats?.usageMinutes ?? 0),
        isToday: isToday,
        isFuture: isFuture,
      );
    });
  }

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

      int totalBreaks = 0;
      int totalSkipped = 0;
      int totalUsage = 0;
      bool isCurrent = false;

      for (
        var d = cursor;
        !d.isAfter(bucketEnd);
        d = d.add(const Duration(days: 1))
      ) {
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final s = byDate[key];
        totalBreaks += s?.breaksCompleted ?? 0;
        totalSkipped += s?.breaksSkipped ?? 0;
        totalUsage += s?.usageMinutes ?? 0;
        if (key == todayStr) isCurrent = true;
      }

      final isFuture = cursor.isAfter(now);
      final monthName = _monthNames[cursor.month - 1];
      slots.add(
        _BarSlot(
          label: 'Wk $weekNum',
          dateStr: '$monthName ${cursor.day}–${bucketEnd.day}',
          value: isFuture ? 0 : totalBreaks,
          breaksSkipped: isFuture ? 0 : totalSkipped,
          usageMinutes: isFuture ? 0 : totalUsage,
          isToday: isCurrent,
          isFuture: isFuture,
        ),
      );

      cursor = bucketEnd.add(const Duration(days: 1));
      weekNum++;
    }

    return slots;
  }

  @override
  Widget build(BuildContext context) {
    if (period == ChartPeriod.today) return _buildTodayChart();
    final slots = period == ChartPeriod.week ? _weekSlots() : _monthSlots();
    return _buildWeekMonthChart(slots, period == ChartPeriod.week ? 22 : 30);
  }

  Widget _buildTodayChart() {
    final today = _todayStr();
    final d = weeklyData.firstWhere(
      (s) => s.date == today,
      orElse: () => DailyStats(
        date: today,
        breaksCompleted: 0,
        breaksSkipped: 0,
        usageMinutes: 0,
      ),
    );

    final done = d.breaksCompleted;
    final skipped = d.breaksSkipped;
    final total = done + skipped;
    final rate = total == 0 ? 0 : ((done / total) * 100).round();

    final sections = total == 0
        ? [
            PieChartSectionData(
              value: 1,
              color: AppTheme.accentColor.withValues(alpha: 0.12),
              radius: 32,
              showTitle: false,
            ),
          ]
        : [
            PieChartSectionData(
              value: done.toDouble(),
              color: AppTheme.accentColor,
              radius: 32,
              showTitle: false,
            ),
            if (skipped > 0)
              PieChartSectionData(
                value: skipped.toDouble(),
                color: const Color(0xFFF43F5E),
                radius: 32,
                showTitle: false,
              ),
          ];

    return Row(
      children: [
        SizedBox(
          width: 136,
          height: 136,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 36,
                  sectionsSpace: total == 0 ? 0 : 3,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total == 0 ? '—' : '$rate%',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: total == 0
                          ? AppTheme.textMuted
                          : AppTheme.accentColor,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    total == 0 ? 'no breaks' : '$done of $total',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TodayMetricTile(
                icon: Icons.check_circle_rounded,
                iconColor: AppTheme.accentColor,
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.08),
                label: 'Completed',
                value: '$done',
                unit: done == 1 ? 'break' : 'breaks',
              ),
              const SizedBox(height: 8),
              _TodayMetricTile(
                icon: Icons.cancel_rounded,
                iconColor: const Color(0xFFF43F5E),
                backgroundColor: const Color(
                  0xFFF43F5E,
                ).withValues(alpha: 0.08),
                label: 'Skipped',
                value: '$skipped',
                unit: skipped == 1 ? 'break' : 'breaks',
              ),
              const SizedBox(height: 8),
              _TodayMetricTile(
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFFF59E0B),
                backgroundColor: const Color(
                  0xFFF59E0B,
                ).withValues(alpha: 0.08),
                label: 'Active time',
                value: _formatMinutes(d.usageMinutes),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekMonthChart(List<_BarSlot> slots, double barWidth) {
    double maxValue = 0;
    for (final s in slots) {
      if (s.value > maxValue) maxValue = s.value.toDouble();
    }
    // Dynamic ceiling with a clean minimum
    final double maxY = maxValue < 4
        ? 4
        : (maxValue + (maxValue * 0.25)).ceilToDouble();

    // Calculate clean integer intervals for guidelines and left axis
    final double interval = maxY <= 4
        ? 1
        : maxY <= 8
        ? 2
        : maxY <= 16
        ? 4
        : (maxY / 4).ceilToDouble();

    final groups = slots.asMap().entries.map((e) {
      final slot = e.value;
      final isToday = slot.isToday;
      final isFuture = slot.isFuture;

      final gradient = isFuture
          ? LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppTheme.accentColor.withValues(alpha: 0.08),
                AppTheme.accentColor.withValues(alpha: 0.14),
              ],
            )
          : isToday
          ? LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppTheme.accentColor,
                Color.lerp(AppTheme.accentColor, Colors.white, 0.3) ??
                    AppTheme.accentColor,
              ],
            )
          : LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppTheme.accentColor.withValues(alpha: 0.45),
                AppTheme.accentColor.withValues(alpha: 0.85),
              ],
            );

      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: slot.value.toDouble(),
            gradient: gradient,
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: AppTheme.accentColor.withValues(alpha: 0.04),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: groups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.textMuted.withValues(alpha: 0.1),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            tooltipBorderRadius: BorderRadius.circular(10),
            tooltipBorder: BorderSide(
              color: AppTheme.accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
            getTooltipItem: (group, gi, rod, ri) {
              final slot = slots[group.x];
              final title = slot.dateStr.isNotEmpty
                  ? '${slot.label} · ${slot.dateStr}'
                  : slot.label;
              return BarTooltipItem(
                '$title\n',
                const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text:
                        '${rod.toY.toInt()} ${rod.toY.toInt() == 1 ? 'break' : 'breaks'} completed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (slot.breaksSkipped > 0)
                    TextSpan(
                      text: '\n${slot.breaksSkipped} skipped',
                      style: const TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (slot.usageMinutes > 0)
                    TextSpan(
                      text: '\n${_formatMinutes(slot.usageMinutes)} active',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value <= 0 || value > maxY) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted.withValues(alpha: 0.65),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= slots.length) return const SizedBox.shrink();
                final slot = slots[i];
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slot.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: slot.isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: slot.isToday
                              ? AppTheme.accentColor
                              : slot.isFuture
                              ? AppTheme.textMuted.withValues(alpha: 0.4)
                              : AppTheme.textMuted.withValues(alpha: 0.85),
                        ),
                      ),
                      if (slot.isToday) ...[
                        const SizedBox(height: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BarSlot {
  final String label;
  final String dateStr;
  final int value;
  final int breaksSkipped;
  final int usageMinutes;
  final bool isToday;
  final bool isFuture;

  const _BarSlot({
    required this.label,
    required this.dateStr,
    required this.value,
    required this.breaksSkipped,
    required this.usageMinutes,
    required this.isToday,
    required this.isFuture,
  });
}

class _TodayMetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final String value;
  final String? unit;

  const _TodayMetricTile({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.value,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Text(
              unit!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
