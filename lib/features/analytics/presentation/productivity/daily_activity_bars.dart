part of 'productivity_cards.dart';

/// The daily bars behind the week and month views.
class DailyActivityBars extends StatefulWidget {
  const DailyActivityBars({super.key, required this.days, this.goalSeconds});

  final List<DailyProductivitySummary> days;

  /// The daily focus goal. When set, a dashed line marks it and days that
  /// reach it turn green, so "was this a good day?" needs no arithmetic.
  final int? goalSeconds;

  @override
  State<DailyActivityBars> createState() => _DailyActivityBarsState();
}

class _DailyActivityBarsState extends State<DailyActivityBars> {
  DailyProductivitySummary? _hoveredDay;

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

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.days.isEmpty) return const SizedBox.shrink();

    final todayStr = _todayStr();
    final goal = widget.goalSeconds != null && widget.goalSeconds! > 0
        ? widget.goalSeconds
        : null;
    final dataPeak = widget.days
        .map((day) => day.activeSeconds)
        .fold<int>(0, (best, value) => value > best ? value : best);
    // The scale must reach the goal line or it would sit off the chart.
    final peak = goal != null && goal > dataPeak ? goal : dataPeak;

    final activeDays = widget.days.where((d) => d.activeSeconds > 0).toList();
    final totalActiveSeconds = widget.days.fold<int>(
      0,
      (sum, d) => sum + d.activeSeconds,
    );
    final avgActiveSeconds = widget.days.isEmpty
        ? 0
        : totalActiveSeconds ~/ (activeDays.isEmpty ? 1 : activeDays.length);

    DailyProductivitySummary? peakDay;
    for (final day in widget.days) {
      if (peakDay == null || day.activeSeconds > peakDay.activeSeconds) {
        peakDay = day;
      }
    }

    final isSparseLabels = widget.days.length > 10;
    final labelInterval = isSparseLabels
        ? (widget.days.length / 5).ceil().clamp(1, widget.days.length)
        : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderHud(avgActiveSeconds, peakDay, todayStr),
          const SizedBox(height: 16),
          SizedBox(
            height: 124,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildYAxisLabels(peak),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      _buildGuidelines(),
                      if (goal != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 22 + (goal / peak) * (124 - 22),
                          child: _GoalLine(label: formatDuration(goal)),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 0; i < widget.days.length; i++)
                            Expanded(
                              child: _buildBarItem(
                                day: widget.days[i],
                                peakSeconds: peak,
                                goalSeconds: goal,
                                isToday: widget.days[i].date == todayStr,
                                isHovered:
                                    _hoveredDay?.date == widget.days[i].date,
                                showLabel:
                                    !isSparseLabels ||
                                    i == 0 ||
                                    i == widget.days.length - 1 ||
                                    i % labelInterval == 0,
                                isSparseLabels: isSparseLabels,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (goal != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _LegendDot(color: AppTheme.success, label: 'Reached goal'),
                const SizedBox(width: 14),
                _LegendDot(color: AppTheme.accent, label: 'Below goal'),
                const SizedBox(width: 14),
                Text(
                  'Dashed line = daily goal',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderHud(
    int avgActiveSeconds,
    DailyProductivitySummary? peakDay,
    String todayStr,
  ) {
    if (_hoveredDay != null) {
      final day = _hoveredDay!;
      final isToday = day.date == todayStr;
      final parsed = DateTime.tryParse(day.date);
      final monthName = parsed != null ? _monthNames[parsed.month - 1] : '';
      final dateLabel = isToday
          ? 'Today'
          : parsed != null
          ? '${shortWeekday(day.date)}, ${parsed.day} $monthName'
          : day.date;

      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${formatDuration(day.activeSeconds)} active',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          if (day.breakSeconds > 0) ...[
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              '${formatDuration(day.breakSeconds)} breaks',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.success,
              ),
            ),
          ],
          if (day.contextSwitches > 0) ...[
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              '${day.contextSwitches} switches',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.warning,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Daily average: ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: AppTheme.textMuted,
              ),
            ),
            Text(
              formatDuration(avgActiveSeconds),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        if (peakDay != null && peakDay.activeSeconds > 0)
          Text(
            'Peak: ${formatDuration(peakDay.activeSeconds)} (${shortWeekday(peakDay.date)})',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
      ],
    );
  }

  Widget _buildYAxisLabels(int peakSeconds) {
    final peakHours = peakSeconds > 0 ? (peakSeconds / 3600) : 0.0;
    final topLabel = peakHours >= 1
        ? '${peakHours.round()}h'
        : peakSeconds > 0
        ? '${(peakSeconds / 60).round()}m'
        : '0h';
    final midLabel = peakHours >= 1
        ? '${(peakHours / 2).round()}h'
        : peakSeconds > 0
        ? '${(peakSeconds / 120).round()}m'
        : '';

    return SizedBox(
      width: 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            topLabel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted.withValues(alpha: 0.65),
            ),
          ),
          if (midLabel.isNotEmpty)
            Text(
              midLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted.withValues(alpha: 0.5),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGuidelines() {
    return Positioned.fill(
      bottom: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 1,
            color: AppTheme.textMuted.withValues(alpha: 0.08),
          ),
          Container(
            height: 1,
            color: AppTheme.textMuted.withValues(alpha: 0.06),
          ),
          Container(
            height: 1,
            color: AppTheme.textMuted.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem({
    required DailyProductivitySummary day,
    required int peakSeconds,
    required int? goalSeconds,
    required bool isToday,
    required bool isHovered,
    required bool showLabel,
    required bool isSparseLabels,
  }) {
    final fraction = peakSeconds == 0 ? 0.0 : day.activeSeconds / peakSeconds;
    final reachedGoal = goalSeconds != null && day.activeSeconds >= goalSeconds;
    final barColor = reachedGoal ? AppTheme.success : AppTheme.accent;
    final parsed = DateTime.tryParse(day.date);
    final bottomLabel = isSparseLabels
        ? (isToday
              ? 'Today'
              : parsed != null
              ? '${parsed.day}'
              : '')
        : shortWeekday(day.date);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredDay = day),
      onExit: (_) => setState(() {
        if (_hoveredDay?.date == day.date) _hoveredDay = null;
      }),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSparseLabels ? 1.5 : 4),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.04),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: day.activeSeconds == 0
                        ? 0.0
                        : fraction.clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isHovered
                              ? [
                                  barColor,
                                  Color.lerp(barColor, Colors.white, 0.35) ??
                                      barColor,
                                ]
                              : isToday
                              ? [
                                  barColor,
                                  Color.lerp(barColor, Colors.white, 0.2) ??
                                      barColor,
                                ]
                              : [
                                  barColor.withValues(alpha: 0.55),
                                  barColor.withValues(alpha: 0.9),
                                ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, -1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 16,
              child: showLabel
                  ? Text(
                      bottomLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: isSparseLabels ? 9 : 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? AppTheme.accent
                            : AppTheme.textMuted.withValues(alpha: 0.8),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final dashes = (c.maxWidth / 8).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < dashes; i++)
                    Container(
                      width: 4,
                      height: 1.2,
                      color: AppTheme.success.withValues(alpha: 0.7),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
