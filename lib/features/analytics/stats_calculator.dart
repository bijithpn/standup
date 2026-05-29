import 'dart:convert';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';

class StatsCalculator {
  static StatsCalculationResult calculateStats(Map<String, dynamic> params) {
    final weeklyDataJsonString = params['weeklyDataJsonString'] as String;
    final breaksCompleted = params['breaksCompleted'] as int;
    final breaksSkipped = params['breaksSkipped'] as int;
    final dailyUsageMinutes = params['dailyUsageMinutes'] as int;
    final lastActiveDate = params['lastActiveDate'] as String;
    final currentStreak = params['currentStreak'] as int;
    final longestStreak = params['longestStreak'] as int;
    final totalWorkSessions = params['totalWorkSessions'] as int;

    List<DailyStats> weeklyData = [];
    if (weeklyDataJsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonData = jsonDecode(weeklyDataJsonString);
        weeklyData = jsonData.map((e) => DailyStats.fromJson(e)).toList();
      } catch (_) {}
    }

    // 1. Average breaks per day
    double averageBreaksPerDay = 0.0;
    if (weeklyData.isNotEmpty) {
      final total = weeklyData.fold<int>(
        0,
        (sum, day) => sum + day.breaksCompleted,
      );
      averageBreaksPerDay = total / weeklyData.length;
    }

