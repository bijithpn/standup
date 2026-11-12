import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Which applications the time went to, and what a single one looks like up
/// close.

class ApplicationUsageList extends StatefulWidget {
  const ApplicationUsageList({
    super.key,
    required this.apps,
    required this.totalActiveSeconds,
    this.limit,
    this.onSelected,
  });

  final List<AppTotal> apps;
  final int totalActiveSeconds;

  /// How many applications get their own slice and row; the rest are folded
  /// into one "Others" slice. Null shows everything.
  final int? limit;

  final ValueChanged<AppTotal>? onSelected;

  @override
  State<ApplicationUsageList> createState() => _ApplicationUsageListState();
}

class _ApplicationUsageListState extends State<ApplicationUsageList> {
  int? _touched;
  final ScrollController _legendScroll = ScrollController();

  @override
  void dispose() {
    _legendScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apps = widget.apps;
    if (apps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          'No application activity recorded',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    final limit = widget.limit;
    final shown = limit == null || limit >= apps.length
        ? apps
        : apps.sublist(0, limit);
    final restSeconds = apps
        .skip(shown.length)
        .fold<int>(0, (sum, a) => sum + a.seconds);
    final total = widget.totalActiveSeconds == 0
        ? apps.fold<int>(0, (sum, a) => sum + a.seconds)
        : widget.totalActiveSeconds;

    final colours = <Color>[
      for (var i = 0; i < shown.length; i++) _sliceColour(shown[i], i),
    ];

    final sections = <PieChartSectionData>[
      for (var i = 0; i < shown.length; i++)
        PieChartSectionData(
          value: shown[i].seconds.toDouble(),
          color: colours[i],
          radius: _touched == i ? 30 : 24,
          showTitle: false,
        ),
      if (restSeconds > 0)
        PieChartSectionData(
          value: restSeconds.toDouble(),
          color: AppTheme.gray600,
          radius: _touched == shown.length ? 30 : 24,
          showTitle: false,
        ),
    ];

    final focused = _touched != null && _touched! < shown.length
        ? shown[_touched!]
        : null;

    // Time per category, for the strip under the header.
    final byCategory = <String, int>{};
    for (final app in apps) {
      byCategory[app.categoryName] =
          (byCategory[app.categoryName] ?? 0) + app.seconds;
    }
    final categories = byCategory.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));

