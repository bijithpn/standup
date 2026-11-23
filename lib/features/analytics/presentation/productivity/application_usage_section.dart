import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Ranked app list with share bars; tapping an app opens ApplicationDetailSheet via [onSelected].
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

  final int? limit;

  final ValueChanged<AppTotal>? onSelected;

  @override
  State<ApplicationUsageList> createState() => _ApplicationUsageListState();
}

class _ApplicationUsageListState extends State<ApplicationUsageList> {
  int? _touched;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final apps = widget.apps;
    if (apps.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
        alignment: Alignment.centerLeft,
        child: Text(
          'No application activity recorded',
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
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

    final colours = <Color>[for (var i = 0; i < shown.length; i++) appColor(i)];

    final values = <double>[
      for (final app in shown) app.seconds.toDouble(),
      if (restSeconds > 0) restSeconds.toDouble(),
    ];
    final sliceColours = <Color>[
      ...colours,
      if (restSeconds > 0) AppTheme.border,
    ];

    final focused = _touched != null && _touched! < shown.length
        ? shown[_touched!]
        : null;

    final byCategory = <String, int>{};
    for (final app in apps) {
      byCategory[app.categoryName] =
          (byCategory[app.categoryName] ?? 0) + app.seconds;
    }
    final categories = byCategory.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));

