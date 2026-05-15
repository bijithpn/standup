import 'package:standup/features/analytics/stats_service.dart';

class StatsModel {
  final int breaksCompleted;
  final int breaksSkipped;
  final int dailyUsageMinutes;
  final String lastActiveDate;
  final int currentStreak;
  final int longestStreak;
  final List<DailyStats> weeklyData;
  final int totalWorkSessions;
  final double averageBreaksPerDay;
  final int productivityScore;

  const StatsModel({
    this.breaksCompleted = 0,
    this.breaksSkipped = 0,
    this.dailyUsageMinutes = 0,
    this.lastActiveDate = '',
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.weeklyData = const [],
    this.totalWorkSessions = 0,
    this.averageBreaksPerDay = 0.0,
    this.productivityScore = 0,
  });

  double get completionRate {
    final total = breaksCompleted + breaksSkipped;
    if (total == 0) return 0;
    return breaksCompleted / total;
  }

  StatsModel copyWith({
    int? breaksCompleted,
    int? breaksSkipped,
    int? dailyUsageMinutes,
    String? lastActiveDate,
    int? currentStreak,
    int? longestStreak,
    List<DailyStats>? weeklyData,
    int? totalWorkSessions,
    double? averageBreaksPerDay,
    int? productivityScore,
  }) {
    return StatsModel(
      breaksCompleted: breaksCompleted ?? this.breaksCompleted,
      breaksSkipped: breaksSkipped ?? this.breaksSkipped,
      dailyUsageMinutes: dailyUsageMinutes ?? this.dailyUsageMinutes,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      weeklyData: weeklyData ?? this.weeklyData,
      totalWorkSessions: totalWorkSessions ?? this.totalWorkSessions,
      averageBreaksPerDay: averageBreaksPerDay ?? this.averageBreaksPerDay,
      productivityScore: productivityScore ?? this.productivityScore,
    );
  }
}
