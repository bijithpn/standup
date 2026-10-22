import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// The day laid out end to end.
///
/// The one view that answers "what was I actually doing at half past ten"
/// rather than "how long was this open in total". Drawn rather than charted:
/// the shape wanted here is a ribbon of labelled spans against an hour scale,
/// which no bar or line chart expresses naturally.
class ActivityTimelineView extends StatefulWidget {
  const ActivityTimelineView({
    super.key,
    required this.entries,
    this.height = 132,
  });

  final List<TimelineEntry> entries;
  final double height;

  @override
  State<ActivityTimelineView> createState() => _ActivityTimelineViewState();
}

class _ActivityTimelineViewState extends State<ActivityTimelineView> {
  TimelineEntry? _hovered;

  /// The hours the timeline spans, padded out to whole hours so the scale
  /// reads sensibly.
  (int, int) get _bounds {
    if (widget.entries.isEmpty) return (9, 18);

    var first = 23;
    var last = 0;
    for (final entry in widget.entries) {
      first = math.min(first, entry.startedAt.hour);
      // A stretch ending at 17:40 still occupies the 17:00 hour.
      last = math.max(last, entry.endedAt.hour);
      if (entry.endedAt.minute > 0 || entry.endedAt.second > 0) {
        last = math.max(last, entry.endedAt.hour + 1);
      }
    }
    // Always show at least four hours, or a short day looks like a glitch.
    if (last - first < 4) last = math.min(24, first + 4);
    return (first, math.min(24, last));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          'No activity recorded for this day',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    final (startHour, endHour) = _bounds;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (event) => _updateHover(
                    event.localPosition,
                    constraints.maxWidth,
                    startHour,
                    endHour,
                  ),
                  onExit: (_) => setState(() => _hovered = null),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, widget.height),
                    painter: _TimelinePainter(
                      entries: widget.entries,
                      startHour: startHour,
                      endHour: endHour,
                      gridColor: AppTheme.border,
                      labelColor: AppTheme.textMuted,
                      highlighted: _hovered,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const _TimelineLegend(),
          const SizedBox(height: 8),
          _Readout(
            entry: _hovered,
            idleHint: busiestHourCaption(widget.entries),
          ),
        ],
      ),
    );
  }

  void _updateHover(Offset position, double width, int startHour, int endHour) {
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

    TimelineEntry? found;
    for (final entry in widget.entries) {
      if (!moment.isBefore(entry.startedAt) && moment.isBefore(entry.endedAt)) {
        found = entry;
        break;
      }
    }
    if (found != _hovered) setState(() => _hovered = found);
  }
}

/// What the pointer is over, or the day's shape when it is over nothing.
class _Readout extends StatelessWidget {
  const _Readout({this.entry, this.idleHint});

  final TimelineEntry? entry;

  /// Shown when the pointer is not over a stretch of the day.
  final String? idleHint;

  @override
  Widget build(BuildContext context) {
    final current = entry;
    if (current == null) {
      return Text(
        idleHint == null
            ? 'Hover the timeline for detail'
            : '$idleHint · hover the timeline for detail',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: AppTheme.textMuted,
        ),
      );
    }

    final colour = activityColor(current.kind, current.categoryName);
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatClock(current.startedAt)}–${formatClock(current.endedAt)}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            current.kind == ActivityKind.active
                ? current.appName
                : activityLabel(current.kind),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatDuration(current.seconds),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.entries,
    required this.startHour,
    required this.endHour,
    required this.gridColor,
    required this.labelColor,
    this.highlighted,
  });

  final List<TimelineEntry> entries;
  final int startHour;
  final int endHour;
  final Color gridColor;
  final Color labelColor;
  final TimelineEntry? highlighted;

  static const double _axisHeight = 18;
  static const double _ribbonGap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final span = (endHour - startHour) * 3600;
    if (span <= 0) return;

    final ribbonHeight = size.height - _axisHeight - _ribbonGap;
    if (ribbonHeight <= 0) return;

    final dayStart = DateTime(
      entries.first.startedAt.year,
      entries.first.startedAt.month,
      entries.first.startedAt.day,
      startHour,
    );

    double xFor(DateTime time) {
      final seconds = time.difference(dayStart).inSeconds;
      return (seconds / span) * size.width;
    }

    _paintHourGrid(canvas, size, ribbonHeight);

    final radius = Radius.circular(ribbonHeight * 0.18);
    for (final entry in entries) {
      final left = xFor(entry.startedAt).clamp(0.0, size.width);
      final right = xFor(entry.endedAt).clamp(0.0, size.width);
      // Below a pixel a span would vanish; give it a sliver so a real switch
      // is never invisible.
      final width = math.max(right - left, 1.5);

      final colour = activityColor(entry.kind, entry.categoryName);
      final isHighlighted = identical(entry, highlighted);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, ribbonHeight),
        radius,
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = entry.kind == ActivityKind.active
              ? colour.withValues(alpha: isHighlighted ? 1.0 : 0.82)
              : colour.withValues(alpha: isHighlighted ? 0.8 : 0.45),
      );

      if (isHighlighted) {
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppTheme.textPrimary.withValues(alpha: 0.6),
        );
      }

      // Only label a span wide enough to read; anything narrower is explained
      // by the readout beneath instead.
      if (width > 52 && entry.kind == ActivityKind.active) {
        _paintLabel(canvas, entry.appName, left + 6, width - 12, ribbonHeight);
      }
    }
  }

  void _paintHourGrid(Canvas canvas, Size size, double ribbonHeight) {
    final hours = endHour - startHour;
    // Thin the labels out rather than letting them collide on a narrow window.
    final step = size.width / hours < 48 ? math.max(1, (hours / 6).round()) : 1;

    final line = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var offset = 0; offset <= hours; offset += step) {
      final x = (offset / hours) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, ribbonHeight + _ribbonGap * 0.5),
        line,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: formatHour(startHour + offset),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            color: labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = math.min(x + 3, size.width - painter.width);
      painter.paint(
        canvas,
        Offset(math.max(0, labelX), ribbonHeight + _ribbonGap),
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    double x,
    double maxWidth,
    double ribbonHeight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, Offset(x, (ribbonHeight - painter.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.startHour != startHour ||
        oldDelegate.endHour != endHour ||
        !identical(oldDelegate.highlighted, highlighted);
  }
}

/// "Most active around 11am (1h 20m)" — the hour of the day with the most
/// time spent actively working, or null when there is no active time.
String? busiestHourCaption(List<TimelineEntry> entries) {
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
  if (perHour.isEmpty) return null;
  final best = perHour.entries.reduce((a, b) => b.value > a.value ? b : a);
  if (best.value < 60) return null;
  return 'Most active around ${formatHour(best.key)} '
      '(${formatDuration(best.value)})';
}

class _TimelineLegend extends StatelessWidget {
  const _TimelineLegend();

  @override
  Widget build(BuildContext context) {
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

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: <Widget>[
        dot(activityColor(ActivityKind.active, 'coding'), 'Working in an app'),
        dot(activityColor(ActivityKind.onBreak, ''), 'On a break'),
        dot(activityColor(ActivityKind.idle, ''), 'Away'),
      ],
    );
  }
}
