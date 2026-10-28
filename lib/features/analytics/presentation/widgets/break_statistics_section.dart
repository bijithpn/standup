import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Break-taking statistics: a handful of period-scoped metric rows plus a
/// GitHub-style yearly heatmap built from [StatsModel.weeklyData] (which
/// retains up to 365 daily entries — see `StatsService._refreshStatsAsync`).
class BreakStatisticsSection extends StatelessWidget {
  final StatsModel stats;

  /// 0 = Today, 1 = This Week, 2 = Month — same convention as
  /// `AnalyticsSettingsSection._selectedFilter`.
  final int selectedFilter;

  const BreakStatisticsSection({
    super.key,
    required this.stats,
    required this.selectedFilter,
  });

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get _periodLabel => switch (selectedFilter) {
    0 => 'today',
    2 => 'this month',
    _ => 'in the last 7 days',
  };

  ({int completed, int skipped, int days}) _periodTotals() {
    if (selectedFilter == 0) {
      final matches = stats.weeklyData.where((d) => d.date == _todayKey());
      if (matches.isEmpty) return (completed: 0, skipped: 0, days: 1);
      final today = matches.first;
      return (
        completed: today.breaksCompleted,
        skipped: today.breaksSkipped,
        days: 1,
      );
    }

    final now = DateTime.now();
    final rangeData = selectedFilter == 2
        ? stats.weeklyData.where((d) {
            final parts = d.date.split('-');
            return parts.length == 3 &&
                int.tryParse(parts[0]) == now.year &&
                int.tryParse(parts[1]) == now.month;
          }).toList()
        : (stats.weeklyData.length > 7
              ? stats.weeklyData.sublist(stats.weeklyData.length - 7)
              : stats.weeklyData);

    final completed = rangeData.fold<int>(0, (s, d) => s + d.breaksCompleted);
    final skipped = rangeData.fold<int>(0, (s, d) => s + d.breaksSkipped);
    // Days elapsed in the period, so the average matches what is selected.
    final days = selectedFilter == 2 ? now.day : 7;
    return (completed: completed, skipped: skipped, days: days);
  }

  @override
  Widget build(BuildContext context) {
    final totals = _periodTotals();
    final total = totals.completed + totals.skipped;
    final skipRate = total > 0 ? totals.skipped / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Break Statistics'),
        const SizedBox(height: 16),
        buildCard([
          _metricRow(
            CupertinoIcons.person_alt,
            'Breaks offered',
            'taken plus skipped, $_periodLabel',
            '$total',
          ),
          divider(),
          _metricRow(
            CupertinoIcons.arrow_uturn_left,
            'Skip rate',
            'share of breaks you skipped, $_periodLabel',
            total == 0 ? '-' : '${(skipRate * 100).round()}%',
          ),
          if (selectedFilter != 0) ...[
            divider(),
            _metricRow(
              CupertinoIcons.chart_bar,
              'Breaks taken per day',
              'average, $_periodLabel',
              (totals.completed / totals.days).toStringAsFixed(1),
            ),
          ],
        ]),
        const SizedBox(height: 32),
        sectionHeader(
          'Break Activity',
          subtitle:
              'Each square is one day. The colour shows how many of that '
              'day\'s breaks you actually took.',
        ),
        const SizedBox(height: 16),
        buildCard([_BreakActivityCard(days: stats.weeklyData)]),
      ],
    );
  }

  static Widget legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _metricRow(
    IconData icon,
    String label,
    String sublabel,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.accentColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

/// How a day reads on the grid, from the share of that day's breaks taken.
enum _HeatLevel {
  none(Color(0x0FFFFFFF), 'No breaks recorded'),
  mostlySkipped(Color(0xFFEF4444), 'Mostly skipped (under half taken)'),
  mixed(Color(0xFFF59E0B), 'Some skipped (half to 85% taken)'),
  good(Color(0xFF4ADE80), 'Took nearly all (85%+)');

  const _HeatLevel(this.color, this.meaning);
  final Color color;
  final String meaning;

  static _HeatLevel of(DailyStats? stat) {
    final total = (stat?.breaksCompleted ?? 0) + (stat?.breaksSkipped ?? 0);
    if (stat == null || total == 0) return none;
    final rate = stat.breaksCompleted / total;
    if (rate >= 0.85) return good;
    if (rate >= 0.5) return mixed;
    return mostlySkipped;
  }
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The 53 weeks ending with the current one, Monday first. A rolling window
/// (rather than the calendar year) means recent activity is always on screen.
({DateTime start, DateTime today}) _heatmapWindow() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thisMonday = today.subtract(Duration(days: today.weekday - 1));
  return (
    start: DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 52 * 7),
    today: today,
  );
}

class _HeatmapSummary extends StatelessWidget {
  final List<DailyStats> days;
  final DateTime start;
  final DateTime end;
  final String periodLabel;

  const _HeatmapSummary({
    required this.days,
    required this.start,
    required this.end,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);
    var activeDays = 0;
    var taken = 0;
    var skipped = 0;
    for (final d in days) {
      if (d.date.compareTo(startKey) < 0 || d.date.compareTo(endKey) > 0) {
        continue;
      }
      if (d.breaksCompleted + d.breaksSkipped > 0) activeDays++;
      taken += d.breaksCompleted;
      skipped += d.breaksSkipped;
    }
    final text = activeDays == 0
        ? 'No breaks recorded $periodLabel.'
        : '$activeDays ${activeDays == 1 ? 'day' : 'days'} with breaks, '
              '$taken taken and $skipped skipped $periodLabel.';
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 12.5,
        fontFamily: 'Inter',
      ),
    );
  }
}

