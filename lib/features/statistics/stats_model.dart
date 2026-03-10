class StatsModel {
  final int breaksCompleted;
  final int breaksSkipped;
  final int dailyUsageMinutes;
  final String lastActiveDate;

  const StatsModel({
    this.breaksCompleted = 0,
    this.breaksSkipped = 0,
    this.dailyUsageMinutes = 0,
    this.lastActiveDate = '',
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
  }) {
    return StatsModel(
      breaksCompleted: breaksCompleted ?? this.breaksCompleted,
      breaksSkipped: breaksSkipped ?? this.breaksSkipped,
      dailyUsageMinutes: dailyUsageMinutes ?? this.dailyUsageMinutes,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }
}