    final totalBreaks = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.breaksCompleted,
    );
    final totalUsage = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.usageMinutes,
    );
    final totalSkipped = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.breaksSkipped,
    );

    final avgBreaksPerDay = weeklyData.isNotEmpty
        ? totalBreaks / weeklyData.length
        : 0.0;
    final avgUsagePerDay = weeklyData.isNotEmpty
        ? totalUsage / weeklyData.length
        : 0.0;

    final completionRate = totalBreaks + totalSkipped > 0
        ? totalBreaks / (totalBreaks + totalSkipped)
        : 0.0;

    // 2. Productivity score
    int productivityScore = 0;
    productivityScore += (completionRate * 50).round();

    if (avgBreaksPerDay >= 5 && avgBreaksPerDay <= 7) {
      productivityScore += 30;
    } else if (avgBreaksPerDay >= 3 && avgBreaksPerDay < 5) {
      productivityScore += 20;
    } else if (avgBreaksPerDay >= 1 && avgBreaksPerDay < 3) {
      productivityScore += 10;
    }

    if (currentStreak >= 7) {
      productivityScore += 20;
    } else if (currentStreak >= 3) {
      productivityScore += 10;
    }
    productivityScore = productivityScore.clamp(0, 100);

    // 3. Wellness actions & score
    final totalWellnessActions = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.wellnessActions,
    );

    int wellnessScore = 0;
    if (weeklyData.isNotEmpty) {
      final avgActions = totalWellnessActions / weeklyData.length;
      wellnessScore += ((avgActions / 10).clamp(0.0, 1.0) * 70).round();
      wellnessScore += (completionRate * 30).round();
    }
    wellnessScore = wellnessScore.clamp(0, 100);

    // 4. Productivity insight message
    String insight = 'Keep up the good work!';
    if (avgBreaksPerDay < 3) {
      insight = 'Try to take more breaks for better productivity.';
    } else if (avgBreaksPerDay > 8) {
      insight = 'Great break habits! Consider longer focus sessions.';
    }

    if (totalSkipped > totalBreaks * 0.3) {
      insight = 'Consider adjusting break intervals to reduce skipping.';
    }

    final stats = StatsModel(
      breaksCompleted: breaksCompleted,
      breaksSkipped: breaksSkipped,
      dailyUsageMinutes: dailyUsageMinutes,
      lastActiveDate: lastActiveDate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      weeklyData: weeklyData,
      totalWorkSessions: totalWorkSessions,
      averageBreaksPerDay: averageBreaksPerDay,
      productivityScore: productivityScore,
      wellnessScore: wellnessScore,
      totalWellnessActions: totalWellnessActions,
    );

    final insights = ProductivityInsights(
      averageBreaksPerDay: avgBreaksPerDay,
      averageDailyUsageMinutes: avgUsagePerDay,
      totalBreaksThisWeek: totalBreaks,
      totalSkippedThisWeek: totalSkipped,
      completionRate: completionRate,
      insight: insight,
    );

    return StatsCalculationResult(stats: stats, insights: insights);
  }

  static StatsUpdateResult updateStats(Map<String, dynamic> params) {
    final weeklyDataJsonString = params['weeklyDataJsonString'] as String;
    final today = params['today'] as String;
    final breaksPerDayForStreak = params['breaksPerDayForStreak'] as int;

    int breaksCompleted = params['breaksCompleted'] as int;
    int breaksSkipped = params['breaksSkipped'] as int;
    int dailyUsageMinutes = params['dailyUsageMinutes'] as int;
    int currentStreak = params['currentStreak'] as int;
    int longestStreak = params['longestStreak'] as int;
    int totalWorkSessions = params['totalWorkSessions'] as int;

    final breaksCompletedDelta = params['breaksCompletedDelta'] as int;
    final breaksSkippedDelta = params['breaksSkippedDelta'] as int;
    final usageMinutesDelta = params['usageMinutesDelta'] as int;
    final wellnessActionsDelta = params['wellnessActionsDelta'] as int;
    final workSessionsDelta = params['workSessionsDelta'] as int;

    breaksCompleted += breaksCompletedDelta;
    breaksSkipped += breaksSkippedDelta;
    dailyUsageMinutes += usageMinutesDelta;
    totalWorkSessions += workSessionsDelta;

    List<DailyStats> weeklyData = [];
    if (weeklyDataJsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonData = jsonDecode(weeklyDataJsonString);
        weeklyData = jsonData.map((e) => DailyStats.fromJson(e)).toList();
      } catch (_) {}
    }

    // Initialize weeklyData if empty (fallback)
    if (weeklyData.isEmpty) {
      final baseTime = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = baseTime.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        weeklyData.add(
          DailyStats(
            date: dateStr,
            breaksCompleted: 0,
            breaksSkipped: 0,
            usageMinutes: 0,
            wellnessActions: 0,
          ),
        );
      }
    }

    final todayIndex = weeklyData.indexWhere((day) => day.date == today);
    if (todayIndex != -1) {
      final todayStats = weeklyData[todayIndex];
      weeklyData[todayIndex] = DailyStats(
        date: today,
        breaksCompleted: todayStats.breaksCompleted + breaksCompletedDelta,
        breaksSkipped: todayStats.breaksSkipped + breaksSkippedDelta,
        usageMinutes: todayStats.usageMinutes + usageMinutesDelta,
        wellnessActions: todayStats.wellnessActions + wellnessActionsDelta,
      );
    } else {
      weeklyData.add(
        DailyStats(
          date: today,
          breaksCompleted: breaksCompletedDelta,
          breaksSkipped: breaksSkippedDelta,
          usageMinutes: usageMinutesDelta,
          wellnessActions: wellnessActionsDelta,
        ),
      );
      if (weeklyData.length > 365) {
        weeklyData.removeAt(0);
      }
    }

    // Handle streak progression
    final previousTodayBreaks = todayIndex != -1
        ? weeklyData[todayIndex].breaksCompleted - breaksCompletedDelta
        : 0;

    final updatedTodayBreaks = todayIndex != -1
        ? weeklyData[todayIndex].breaksCompleted
        : breaksCompletedDelta;

    if (previousTodayBreaks < breaksPerDayForStreak &&
        updatedTodayBreaks >= breaksPerDayForStreak) {
      currentStreak += 1;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }

    // Calculations
    double averageBreaksPerDay = 0.0;
    if (weeklyData.isNotEmpty) {
      final total = weeklyData.fold<int>(
        0,
        (sum, day) => sum + day.breaksCompleted,
      );
      averageBreaksPerDay = total / weeklyData.length;
    }

    final totalBreaks = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.breaksCompleted,
    );
    final totalUsage = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.usageMinutes,
    );
    final totalSkipped = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.breaksSkipped,
    );

    final avgBreaksPerDay = weeklyData.isNotEmpty
        ? totalBreaks / weeklyData.length
        : 0.0;
    final avgUsagePerDay = weeklyData.isNotEmpty
        ? totalUsage / weeklyData.length
        : 0.0;

    final completionRate = totalBreaks + totalSkipped > 0
        ? totalBreaks / (totalBreaks + totalSkipped)
        : 0.0;

    int productivityScore = 0;
    productivityScore += (completionRate * 50).round();

    if (avgBreaksPerDay >= 5 && avgBreaksPerDay <= 7) {
      productivityScore += 30;
    } else if (avgBreaksPerDay >= 3 && avgBreaksPerDay < 5) {
      productivityScore += 20;
    } else if (avgBreaksPerDay >= 1 && avgBreaksPerDay < 3) {
      productivityScore += 10;
    }

    if (currentStreak >= 7) {
      productivityScore += 20;
    } else if (currentStreak >= 3) {
      productivityScore += 10;
    }
    productivityScore = productivityScore.clamp(0, 100);

    final totalWellnessActions = weeklyData.fold<int>(
      0,
      (sum, day) => sum + day.wellnessActions,
    );

    int wellnessScore = 0;
    if (weeklyData.isNotEmpty) {
      final avgActions = totalWellnessActions / weeklyData.length;
      wellnessScore += ((avgActions / 10).clamp(0.0, 1.0) * 70).round();
      wellnessScore += (completionRate * 30).round();
    }
    wellnessScore = wellnessScore.clamp(0, 100);

    String insight = 'Keep up the good work!';
    if (avgBreaksPerDay < 3) {
      insight = 'Try to take more breaks for better productivity.';
    } else if (avgBreaksPerDay > 8) {
      insight = 'Great break habits! Consider longer focus sessions.';
    }

    if (totalSkipped > totalBreaks * 0.3) {
      insight = 'Consider adjusting break intervals to reduce skipping.';
    }

    final stats = StatsModel(
      breaksCompleted: breaksCompleted,
      breaksSkipped: breaksSkipped,
      dailyUsageMinutes: dailyUsageMinutes,
      lastActiveDate: today,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      weeklyData: weeklyData,
      totalWorkSessions: totalWorkSessions,
      averageBreaksPerDay: averageBreaksPerDay,
      productivityScore: productivityScore,
      wellnessScore: wellnessScore,
      totalWellnessActions: totalWellnessActions,
    );

    final insights = ProductivityInsights(
      averageBreaksPerDay: avgBreaksPerDay,
      averageDailyUsageMinutes: avgUsagePerDay,
      totalBreaksThisWeek: totalBreaks,
      totalSkippedThisWeek: totalSkipped,
      completionRate: completionRate,
      insight: insight,
    );

    final updatedWeeklyDataJson = jsonEncode(
      weeklyData.map((e) => e.toJson()).toList(),
    );

    return StatsUpdateResult(
      stats: stats,
      insights: insights,
      breaksCompleted: breaksCompleted,
      breaksSkipped: breaksSkipped,
      dailyUsageMinutes: dailyUsageMinutes,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalWorkSessions: totalWorkSessions,
      updatedWeeklyDataJson: updatedWeeklyDataJson,
    );
  }
}