/// The last 12 months as a calendar grid, with what the colours mean.
class _BreakActivityCard extends StatelessWidget {
  final List<DailyStats> days;

  const _BreakActivityCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final w = _heatmapWindow();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 12 months',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          _HeatmapSummary(
            days: days,
            start: w.start,
            end: w.today,
            periodLabel: 'in the last 12 months',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final level in _HeatLevel.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BreakStatisticsSection.legendDot(level.color),
                    const SizedBox(width: 6),
                    Text(
                      level.meaning,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          _YearlyHeatmap(days: days, from: w.start, to: w.today),
        ],
      ),
    );
  }
}

/// Columns are weeks, rows are Monday to Sunday.
class _YearlyHeatmap extends StatefulWidget {
  final List<DailyStats> days;

  /// First and last day to draw (inclusive); other days in the grid are blank.
  final DateTime from;
  final DateTime to;

  const _YearlyHeatmap({
    required this.days,
    required this.from,
    required this.to,
  });

  @override
  State<_YearlyHeatmap> createState() => _YearlyHeatmapState();
}

class _YearlyHeatmapState extends State<_YearlyHeatmap> {
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
  static const _weekdays = ['Mon', '', 'Wed', '', 'Fri', '', 'Sun'];
  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _gap = 3.0;
  static const _labelWidth = 30.0;

  final ScrollController _scroll = ScrollController();

  /// Columns that get a month name: the week a month begins. The partial
  /// month at the left edge is skipped when the next month starts within three
  /// weeks, otherwise two names would be drawn on top of each other.
  static List<int> _labelledWeeks(List<DateTime> weekStarts) {
    final starts = <int>[
      for (var i = 1; i < weekStarts.length; i++)
        if (weekStarts[i].month != weekStarts[i - 1].month) i,
    ];
    // Name the partial first month only when there is room before the next.
    if (starts.isEmpty || starts.first >= 3) starts.insert(0, 0);
    return starts;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in widget.days) d.date: d};
    final today = _heatmapWindow().today;
    final first = widget.from;
    final firstMonday = DateTime(
      first.year,
      first.month,
      first.day - (first.weekday - 1),
    );
    final weeks = (widget.to.difference(firstMonday).inDays / 7).floor() + 1;

    return LayoutBuilder(
      builder: (context, box) {
        // The square size is worked out from the 53 weeks so the whole year
        // fits; on a narrow window it keeps a readable minimum and scrolls.
        const yearWeeks = 53;
        final fit =
            (box.maxWidth - _labelWidth - _gap * (yearWeeks - 1)) / yearWeeks;
        final cellW = fit.clamp(9.0, 24.0);
        final cellH = cellW;
        final gridWidth = weeks * cellW + (weeks - 1) * _gap;
        // Open on the newest week rather than on the oldest.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });

        final weekStarts = [
          for (var i = 0; i < weeks; i++)
            DateTime(
              firstMonday.year,
              firstMonday.month,
              firstMonday.day + i * 7,
            ),
        ];
        const topHeight = 18.0;

        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: topHeight,
              child: Stack(
                children: [
                  for (final i in _labelledWeeks(weekStarts))
                    Positioned(
                      left: i * (cellW + _gap),
                      child: Text(
                        _months[weekStarts[i].month - 1],
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < weeks; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i == weeks - 1 ? 0 : _gap),
                    child: Column(
                      children: [
                        for (var d = 0; d < 7; d++)
                          _cell(
                            DateTime(
                              weekStarts[i].year,
                              weekStarts[i].month,
                              weekStarts[i].day + d,
                            ),
                            today,
                            byDate,
                            cellW,
                            cellH,
                            d,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelWidth,
              child: Padding(
                padding: EdgeInsets.only(top: topHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final label in _weekdays)
                      Container(
                        height: cellH,
                        margin: const EdgeInsets.only(bottom: _gap),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 9.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: gridWidth, child: grid),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cell(
    DateTime date,
    DateTime today,
    Map<String, DailyStats> byDate,
    double width,
    double height,
    int weekdayIndex,
  ) {
    final blank = Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: _gap),
    );
    // Outside the selected period, or not happened yet: leave blank.
    if (date.isBefore(widget.from) ||
        date.isAfter(widget.to) ||
        date.isAfter(today)) {
      return blank;
    }

    final stat = byDate[_dateKey(date)];
    final level = _HeatLevel.of(stat);
    final isToday = date == today;
    final hasData = level != _HeatLevel.none;
    final label =
        '${_weekdayNames[weekdayIndex]}, ${date.day} ${_months[date.month - 1]}'
        '${date.year == today.year ? '' : ' ${date.year}'}';
    final detail = hasData
        ? '${stat!.breaksCompleted} taken, ${stat.breaksSkipped} skipped'
        : 'no breaks recorded';

    final square = Tooltip(
      message: '$label\n$detail',
      waitDuration: const Duration(milliseconds: 250),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: level.color,
          borderRadius: BorderRadius.circular(height > 20 ? 4 : 2),
          border: isToday
              ? Border.all(color: AppTheme.textPrimary, width: 1.2)
              : null,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: _gap),
      child: square,
    );
  }
}
