import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// State machine turning poll observations (active/idle/break) into closed ActivitySegments; a segment ends on state/app change, midnight, or a gap > maxGap.
class ActivitySegmentBuilder {
  ActivitySegmentBuilder({required Duration pollInterval, Duration? maxGap})
    : _pollInterval = pollInterval,

      _maxGap = maxGap ?? pollInterval * 3;

  final Duration _pollInterval;
  final Duration _maxGap;

  _OpenSegment? _open;
  DateTime? _lastObservedAt;

  ActivityKind? get openKind => _open?.kind;

  ActivitySegment? onActive({
    required String appKey,
    required String appName,
    required AppCategory category,
    required DateTime now,
  }) {
    return _observe(
      now: now,
      kind: ActivityKind.active,
      appKey: appKey,
      appName: appName,
      categoryName: category.name,
    );
  }

  ActivitySegment? onIdle(DateTime now) {
    return _observe(now: now, kind: ActivityKind.idle);
  }

  ActivitySegment? onBreakStarted(DateTime now) {
    return _observe(now: now, kind: ActivityKind.onBreak, force: true);
  }

  ActivitySegment? onBreakEnded(DateTime now) {
    final finished = _closeOpen(now);
    _lastObservedAt = now;
    return finished;
  }

  ActivitySegment? close(DateTime now) {
    final finished = _closeOpen(now);
    _open = null;
    _lastObservedAt = null;
    return finished;
  }

  // Gap: close at last seen + one poll (not now) so sleep/pause time isn't counted. Midnight: split at start of day.
  ActivitySegment? _observe({
    required DateTime now,
    required ActivityKind kind,
    String appKey = '',
    String appName = '',
    String categoryName = '',
    bool force = false,
  }) {
    final open = _open;
    final lastObservedAt = _lastObservedAt;
    _lastObservedAt = now;

    if (open != null &&
        lastObservedAt != null &&
        now.difference(lastObservedAt) > _maxGap) {
      final finished = _finish(open, lastObservedAt.add(_pollInterval));
      _open = _OpenSegment(
        kind: kind,
        appKey: appKey,
        appName: appName,
        categoryName: categoryName,
        startedAt: now,
      );
      return finished;
    }

    if (open != null) {
      final sameState = open.kind == kind && open.appKey == appKey;
      final sameDay = _dateKey(open.startedAt) == _dateKey(now);
      if (sameState && sameDay && !force) {
        open.lastSeenAt = now;
        return null;
      }

      final boundary = sameDay ? now : _startOfDay(now);
      final finished = _finish(open, boundary);
      _open = _OpenSegment(
        kind: kind,
        appKey: appKey,
        appName: appName,
        categoryName: categoryName,
        startedAt: boundary,
      )..lastSeenAt = now;
      return finished;
    }

    _open = _OpenSegment(
      kind: kind,
      appKey: appKey,
      appName: appName,
      categoryName: categoryName,
      startedAt: now,
    )..lastSeenAt = now;
    return null;
  }

  ActivitySegment? _closeOpen(DateTime now) {
    final open = _open;
    if (open == null) return null;
    _open = null;
    return _finish(open, now);
  }

  ActivitySegment? _finish(_OpenSegment open, DateTime endedAt) {
    final end = endedAt.isAfter(open.startedAt) ? endedAt : open.startedAt;
    final segment = ActivitySegment(
      appKey: open.appKey,
      appName: open.appName,
      categoryName: open.categoryName,
      date: _dateKey(open.startedAt),
      startedAtMs: open.startedAt.millisecondsSinceEpoch,
      endedAtMs: end.millisecondsSinceEpoch,
      kind: open.kind.storedValue,
    );

    return segment.isValid ? segment : null;
  }

  static DateTime _startOfDay(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  static String _dateKey(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}'
      '-${time.day.toString().padLeft(2, '0')}';
}

class _OpenSegment {
  _OpenSegment({
    required this.kind,
    required this.appKey,
    required this.appName,
    required this.categoryName,
    required this.startedAt,
  });

  final ActivityKind kind;
  final String appKey;
  final String appName;
  final String categoryName;
  final DateTime startedAt;

  late DateTime lastSeenAt = startedAt;
}
