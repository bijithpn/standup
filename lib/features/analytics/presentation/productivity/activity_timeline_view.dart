import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// The day laid out end to end.
///
/// Three layers, each answering one question:
///  * a row of facts — when the day started, the longest unbroken stretch of
///    work, how many breaks;
///  * the ribbon — what was open at any moment, against an hour scale, with a
///    "now" marker and honest gaps where nothing was recorded;
///  * hour-by-hour bars — which hours the work actually happened in.
class ActivityTimelineView extends StatefulWidget {
  const ActivityTimelineView({
    super.key,
    required this.entries,
    this.height = 64,
    this.now,
  });

  final List<TimelineEntry> entries;

  /// Height of the ribbon itself (the axis labels sit beneath it).
  final double height;

  /// The current time, for the "now" marker. Defaults to the real clock.
  final DateTime? now;

  @override
  State<ActivityTimelineView> createState() => _ActivityTimelineViewState();
}

class _ActivityTimelineViewState extends State<ActivityTimelineView> {
  TimelineEntry? _hovered;

  DateTime get _now => widget.now ?? DateTime.now();

  bool get _isToday {
    if (widget.entries.isEmpty) return false;
    final first = widget.entries.first.startedAt;
    final now = _now;
    return first.year == now.year &&
        first.month == now.month &&
        first.day == now.day;
  }

