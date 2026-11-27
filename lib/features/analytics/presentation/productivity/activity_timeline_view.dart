import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Day timeline in split 15-minute columns with hover readout and key facts.
class ActivityTimelineView extends StatefulWidget {
  const ActivityTimelineView({
    super.key,
    required this.entries,
    this.height = 120,
    this.now,
    this.appKeys = const <String>[],
  });

  final List<TimelineEntry> entries;

  final double height;

  final DateTime? now;

  /// Most used first, so blocks match the colours of the application list.
  final List<String> appKeys;

  @override
  State<ActivityTimelineView> createState() => _ActivityTimelineViewState();
}

class _ActivityTimelineViewState extends State<ActivityTimelineView> {
  DateTime? _hovered;

  DateTime get _now => widget.now ?? DateTime.now();

  bool get _isToday {
    if (widget.entries.isEmpty) return false;
    final first = widget.entries.first.startedAt;
    final now = _now;
    return first.year == now.year &&
        first.month == now.month &&
        first.day == now.day;
  }

  (int, int) get _bounds {
    if (widget.entries.isEmpty) return (9, 18);

    var first = 23;
    var last = 0;
    for (final entry in widget.entries) {
      first = math.min(first, entry.startedAt.hour);
      last = math.max(last, entry.endedAt.hour);
      if (entry.endedAt.minute > 0 || entry.endedAt.second > 0) {
        last = math.max(last, entry.endedAt.hour + 1);
      }
    }
    if (_isToday) {
      final now = _now;
      last = math.max(last, now.minute > 0 ? now.hour + 1 : now.hour);
    }

    if (last - first < 3) last = first + 3;
    if (last > 24) {
      first = math.max(0, first - (last - 24));
      last = 24;
    }
    return (first, last);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.centerLeft,
        child: Text(
          'No activity recorded for this day',
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    final (startHour, endHour) = _bounds;
    final blocks = timelineBlocks(widget.entries);
    final hovered = blocks.where((b) => b.start == _hovered).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FactsRow(entries: widget.entries),
        const SizedBox(height: 16),
        SizedBox(
          height: widget.height + _TimelinePainter.axisHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                onHover: (event) => _updateHover(
                  blocks,
                  event.localPosition,
                  constraints.maxWidth,
                  startHour,
                  endHour,
                ),
                onExit: (_) => setState(() => _hovered = null),
                child: CustomPaint(
                  size: Size(
                    constraints.maxWidth,
                    widget.height + _TimelinePainter.axisHeight,
                  ),
                  painter: _TimelinePainter(
                    blocks: blocks,
                    appKeys: widget.appKeys,
                    startHour: startHour,
                    endHour: endHour,
                    ribbonHeight: widget.height,
                    gridColor: AppTheme.border,
                    labelColor: AppTheme.textMuted,
                    trackColor: AppTheme.surfaceElevated,
                    nowMarker: _isToday ? _now : null,
                    nowColor: AppTheme.accent,
                    highlighted: hovered,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _TimelineLegend(blocks: blocks, appKeys: widget.appKeys),
        const SizedBox(height: 8),
        _Readout(
          block: hovered,
          appKeys: widget.appKeys,
          idleHint: busiestHourCaption(widget.entries),
        ),
      ],
    );
  }

  void _updateHover(
    List<TimelineBlock> blocks,
    Offset position,
    double width,
    int startHour,
    int endHour,
  ) {
    final span = (endHour - startHour) * 3600;
    if (span <= 0 || width <= 0) return;

    final secondsFromStart = (position.dx / width) * span;
    final at = widget.entries.first.startedAt;
    final moment = DateTime(
      at.year,
      at.month,
      at.day,
      startHour,
    ).add(Duration(seconds: secondsFromStart.round()));

    final found = blocks
        .where(
          (b) =>
              !moment.isBefore(b.start) &&
              moment.isBefore(b.start.add(_blockLength)),
        )
        .firstOrNull
        ?.start;
    if (found != _hovered) setState(() => _hovered = found);
  }
}

typedef TimelinePart = ({
  ActivityKind kind,
  String appKey,
  String appName,
  int seconds,
});

/// One column of the timeline; [parts] are largest first.
typedef TimelineBlock = ({DateTime start, List<TimelinePart> parts});

const Duration _blockLength = Duration(minutes: 15);
const double _minSlice = 4;

List<TimelineBlock> timelineBlocks(List<TimelineEntry> entries) {
  final buckets = <DateTime, Map<(ActivityKind, String), TimelinePart>>{};
  for (final entry in entries) {
    var cursor = entry.startedAt;
    while (cursor.isBefore(entry.endedAt)) {
      final bucket = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
        cursor.minute - cursor.minute % _blockLength.inMinutes,
      );
      final next = bucket.add(_blockLength);
      final end = next.isBefore(entry.endedAt) ? next : entry.endedAt;
      final parts = buckets[bucket] ??= {};
      final key = (entry.kind, entry.appKey);
      parts[key] = (
        kind: entry.kind,
        appKey: entry.appKey,
        appName: entry.appName,
        seconds: (parts[key]?.seconds ?? 0) + end.difference(cursor).inSeconds,
      );
      cursor = end;
    }
  }

  return <TimelineBlock>[
    for (final MapEntry(key: start, value: parts) in buckets.entries)
      (
        start: start,
        parts: parts.values.toList()
          ..sort((a, b) => b.seconds.compareTo(a.seconds)),
      ),
  ];
}

/// Slice heights as a share of the block, with a floor so that a break of a few
/// seconds stays visible.
List<double> timelineSliceHeights(List<int> seconds, double height) {
  final raw = <double>[
    for (final value in seconds)
      math.max(_minSlice, value / _blockLength.inSeconds * height),
  ];
  final total = raw.fold<double>(0, (a, b) => a + b);
  if (total <= height) return raw;
  return <double>[for (final value in raw) value * height / total];
}

/// Position in the application list; unlisted apps go last.
int _rank(TimelinePart part, List<String> appKeys) {
  final index = appKeys.indexOf(part.appKey);
  return index < 0 ? appKeys.length : index;
}

Color _partColor(TimelinePart part, List<String> appKeys) {
  switch (part.kind) {
    case ActivityKind.active:
      final rank = appKeys.indexOf(part.appKey);
      return rank < 0 ? AppTheme.gray500 : appColor(rank);
    // Neutral, because green already belongs to an application.
    case ActivityKind.onBreak:
      return AppTheme.textSecondary;
    case ActivityKind.idle:
      return AppTheme.gray700;
  }
}

String _partLabel(TimelinePart part) => switch (part.kind) {
  ActivityKind.active => part.appName,
  ActivityKind.onBreak => 'Break',
  ActivityKind.idle => 'Away',
};

Map<int, int> activeSecondsByHour(List<TimelineEntry> entries) {
  final perHour = <int, int>{};
  for (final entry in entries) {
    if (entry.kind != ActivityKind.active) continue;
    var cursor = entry.startedAt;
    while (cursor.isBefore(entry.endedAt)) {
      final hourEnd = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
      ).add(const Duration(hours: 1));
      final sliceEnd = hourEnd.isBefore(entry.endedAt)
          ? hourEnd
          : entry.endedAt;
      perHour[cursor.hour] =
          (perHour[cursor.hour] ?? 0) + sliceEnd.difference(cursor).inSeconds;
      cursor = sliceEnd;
    }
  }
  return perHour;
}

