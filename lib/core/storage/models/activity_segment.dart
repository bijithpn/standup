import 'package:objectbox/objectbox.dart';

/// Persisted as an int ([storedValue]); do not reorder or reuse values.
enum ActivityKind {
  active(0),

  idle(1),

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

/// One contiguous span of foreground-app activity (or idle/break time) for the activity timeline.
@Entity()
class ActivitySegment {
  @Id()
  int id;

  @Index()
  String appKey;

  String appName;

  String categoryName;

  @Index()
  String date;

  @Index()
  int startedAtMs;

  int endedAtMs;

  // Raw stored [ActivityKind]; use [activityKind] to read/write.
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

  // Zero/negative-length spans come from clock jumps and should be discarded.
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
