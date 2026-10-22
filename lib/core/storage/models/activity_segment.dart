import 'package:objectbox/objectbox.dart';

/// What the user was doing during a stretch of time.
///
/// Stored as an integer so the value survives reordering of the enum.
enum ActivityKind {
  /// Actively using an application.
  active(0),

  /// No input for longer than the idle threshold.
  idle(1),

  /// A BreakMate break was running.
  onBreak(2);

  const ActivityKind(this.storedValue);

  final int storedValue;

  static ActivityKind fromStored(int value) {
    for (final kind in ActivityKind.values) {
      if (kind.storedValue == value) return kind;
    }
    return ActivityKind.active;
  }
}

/// One continuous stretch of time spent in a single state.
///
/// This is the record the previous usage history could not express. Usage was
/// stored as a per-day total per app, which answers "how long was Chrome open
/// today" but nothing about *when* — so a timeline, per-app sessions, and any
/// pattern that depends on time of day were all unreachable. A segment carries
/// its own start and end, so those fall out of the data instead of needing a
/// second collection path.
///
/// Deliberately app-level only: the application's name and category, never the
/// window title or anything from inside it.
@Entity()
class ActivitySegment {
  @Id()
  int id;

  /// Stable per-app identifier — the bundle id on macOS, the executable path
  /// on Windows. Empty for idle and break segments, which belong to no app.
  @Index()
  String appKey;

  /// The app's display name, derived from its executable.
  String appName;

  /// [AppCategory.name] at the time of recording, kept as a string so a
  /// renamed or added category cannot corrupt stored history.
  String categoryName;

  /// Local calendar day, `YYYY-MM-DD`. Indexed because almost every query is
  /// "one day" or "a range of days", and deriving it from [startedAtMs] would
  /// mean scanning.
  @Index()
  String date;

  @Index()
  int startedAtMs;

  int endedAtMs;

  /// [ActivityKind.storedValue].
  int kind;

  ActivitySegment({
    this.id = 0,
    this.appKey = '',
    this.appName = '',
    this.categoryName = '',
    required this.date,
    required this.startedAtMs,
    required this.endedAtMs,
    this.kind = 0,
  });

  DateTime get startedAt => DateTime.fromMillisecondsSinceEpoch(startedAtMs);

  DateTime get endedAt => DateTime.fromMillisecondsSinceEpoch(endedAtMs);

  Duration get duration => Duration(milliseconds: endedAtMs - startedAtMs);

  int get seconds => (endedAtMs - startedAtMs) ~/ 1000;

  ActivityKind get activityKind => ActivityKind.fromStored(kind);

  set activityKind(ActivityKind value) => kind = value.storedValue;

  /// A segment that ended before it started, or spans no time at all, is a
  /// clock adjustment or a bug rather than real usage.
  bool get isValid => endedAtMs > startedAtMs;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'appKey': appKey,
      'appName': appName,
      'categoryName': categoryName,
      'date': date,
      'startedAtMs': startedAtMs,
      'endedAtMs': endedAtMs,
      'kind': kind,
    };
  }

  @override
  String toString() =>
      'ActivitySegment($date ${activityKind.name} '
      '${appName.isEmpty ? '-' : appName} ${seconds}s)';
}