String? busiestHourCaption(List<TimelineEntry> entries) {
  final perHour = activeSecondsByHour(entries);
  if (perHour.isEmpty) return null;
  final best = perHour.entries.reduce((a, b) => b.value > a.value ? b : a);
  if (best.value < 60) return null;
  return 'Most active around ${formatHour(best.key)} '
      '(${formatDuration(best.value)})';
}

int longestFocusSeconds(List<TimelineEntry> entries) {
  var best = 0;
  for (final entry in entries) {
    if (entry.kind == ActivityKind.active && entry.seconds > best) {
      best = entry.seconds;
    }
  }
  return best;
}

class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.entries});

  final List<TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final started = entries.first.startedAt;
    final latest = entries.last.endedAt;
    final longest = longestFocusSeconds(entries);
    final breaks = entries.where((e) => e.kind == ActivityKind.onBreak).length;

    return Wrap(
      spacing: AppTheme.space24,
      runSpacing: AppTheme.space8,
      children: <Widget>[
        _Fact(label: 'Started', value: formatClock(started)),
        _Fact(label: 'Latest', value: formatClock(latest)),
        if (longest >= 60)
          _Fact(label: 'Longest focus', value: formatDuration(longest)),
        if (breaks > 0)
          _Fact(label: breaks == 1 ? 'Break' : 'Breaks', value: '$breaks'),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      style: TextStyle(
        fontFeatures: AppTheme.tabular,
        fontFamily: 'Inter',
        fontSize: 12,
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({this.block, required this.appKeys, this.idleHint});

  final TimelineBlock? block;
  final List<String> appKeys;
  final String? idleHint;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFeatures: AppTheme.tabular,
      fontFamily: 'Inter',
      fontSize: 12,
      color: AppTheme.textMuted,
    );
    final current = block;
    if (current == null) {
      return Text(
        idleHint == null
            ? 'Hover a column for detail'
            : '$idleHint · hover a column for detail',
        style: style,
      );
    }

    // Breaks lead, so truncation never hides them.
    final parts = <TimelinePart>[
      ...current.parts.where((p) => p.kind == ActivityKind.onBreak),
      ...current.parts.where((p) => p.kind != ActivityKind.onBreak),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${formatClock(current.start)}–'
          '${formatClock(current.start.add(_blockLength))}',
          style: style.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            <String>[
              for (final part in parts)
                '${_partLabel(part)} ${formatDuration(part.seconds)}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _TimelineLegend extends StatelessWidget {
  const _TimelineLegend({required this.blocks, required this.appKeys});

  final List<TimelineBlock> blocks;
  final List<String> appKeys;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFeatures: AppTheme.tabular,
      fontFamily: 'Inter',
      fontSize: 12,
      color: AppTheme.textMuted,
    );
    Widget dot(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: style),
      ],
    );

    final apps =
        <String, TimelinePart>{
            for (final block in blocks)
              for (final part in block.parts)
                if (part.kind == ActivityKind.active) part.appKey: part,
          }.values.toList()
          ..sort((a, b) => _rank(a, appKeys).compareTo(_rank(b, appKeys)));

    Color fixed(ActivityKind kind) =>
        _partColor((kind: kind, appKey: '', appName: '', seconds: 0), appKeys);

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: <Widget>[
        for (final app in apps) dot(_partColor(app, appKeys), app.appName),
        dot(fixed(ActivityKind.onBreak), 'On a break'),
        dot(fixed(ActivityKind.idle), 'Away'),
        Text('Each column is 15 minutes', style: style),
        Text('Empty = not recorded', style: style),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.blocks,
    required this.appKeys,
    required this.startHour,
    required this.endHour,
    required this.ribbonHeight,
    required this.gridColor,
    required this.labelColor,
    required this.trackColor,
    required this.nowColor,
    this.nowMarker,
    this.highlighted,
  });

  final List<TimelineBlock> blocks;
  final List<String> appKeys;
  final int startHour;
  final int endHour;
  final double ribbonHeight;
  final Color gridColor;
  final Color labelColor;
  final Color trackColor;
  final Color nowColor;
  final DateTime? nowMarker;
  final TimelineBlock? highlighted;

  static const double axisHeight = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final span = (endHour - startHour) * 3600;
    if (span <= 0 || ribbonHeight <= 0) return;

    final dayStart = DateTime(
      blocks.first.start.year,
      blocks.first.start.month,
      blocks.first.start.day,
      startHour,
    );

    double xFor(DateTime time) {
      final seconds = time.difference(dayStart).inSeconds;
      return (seconds / span) * size.width;
    }

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, ribbonHeight),
      const Radius.circular(AppTheme.radiusSm),
    );
    canvas.drawRRect(track, Paint()..color = trackColor.withValues(alpha: 0.6));

    _paintHourGrid(canvas, size, _nowLabelRect(size, xFor));

    canvas.save();
    canvas.clipRRect(track);
    Rect columnFor(TimelineBlock block) {
      final left = xFor(block.start);
      final right = xFor(block.start.add(_blockLength));
      return Rect.fromLTRB(left + 1, 3, right - 1, ribbonHeight - 3);
    }

    // Bottom to top: apps in list order, then breaks, then away.
    const kinds = <ActivityKind>[
      ActivityKind.active,
      ActivityKind.onBreak,
      ActivityKind.idle,
    ];
    for (final block in blocks) {
      final column = columnFor(block);
      final parts = block.parts.toList()
        ..sort((a, b) {
          final kind = kinds.indexOf(a.kind).compareTo(kinds.indexOf(b.kind));
          return kind != 0
              ? kind
              : _rank(a, appKeys).compareTo(_rank(b, appKeys));
        });
      final heights = timelineSliceHeights([
        for (final part in parts) part.seconds,
      ], column.height);

      var bottom = column.bottom;
      for (var i = 0; i < parts.length; i++) {
        final top = bottom - heights[i];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(column.left, top + 1, column.right, bottom),
            const Radius.circular(2),
          ),
          Paint()
            ..color = _partColor(
              parts[i],
              appKeys,
            ).withValues(alpha: parts[i].kind == ActivityKind.idle ? 0.6 : 0.9),
        );
        bottom = top;
      }
    }

    final hovered = highlighted;
    if (hovered != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(columnFor(hovered), const Radius.circular(2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppTheme.textPrimary.withValues(alpha: 0.8),
      );
    }
    canvas.restore();

    _paintNow(canvas, size, xFor);
  }

  TextPainter _nowLabel() => TextPainter(
    text: TextSpan(
      text: 'Now',
      style: TextStyle(
        fontFeatures: AppTheme.tabular,
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: nowColor,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  Rect? _nowLabelRect(Size size, double Function(DateTime) xFor) {
    final now = nowMarker;
    if (now == null) return null;
    final x = xFor(now);
    if (x < 0 || x > size.width) return null;
    final painter = _nowLabel();
    final labelX = math.max(0.0, math.min(x + 4, size.width - painter.width));
    return Rect.fromLTWH(
      labelX,
      ribbonHeight + 3,
      painter.width,
      painter.height,
    );
  }

  void _paintNow(Canvas canvas, Size size, double Function(DateTime) xFor) {
    final label = _nowLabelRect(size, xFor);
    if (label == null) return;
    final x = xFor(nowMarker!);

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, ribbonHeight),
      Paint()
        ..color = nowColor
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(Offset(x, 0), 3.5, Paint()..color = nowColor);
    _nowLabel().paint(canvas, label.topLeft);
  }

  void _paintHourGrid(Canvas canvas, Size size, Rect? avoid) {
    final hours = endHour - startHour;

    final step = size.width / hours < 48 ? math.max(1, (hours / 6).round()) : 1;

    final line = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    for (var offset = 0; offset <= hours; offset += step) {
      final x = (offset / hours) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, ribbonHeight), line);

      final painter = TextPainter(
        text: TextSpan(
          text: formatHour(startHour + offset),
          style: TextStyle(
            fontFeatures: AppTheme.tabular,
            fontFamily: 'Inter',
            fontSize: 12,
            color: labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = math.max(0.0, math.min(x + 3, size.width - painter.width));
      final rect = Rect.fromLTWH(
        labelX,
        ribbonHeight + 3,
        painter.width,
        painter.height,
      );
      if (avoid != null && rect.inflate(2).overlaps(avoid)) continue;
      painter.paint(canvas, rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => true;
}