    final chart = SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _Donut(
            values: values,
            colours: sliceColours,
            touched: _touched,
            onTouched: (index) {
              if (index != _touched) setState(() => _touched = index);
            },
            onTap: (index) {
              if (index < shown.length) widget.onSelected?.call(shown[index]);
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 96,
                child: Text(
                  focused?.appName ?? 'Active time',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDuration(focused?.seconds ?? total),
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                focused != null
                    ? '${_percent(focused.seconds, total)}% of time'
                    : '${apps.length} ${apps.length == 1 ? 'app' : 'apps'}',
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final visible = _showAll ? apps.length : apps.length.clamp(0, 5);
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < visible; i++)
          _ApplicationRow(
            app: apps[i],
            colour: i < shown.length ? colours[i] : AppTheme.border,
            totalActiveSeconds: total,
            highlighted: _touched == i,
            onHover: i < shown.length
                ? (hovering) => setState(() => _touched = hovering ? i : null)
                : null,
            onTap: widget.onSelected == null
                ? null
                : () => widget.onSelected!(apps[i]),
          ),
        if (apps.length > 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? 'Show less' : 'Show all ${apps.length}'),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: chart),
        const SizedBox(height: AppTheme.space16),
        legend,
        const SizedBox(height: 16),
        Text(
          'By category',
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: <Widget>[
            for (final c in categories)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${categoryLabel(c.key)} · ${formatDuration(c.value)}',
                    style: TextStyle(
                      fontFeatures: AppTheme.tabular,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

int _percent(int seconds, int total) =>
    total == 0 ? 0 : (seconds * 100 / total).round();

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
        '${app.sessionCount} ${app.sessionCount == 1 ? 'session' : 'sessions'}';

    return InkWell(
      onTap: onTap,
      onHover: onHover,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        decoration: BoxDecoration(
          color: highlighted ? colour.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                      fontFeatures: AppTheme.tabular,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFeatures: AppTheme.tabular,
                      fontFamily: 'Inter',
                      fontSize: 12,
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
                    fontFeatures: AppTheme.tabular,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_percent(app.seconds, totalActiveSeconds)}%',
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_right,
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

class ApplicationDetailSheet extends StatelessWidget {
  const ApplicationDetailSheet({
    super.key,
    required this.app,
    required this.totalActiveSeconds,
    required this.segments,
    required this.dateLabel,
    required this.onClose,
    required this.colour,
    this.historyByDate = const <String, int>{},
  });

  final VoidCallback onClose;
  final Color colour;
  final AppTotal app;
  final int totalActiveSeconds;

  final List<ActivitySegment> segments;

  final String dateLabel;

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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusMd),
        ),
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 24, 32, 0),
            child: Row(
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colour,
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
                          fontFeatures: AppTheme.tabular,
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${categoryLabel(app.categoryName)} · $dateLabel',
                        style: TextStyle(
                          fontFeatures: AppTheme.tabular,
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(CupertinoIcons.xmark, size: 18),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(40, 20, 40, 32),
              shrinkWrap: true,
              children: <Widget>[
                Wrap(
                  spacing: 48,
                  runSpacing: 16,
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
                  _SubHeading('Today by hour'),
                  const SizedBox(height: 10),
                  _HourlyChart(segments: segments, colour: colour),
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
      text,
      style: TextStyle(
        fontFeatures: AppTheme.tabular,
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.textSecondary,
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
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
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
                fontFeatures: AppTheme.tabular,
                fontFamily: 'Inter',
                fontSize: 12,
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
                fontFeatures: AppTheme.tabular,
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seconds of [segments] per clock hour, splitting segments that cross an hour boundary.
List<int> _secondsByHour(List<ActivitySegment> segments) {
  final hours = List<int>.filled(24, 0);
  for (final segment in segments) {
    var cursor = segment.startedAt;
    final end = segment.endedAt;
    while (cursor.isBefore(end)) {
      final next = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour + 1,
      );
      final stop = next.isBefore(end) ? next : end;
      hours[cursor.hour] += stop.difference(cursor).inSeconds;
      cursor = stop;
    }
  }
  return hours;
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.segments, required this.colour});

  final List<ActivitySegment> segments;
  final Color colour;

  static const double _barAreaHeight = 96;

  @override
  Widget build(BuildContext context) {
    final byHour = _secondsByHour(segments);
    final used = <int>[
      for (var h = 0; h < 24; h++)
        if (byHour[h] > 0) h,
    ];
    if (used.isEmpty) return const SizedBox.shrink();

    var first = used.first;
    var last = used.last;
    while (last - first < 5) {
      if (first > 0) first--;
      if (last - first < 5 && last < 23) last++;
      if (first == 0 && last == 23) break;
    }
    final peak = byHour.reduce((a, b) => a > b ? a : b);
    final label = TextStyle(
      fontFeatures: AppTheme.tabular,
      fontFamily: 'Inter',
      fontSize: 11,
      color: AppTheme.textMuted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: _barAreaHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var h = first; h <= last; h++)
                Expanded(
                  child: Tooltip(
                    message: '${formatHour(h)} · ${formatDuration(byHour[h])}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: byHour[h] == 0
                              ? 3
                              : math.max(
                                  6.0,
                                  _barAreaHeight * byHour[h] / peak,
                                ),
                          decoration: BoxDecoration(
                            color: byHour[h] == 0
                                ? AppTheme.borderSubtle
                                : colour,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text(formatHour(first), style: label),
            const Spacer(),
            Text('Busiest ${formatDuration(peak)}', style: label),
            const Spacer(),
            Text(formatHour(last), style: label),
          ],
        ),
      ],
    );
  }
}

/// Ring chart drawn with stroked arcs: anti-aliased edges, small gaps between slices, the hovered slice thickens.
class _Donut extends StatelessWidget {
  const _Donut({
    required this.values,
    required this.colours,
    required this.touched,
    required this.onTouched,
    required this.onTap,
  });

  final List<double> values;
  final List<Color> colours;
  final int? touched;
  final ValueChanged<int?> onTouched;
  final ValueChanged<int> onTap;

  static const double _thickness = 22;
  static const double _hoverExtra = 6;

  int? _hit(Offset position, Size size) {
    final centre = size.center(Offset.zero);
    final delta = position - centre;
    final radius = delta.distance;
    final outer = size.shortestSide / 2;
    if (radius > outer || radius < outer - _thickness - _hoverExtra * 2) {
      return null;
    }
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    var start = 0.0;
    for (var i = 0; i < values.length; i++) {
      start += values[i] / total * math.pi * 2;
      if (angle <= start) return i;
    }
    return values.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return MouseRegion(
          onHover: (e) => onTouched(_hit(e.localPosition, size)),
          onExit: (_) => onTouched(null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final index = _hit(d.localPosition, size);
              if (index != null) onTap(index);
            },
            child: CustomPaint(
              size: size,
              painter: _DonutPainter(values, colours, touched),
            ),
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colours, this.touched);

  final List<double> values;
  final List<Color> colours;
  final int? touched;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final outer = size.shortestSide / 2;
    final gap = values.length > 1 ? 0.045 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final thickness =
          _Donut._thickness + (touched == i ? _Donut._hoverExtra : 0);
      final rect = Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: outer - _Donut._hoverExtra - _Donut._thickness / 2,
      );
      final visible = math.max(0.0, sweep - gap);
      canvas.drawArc(
        rect,
        start + gap / 2,
        visible,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt
          ..isAntiAlias = true
          ..color = colours[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.touched != touched ||
      !listEquals(old.values, values) ||
      !listEquals(old.colours, colours);
}
