import 'package:objectbox/objectbox.dart';

/// Per-day break and usage counters, keyed by unique "date" string.
@Entity()
class DailyStats {
  @Id()
  int id;

  @Unique()
  String date;

  int breaksCompleted;
  int breaksSkipped;
  int usageMinutes;
  int wellnessActions;

  DailyStats({
    this.id = 0,
    required this.date,
    this.breaksCompleted = 0,
    this.breaksSkipped = 0,
    this.usageMinutes = 0,
    this.wellnessActions = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'breaksCompleted': breaksCompleted,
      'breaksSkipped': breaksSkipped,
      'usageMinutes': usageMinutes,
      'wellnessActions': wellnessActions,
    };
  }
}

/// Single-row lifetime stats (streaks and session totals).
@Entity()
class GlobalStats {
  @Id(assignable: true)
  int id;

  int currentStreak;
  int longestStreak;
  int totalWorkSessions;
  String lastActiveDate;

  GlobalStats({
    this.id = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalWorkSessions = 0,
    this.lastActiveDate = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalWorkSessions': totalWorkSessions,
      'lastActiveDate': lastActiveDate,
    };
  }
}
