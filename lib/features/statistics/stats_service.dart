import 'dart:convert';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/services/storage_service.dart';
import 'package:standup/features/statistics/stats_model.dart';

/// Enhanced statistics service with streak tracking, weekly data, and productivity insights
class StatsService {
  final StorageService _storage;

  StatsService({required StorageService storage}) : _storage = storage;

  StatsModel load() {
    final today = _todayString();
    final lastDate = _storage.getString(AppConstants.keyLastActiveDate);

    // Reset daily stats if it's a new day
    if (lastDate != today) {
      _storage.setString(AppConstants.keyLastActiveDate, today);
      _storage.setInt(AppConstants.keyDailyUsageMinutes, 0);
      _checkAndUpdateStreak(today);
    }

    // Ensure all required keys exist
    _ensureStorageKeys();

    return StatsModel(
      breaksCompleted: _storage.getInt(AppConstants.keyBreaksCompleted),
      breaksSkipped: _storage.getInt(AppConstants.keyBreaksSkipped),
      dailyUsageMinutes: _storage.getInt(AppConstants.keyDailyUsageMinutes),
      lastActiveDate: today,
      currentStreak: _storage.getInt(AppConstants.keyCurrentStreak),
      longestStreak: _storage.getInt(AppConstants.keyLongestStreak),
      weeklyData: _loadWeeklyData(),
      totalWorkSessions: _storage.getInt(AppConstants.keyTotalWorkSessions),
      averageBreaksPerDay: _calculateAverageBreaksPerDay(),
      productivityScore: _calculateProductivityScore(),
    );
  }

  /// Ensure all storage keys are initialized
  void _ensureStorageKeys() {
    final keys = [
      AppConstants.keyBreaksCompleted,
      AppConstants.keyBreaksSkipped,
      AppConstants.keyDailyUsageMinutes,
      AppConstants.keyCurrentStreak,
      AppConstants.keyLongestStreak,
      AppConstants.keyTotalWorkSessions,
    ];
    
    for (final key in keys) {
      if ((_storage.getInt(key)) ==0) {
        _storage.setInt(key, 0);
      }
    }
    
    // Initialize weekly data if not exists
    if (_storage.getString(AppConstants.keyWeeklyStats).isNotEmpty) {
      _saveWeeklyData(_initializeWeeklyData());
    }
  }

  void recordCompletedBreak() {
    final current = _storage.getInt(AppConstants.keyBreaksCompleted);
    _storage.setInt(AppConstants.keyBreaksCompleted, current + 1);

    // Update today's break count in weekly data
    _updateWeeklyData(breaksCompleted: 1);

    // Check if we should increment streak (5+ breaks per day maintains streak)
    final todayBreaks = _getTodayBreakCount();
    if (todayBreaks >= AppConstants.breaksPerDayForStreak) {
      _incrementStreak();
    }
  }

  void recordSkippedBreak() {
    final current = _storage.getInt(AppConstants.keyBreaksSkipped);
    _storage.setInt(AppConstants.keyBreaksSkipped, current + 1);
    _updateWeeklyData(breaksSkipped: 1);
  }

  void addUsageMinutes(int minutes) {
    final current = _storage.getInt(AppConstants.keyDailyUsageMinutes);
    _storage.setInt(AppConstants.keyDailyUsageMinutes, current + minutes);
    _updateWeeklyData(usageMinutes: minutes);
  }

  void recordWorkSession() {
    final current = _storage.getInt(AppConstants.keyTotalWorkSessions);
    _storage.setInt(AppConstants.keyTotalWorkSessions, current + 1);
  }

  /// Get weekly statistics
  List<DailyStats> getWeeklyStats() {
    return _loadWeeklyData();
  }

  /// Get productivity insights
  ProductivityInsights getInsights() {
    final weeklyData = _loadWeeklyData();
    final totalBreaks = weeklyData.fold<int>(0, (sum, day) => sum + day.breaksCompleted);
    final totalUsage = weeklyData.fold<int>(0, (sum, day) => sum + day.usageMinutes);
    final totalSkipped = weeklyData.fold<int>(0, (sum, day) => sum + day.breaksSkipped);

    final avgBreaksPerDay = weeklyData.isNotEmpty ? totalBreaks / weeklyData.length : 0.0;
    final avgUsagePerDay = weeklyData.isNotEmpty ? totalUsage / weeklyData.length : 0.0;

    String insight = 'Keep up the good work!';
    if (avgBreaksPerDay < 3) {
      insight = 'Try to take more breaks for better productivity.';
    } else if (avgBreaksPerDay > 8) {
      insight = 'Great break habits! Consider longer focus sessions.';
    }

    if (totalSkipped > totalBreaks * 0.3) {
      insight = 'Consider adjusting break intervals to reduce skipping.';
    }

    return ProductivityInsights(
      averageBreaksPerDay: avgBreaksPerDay.toDouble(),
      averageDailyUsageMinutes: avgUsagePerDay.toDouble(),
      totalBreaksThisWeek: totalBreaks,
      totalSkippedThisWeek: totalSkipped,
      completionRate: totalBreaks + totalSkipped > 0
          ? totalBreaks / (totalBreaks + totalSkipped)
          : 0.0,
      insight: insight,
    );
  }

  // ============ Private Helper Methods ============