    final chart = SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 72,
              sectionsSpace: 2.5,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final index = response?.touchedSection?.touchedSectionIndex;
                  final next =
                      event.isInterestedForInteractions &&
                          index != null &&
                          index >= 0
                      ? index
                      : null;
                  if (next != _touched) setState(() => _touched = next);
                  if (event is FlTapUpEvent &&
                      next != null &&
                      next < shown.length) {
                    widget.onSelected?.call(shown[next]);
                  }
                },
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 120,
                child: Text(
                  focused?.appName ?? 'Total active',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDuration(focused?.seconds ?? total),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                focused != null
                    ? '${_percent(focused.seconds, total)}% of time'
                    : '${apps.length} ${apps.length == 1 ? 'app' : 'apps'}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Every app is listed, however many there are; the list scrolls inside a
    // fixed height so a long day never stretches the page. Only the chart
    // folds the tail into "Others".
    final legend = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Scrollbar(
        controller: _legendScroll,
        thumbVisibility: apps.length > 5,
        child: ListView.builder(
          controller: _legendScroll,
          shrinkWrap: true,
          itemCount: apps.length,
          itemBuilder: (context, i) {
            final inChart = i < shown.length;
            return _ApplicationRow(
              app: apps[i],
              colour: inChart ? colours[i] : AppTheme.gray600,
              totalActiveSeconds: total,
              highlighted: _touched == i,
              onHover: inChart
                  ? (hovering) => setState(() => _touched = hovering ? i : null)
                  : null,
              onTap: widget.onSelected == null
                  ? null
                  : () => widget.onSelected!(apps[i]),
            );
          },
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth >= 640) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    chart,
                    const SizedBox(width: 24),
                    Expanded(child: legend),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  Center(child: chart),
                  const SizedBox(height: 12),
                  legend,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'By category',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: <Widget>[
                  for (final c in categories)
                    Expanded(
                      flex: c.value <= 0 ? 1 : c.value,
                      child: Container(color: categoryColor(c.key)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: <Widget>[
              for (final c in categories)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: categoryColor(c.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${categoryLabel(c.key)} · ${formatDuration(c.value)} '
                      '(${_percent(c.value, total)}%)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

int _percent(int seconds, int total) =>
    total == 0 ? 0 : (seconds * 100 / total).round();

/// Slices need to be told apart by app, not just by category, so the category
/// colour is shifted in lightness per rank when several apps share one.
Color _sliceColour(AppTotal app, int rank) {
  final hsl = HSLColor.fromColor(categoryColor(app.categoryName));
  final shift = ((rank % 4) - 1.5) * 0.08;
  return hsl.withLightness((hsl.lightness + shift).clamp(0.25, 0.75)).toColor();
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({
    required this.app,
    required this.colour,
    required this.totalActiveSeconds,
    this.highlighted = false,
    this.onHover,
    this.onTap,
  });

  final ValueChanged<bool>? onHover;
  final AppTotal app;
  final Color colour;
  final int totalActiveSeconds;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final detail =
        '${categoryLabel(app.categoryName)} · '
        '${app.sessionCount} ${app.sessionCount == 1 ? 'session' : 'sessions'}'
        ' · avg ${formatDuration(app.averageSessionSeconds)}'
        ' · longest ${formatDuration(app.longestSessionSeconds)}';

    return InkWell(
      onTap: onTap,
      onHover: onHover,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        decoration: BoxDecoration(
          color: highlighted ? colour.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    app.appName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  formatDuration(app.seconds),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_percent(app.seconds, totalActiveSeconds)}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One application, up close: how long, how often, and when.
class ApplicationDetailSheet extends StatelessWidget {
  const ApplicationDetailSheet({
    super.key,
    required this.app,
    required this.totalActiveSeconds,
    required this.segments,
    required this.dateLabel,
    this.historyByDate = const <String, int>{},
  });

  final AppTotal app;
  final int totalActiveSeconds;

  /// This application's stretches on the selected day, oldest first.
  final List<ActivitySegment> segments;

  final String dateLabel;

  /// Seconds per day over the recent past, oldest key first.
  final Map<String, int> historyByDate;

  @override
  Widget build(BuildContext context) {
    final share = totalActiveSeconds == 0
        ? 0.0
        : app.seconds / totalActiveSeconds;

    return Container(
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: categoryColor(app.categoryName),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        app.appName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${categoryLabel(app.categoryName)} · $dateLabel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              shrinkWrap: true,
              children: <Widget>[
                Wrap(
                  spacing: 28,
                  runSpacing: 14,
                  children: <Widget>[
                    _DetailStat(
                      label: 'Time',
                      value: formatDuration(app.seconds),
                    ),
                    _DetailStat(
                      label: 'Share',
                      value: '${(share * 100).round()}%',
                    ),
                    _DetailStat(
                      label: 'Sessions',
                      value: '${app.sessionCount}',
                    ),
                    _DetailStat(
                      label: 'Average',
                      value: formatDuration(app.averageSessionSeconds),
                    ),
                    _DetailStat(
                      label: 'Longest',
                      value: formatDuration(app.longestSessionSeconds),
                    ),
                  ],
                ),
                if (historyByDate.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  _SubHeading('Recent days'),
                  const SizedBox(height: 8),
                  for (final entry in historyByDate.entries)
                    _HistoryRow(
                      label: shortWeekday(entry.key),
                      seconds: entry.value,
                      peakSeconds: historyByDate.values.fold<int>(
                        0,
                        (a, b) => b > a ? b : a,
                      ),
                    ),
                ],
                if (segments.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  _SubHeading('Sessions on this day'),
                  const SizedBox(height: 8),
                  for (final segment in segments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '${formatClock(segment.startedAt)}'
                            '–${formatClock(segment.endedAt)}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatDuration(segment.seconds),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppTheme.textMuted,
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.label,
    required this.seconds,
    required this.peakSeconds,
  });

  final String label;
  final int seconds;
  final int peakSeconds;

  @override
  Widget build(BuildContext context) {
    final fraction = peakSeconds == 0 ? 0.0 : seconds / peakSeconds;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppTheme.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              formatDuration(seconds),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