  /// The hours the timeline spans, padded out to whole hours so the scale
  /// reads sensibly, and stretched to "now" when looking at today.
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
    // Always show at least three hours, or a short day looks like a glitch.
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
        alignment: Alignment.center,
        decoration: _cardDecoration(),
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
    final byHour = activeSecondsByHour(widget.entries);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: _cardDecoration(),
      child: Column(
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
                      entries: widget.entries,
                      startHour: startHour,
                      endHour: endHour,
                      ribbonHeight: widget.height,
                      gridColor: AppTheme.border,
                      labelColor: AppTheme.textMuted,
                      trackColor: AppTheme.surfaceElevated,
                      nowMarker: _isToday ? _now : null,
                      nowColor: AppTheme.accent,
                      highlighted: _hovered,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _HourBars(byHour: byHour, startHour: startHour, endHour: endHour),
          const SizedBox(height: 12),
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

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppTheme.surfaceCard,
    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    border: Border.all(color: AppTheme.border),
  );

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

/// Seconds of active work in each hour of the day (0–23).
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

/// "Most active around 11am (1h 20m)" — the hour of the day with the most
/// time spent actively working, or null when there is no active time.
String? busiestHourCaption(List<TimelineEntry> entries) {
  final perHour = activeSecondsByHour(entries);
  if (perHour.isEmpty) return null;
  final best = perHour.entries.reduce((a, b) => b.value > a.value ? b : a);
  if (best.value < 60) return null;
  return 'Most active around ${formatHour(best.key)} '
      '(${formatDuration(best.value)})';
}

/// The longest single stretch of work, in seconds (0 when there is none).
int longestFocusSeconds(List<TimelineEntry> entries) {
  var best = 0;
  for (final entry in entries) {
    if (entry.kind == ActivityKind.active && entry.seconds > best) {
      best = entry.seconds;
    }
  }
  return best;
}

// ── Facts ───────────────────────────────────────────────────────────────────

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
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _Fact(
          icon: Icons.wb_twilight_rounded,
          label: 'Started',
          value: formatClock(started),
        ),
        _Fact(
          icon: Icons.schedule_rounded,
          label: 'Latest',
          value: formatClock(latest),
        ),
        if (longest >= 60)
          _Fact(
            icon: Icons.bolt_rounded,
            label: 'Longest focus',
            value: formatDuration(longest),
            highlight: true,
          ),
        if (breaks > 0)
          _Fact(
            icon: Icons.free_breakfast_rounded,
            label: breaks == 1 ? 'Break' : 'Breaks',
            value: '$breaks',
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppTheme.accent : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (highlight ? AppTheme.accent : AppTheme.textMuted).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: AppTheme.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? AppTheme.accent : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hour bars ───────────────────────────────────────────────────────────────

/// One bar per hour, lined up under the ribbon: how much of each hour was
/// spent working. The tallest hour is highlighted and labelled.
class _HourBars extends StatelessWidget {
  const _HourBars({
    required this.byHour,
    required this.startHour,
    required this.endHour,
  });

  final Map<int, int> byHour;
  final int startHour;
  final int endHour;

  static const double _barArea = 40;

  @override
  Widget build(BuildContext context) {
    final hours = endHour - startHour;
    if (hours <= 0) return const SizedBox.shrink();

    var peakHour = -1;
    var peak = 0;
    byHour.forEach((hour, seconds) {
      if (seconds > peak) {
        peak = seconds;
        peakHour = hour;
      }
    });
    // Scale to a full hour, so a few minutes looks like a few minutes rather
    // than being stretched into a tall bar.
    const scale = 3600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Active time per hour',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _barArea + 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (var hour = startHour; hour < endHour; hour++)
                Expanded(
                  child: _HourBar(
                    hour: hour,
                    seconds: byHour[hour] ?? 0,
                    fraction: ((byHour[hour] ?? 0) / scale).clamp(0.0, 1.0),
                    isPeak: hour == peakHour && peak >= 60,
                    barArea: _barArea,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourBar extends StatelessWidget {
  const _HourBar({
    required this.hour,
    required this.seconds,
    required this.fraction,
    required this.isPeak,
    required this.barArea,
  });

  final int hour;
  final int seconds;
  final double fraction;
  final bool isPeak;
  final double barArea;

  @override
  Widget build(BuildContext context) {
    final color = isPeak
        ? AppTheme.accent
        : AppTheme.accent.withValues(alpha: 0.5);
    final height = seconds <= 0 ? 0.0 : math.max(3.0, fraction * barArea);

    return Tooltip(
      message: seconds <= 0
          ? '${formatHour(hour)}: no activity'
          : '${formatHour(hour)}: ${formatDuration(seconds)} active',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            SizedBox(
              height: 14,
              child: isPeak
                  ? FittedBox(
                      child: Text(
                        formatDuration(seconds),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 2),
            Container(
              height: barArea,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Readout and legend ──────────────────────────────────────────────────────

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
        Text(
          'Empty = not recorded',
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

// ── Ribbon ──────────────────────────────────────────────────────────────────

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.entries,
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

  final List<TimelineEntry> entries;
  final int startHour;
  final int endHour;
  final double ribbonHeight;
  final Color gridColor;
  final Color labelColor;
  final Color trackColor;
  final Color nowColor;
  final DateTime? nowMarker;
  final TimelineEntry? highlighted;

  static const double axisHeight = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final span = (endHour - startHour) * 3600;
    if (span <= 0 || ribbonHeight <= 0) return;

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

    // The empty track: anything not covered by a stretch was not recorded.
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, ribbonHeight),
      const Radius.circular(10),
    );
    canvas.drawRRect(track, Paint()..color = trackColor.withValues(alpha: 0.6));

    _paintHourGrid(canvas, size);

    canvas.save();
    canvas.clipRRect(track);
    for (final entry in entries) {
      final left = xFor(entry.startedAt).clamp(0.0, size.width);
      final right = xFor(entry.endedAt).clamp(0.0, size.width);
      // Below a couple of pixels a span would vanish; give it a sliver so a
      // real stretch is never invisible.
      final width = math.max(right - left, 2.5);

      final colour = activityColor(entry.kind, entry.categoryName);
      final isHighlighted = identical(entry, highlighted);
      final isActive = entry.kind == ActivityKind.active;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 3, width, ribbonHeight - 6),
        const Radius.circular(7),
      );

      final base = isActive
          ? colour.withValues(alpha: isHighlighted ? 1.0 : 0.88)
          : colour.withValues(alpha: isHighlighted ? 0.75 : 0.4);
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color.lerp(base, Colors.white, 0.12) ?? base, base],
          ).createShader(rect.outerRect),
      );

      if (isHighlighted) {
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = AppTheme.textPrimary.withValues(alpha: 0.7),
        );
      }

      // Only label a span wide enough to read; anything narrower is explained
      // by the readout beneath instead.
      if (isActive && width > 56) {
        _paintLabel(canvas, entry.appName, left + 8, width - 16);
      } else if (entry.kind == ActivityKind.onBreak && width > 44) {
        _paintLabel(canvas, 'Break', left + 8, width - 16);
      }
    }
    canvas.restore();

    _paintNow(canvas, size, xFor);
  }

  void _paintNow(Canvas canvas, Size size, double Function(DateTime) xFor) {
    final now = nowMarker;
    if (now == null) return;
    final x = xFor(now);
    if (x < 0 || x > size.width) return;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, ribbonHeight),
      Paint()
        ..color = nowColor
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(Offset(x, 0), 3.5, Paint()..color = nowColor);

    final painter = TextPainter(
      text: TextSpan(
        text: 'Now',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: nowColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelX = math.min(x + 4, size.width - painter.width);
    painter.paint(canvas, Offset(math.max(0, labelX), ribbonHeight + 3));
  }

  void _paintHourGrid(Canvas canvas, Size size) {
    final hours = endHour - startHour;
    // Thin the labels out rather than letting them collide on a narrow window.
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
            fontFamily: 'Inter',
            fontSize: 9.5,
            color: labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = math.min(x + 3, size.width - painter.width);
      painter.paint(canvas, Offset(math.max(0, labelX), ribbonHeight + 3));
    }
  }

  void _paintLabel(Canvas canvas, String text, double left, double maxWidth) {
    if (maxWidth <= 8) return;
    final painter = TextPainter(
      text: const TextSpan(
        text: '',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    );
    painter.text = TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
    painter.layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(left, (ribbonHeight - painter.height) / 2));
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.entries != entries ||
      old.startHour != startHour ||
      old.endHour != endHour ||
      old.highlighted != highlighted ||
      old.nowMarker != nowMarker ||
      old.ribbonHeight != ribbonHeight;
}