  void _checkAndUpdateStreak(String today) {
    final yesterday = _getYesterdayString();
    final lastActive = _storage.getString(AppConstants.keyLastActiveDate);

    if (lastActive == yesterday) {
      // Streak continues - already handled in recordCompletedBreak
    } else if (lastActive != today) {
      // Streak broken
      _storage.setInt(AppConstants.keyCurrentStreak, 0);
    }
  }

  void _incrementStreak() {
    final current = _storage.getInt(AppConstants.keyCurrentStreak);
    final newStreak = current + 1;
    _storage.setInt(AppConstants.keyCurrentStreak, newStreak);

    // Update longest streak
    final longest = _storage.getInt(AppConstants.keyLongestStreak);
    if (newStreak > longest) {
      _storage.setInt(AppConstants.keyLongestStreak, newStreak);
    }
  }

  int _getTodayBreakCount() {
    final weeklyData = _loadWeeklyData();
    final today = _todayString();
    final todayStats = weeklyData.firstWhere(
      (day) => day.date == today,
      orElse: () => DailyStats(date: today, breaksCompleted: 0, breaksSkipped: 0, usageMinutes: 0),
    );
    return todayStats.breaksCompleted;
  }

  List<DailyStats> _loadWeeklyData() {
    final dataString = _storage.getString(AppConstants.keyWeeklyStats);
    if (dataString.isEmpty) {
      return _initializeWeeklyData();
    }

    try {
      final List<dynamic> jsonData = jsonDecode(dataString);
      return jsonData.map((e) => DailyStats.fromJson(e)).toList();
    } catch (e) {
      return _initializeWeeklyData();
    }
  }

  List<DailyStats> _initializeWeeklyData() {
    final List<DailyStats> weeklyData = [];
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      weeklyData.add(DailyStats(
        date: dateStr,
        breaksCompleted: 0,
        breaksSkipped: 0,
        usageMinutes: 0,
      ));
    }
    _saveWeeklyData(weeklyData);
    return weeklyData;
  }

  void _updateWeeklyData({int breaksCompleted = 0, int breaksSkipped = 0, int usageMinutes = 0}) {
    final weeklyData = _loadWeeklyData();
    final today = _todayString();

    final todayIndex = weeklyData.indexWhere((day) => day.date == today);
    if (todayIndex != -1) {
      final todayStats = weeklyData[todayIndex];
      weeklyData[todayIndex] = DailyStats(
        date: today,
        breaksCompleted: todayStats.breaksCompleted + breaksCompleted,
        breaksSkipped: todayStats.breaksSkipped + breaksSkipped,
        usageMinutes: todayStats.usageMinutes + usageMinutes,
      );
      _saveWeeklyData(weeklyData);
    }
  }

  void _saveWeeklyData(List<DailyStats> weeklyData) {
    final jsonData = weeklyData.map((e) => e.toJson()).toList();
    _storage.setString(AppConstants.keyWeeklyStats, jsonEncode(jsonData));
  }

  double _calculateAverageBreaksPerDay() {
    final weeklyData = _loadWeeklyData();
    if (weeklyData.isEmpty) return 0.0;
    final total = weeklyData.fold<int>(0, (sum, day) => sum + day.breaksCompleted);
    return total / weeklyData.length;
  }

  int _calculateProductivityScore() {
    final insights = getInsights();
    final completionRate = insights.completionRate;
    final avgBreaks = insights.averageBreaksPerDay;

    // Score calculation:
    // - Completion rate: 50% weight
    // - Average breaks (ideal 5-7): 30% weight
    // - Consistency (streak): 20% weight

    int score = 0;
    score += (completionRate * 50).round();

    if (avgBreaks >= 5 && avgBreaks <= 7) {
      score += 30;
    } else if (avgBreaks >= 3 && avgBreaks < 5) {
      score += 20;
    } else if (avgBreaks >= 1 && avgBreaks < 3) {
      score += 10;
    }

    final streak = _storage.getInt(AppConstants.keyCurrentStreak);
    if (streak >= 7) {
      score += 20;
    } else if (streak >= 3) {
      score += 10;
    }

    return score.clamp(0, 100);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getYesterdayString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }
}

/// Daily statistics model
class DailyStats {
  final String date;
  final int breaksCompleted;
  final int breaksSkipped;
  final int usageMinutes;

  DailyStats({
    required this.date,
    required this.breaksCompleted,
    required this.breaksSkipped,
    required this.usageMinutes,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: json['date'] ?? '',
      breaksCompleted: json['breaksCompleted'] ?? 0,
      breaksSkipped: json['breaksSkipped'] ?? 0,
      usageMinutes: json['usageMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'breaksCompleted': breaksCompleted,
      'breaksSkipped': breaksSkipped,
      'usageMinutes': usageMinutes,
    };
  }

  String get dayName {
    try {
      final parts = date.split('-');
      final dateTime = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } catch (e) {
      return 'Unknown';
    }
  }
}

/// Productivity insights model
class ProductivityInsights {
  final double averageBreaksPerDay;
  final double averageDailyUsageMinutes;
  final int totalBreaksThisWeek;
  final int totalSkippedThisWeek;
  final double completionRate;
  final String insight;

  ProductivityInsights({
    required this.averageBreaksPerDay,
    required this.averageDailyUsageMinutes,
    required this.totalBreaksThisWeek,
    required this.totalSkippedThisWeek,
    required this.completionRate,
    required this.insight,
  });
}
