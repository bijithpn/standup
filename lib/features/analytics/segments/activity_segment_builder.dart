import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

/// Turns a stream of "what is happening right now" observations into closed
/// stretches of time.
///
/// Pure and timer-free on purpose: [AppUsageTracker] already polls, and a
/// second polling service is exactly what the architecture does not need. This
/// only decides where one stretch ends and the next begins, which makes the
/// interesting behaviour — day rollover, sleep gaps, idle — testable without a
/// clock or a database.
///
/// Call [onActive] or [onIdle] once per poll, [onBreakStarted] / [onBreakEnded]
/// around breaks, and [close] when tracking stops. Each call returns any
/// segment that just finished.
class ActivitySegmentBuilder {
  ActivitySegmentBuilder({
    required Duration pollInterval,
    Duration? maxGap,
  })  : _pollInterval = pollInterval,
        // Three missed polls is the point where "the loop is a little late"
        // becomes "something stopped the machine".
        _maxGap = maxGap ?? pollInterval * 3;

  final Duration _pollInterval;
  final Duration _maxGap;

  _OpenSegment? _open;
  DateTime? _lastObservedAt;

  /// The stretch currently being accumulated, if any. For diagnostics.
  ActivityKind? get openKind => _open?.kind;

  /// The user is actively using [appKey].
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

  /// The user has gone idle.
  ActivitySegment? onIdle(DateTime now) {
    return _observe(now: now, kind: ActivityKind.idle);
  }

  /// A break started. Breaks are recorded even while the user is idle, because
  /// stepping away from the machine is the point of a break.
  ActivitySegment? onBreakStarted(DateTime now) {
    return _observe(now: now, kind: ActivityKind.onBreak, force: true);
  }

  /// A break ended. The next [onActive] or [onIdle] opens the following
  /// stretch; this just closes the break.
  ActivitySegment? onBreakEnded(DateTime now) {
    final finished = _closeOpen(now);
    _lastObservedAt = now;
    return finished;
  }

  /// Closes whatever is open, e.g. when tracking is switched off or the app is
  /// shutting down.
  ActivitySegment? close(DateTime now) {
    final finished = _closeOpen(now);
    _open = null;
    _lastObservedAt = null;
    return finished;
  }

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

    // A long silence means the machine slept, the app was suspended, or the
    // clock jumped. Attributing all of it to whatever was open would invent
    // hours of usage, so the stretch is closed at the last moment actually
    // observed and the gap is left untracked.
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

      // A stretch running past midnight is split, so every segment belongs to
      // exactly one calendar day and day queries stay a simple lookup.
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
    // A zero-length stretch is a state that flickered between two polls; it
    // carries no time and only adds noise to the timeline.
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
