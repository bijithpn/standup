import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/stats_model.dart';

/// Enhanced statistics service with streak tracking, weekly data, and productivity insights
/// Optimized using background Isolate Pooling for heavy JSON parsing and scoring math.
class StatsService extends ChangeNotifier {
  final StorageService _storage;

  StatsModel _cachedStats = const StatsModel();
  ProductivityInsights _cachedInsights = ProductivityInsights(
    averageBreaksPerDay: 0.0,
    averageDailyUsageMinutes: 0.0,
    totalBreaksThisWeek: 0,
    totalSkippedThisWeek: 0,
    completionRate: 0.0,
    insight: 'Keep up the good work!',
  );

  StatsModel get stats => _cachedStats;
  ProductivityInsights get insights => _cachedInsights;

  StatsService({required StorageService storage}) : _storage = storage {
    // Fast synchronous baseline load from memory-cached primitives to avoid zero-values on startup
    _cachedStats = StatsModel(
      breaksCompleted: _storage.getInt(AppConstants.keyBreaksCompleted),
      breaksSkipped: _storage.getInt(AppConstants.keyBreaksSkipped),
      dailyUsageMinutes: _storage.getInt(AppConstants.keyDailyUsageMinutes),
      lastActiveDate: _storage.getString(AppConstants.keyLastActiveDate),
      currentStreak: _storage.getInt(AppConstants.keyCurrentStreak),
      longestStreak: _storage.getInt(AppConstants.keyLongestStreak),
      totalWorkSessions: _storage.getInt(AppConstants.keyTotalWorkSessions),
    );
    initialize();
  }

  Future<void> initialize() async {
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

    await _refreshStatsAsync();
  }

  StatsModel load() {
    return _cachedStats;
  }

  ProductivityInsights getInsights() {
    return _cachedInsights;
  }

  List<DailyStats> getWeeklyStats() {
    return _cachedStats.weeklyData;
  }

  void recordCompletedBreak() {
    _updateStatsAsync(breaksCompletedDelta: 1);
  }

  void recordSkippedBreak() {
    _updateStatsAsync(breaksSkippedDelta: 1);
  }

  void recordWellnessAction() {
    _updateStatsAsync(wellnessActionsDelta: 1);
  }

  void addUsageMinutes(int minutes) {
    _updateStatsAsync(usageMinutesDelta: minutes);
  }

  void recordWorkSession() {
    _updateStatsAsync(workSessionsDelta: 1);
  }

  // ============ Private Helper Methods ============

  Future<void> _refreshStatsAsync() async {
    final weeklyDataJsonString = _storage.getString(
      AppConstants.keyWeeklyStats,
    );
    final params = {
      'weeklyDataJsonString': weeklyDataJsonString,
      'breaksCompleted': _storage.getInt(AppConstants.keyBreaksCompleted),
      'breaksSkipped': _storage.getInt(AppConstants.keyBreaksSkipped),
      'dailyUsageMinutes': _storage.getInt(AppConstants.keyDailyUsageMinutes),
      'lastActiveDate': _storage.getString(AppConstants.keyLastActiveDate),
      'currentStreak': _storage.getInt(AppConstants.keyCurrentStreak),
      'longestStreak': _storage.getInt(AppConstants.keyLongestStreak),
      'totalWorkSessions': _storage.getInt(AppConstants.keyTotalWorkSessions),
    };

    try {
      final result = await compute(_calculateStatsIsolate, params);
      _cachedStats = result.stats;
      _cachedInsights = result.insights;
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating stats in isolate: $e');
    }
  }

  Future<void> _updateStatsAsync({
    int breaksCompletedDelta = 0,
    int breaksSkippedDelta = 0,
    int usageMinutesDelta = 0,
    int wellnessActionsDelta = 0,
    int workSessionsDelta = 0,
  }) async {
    final today = _todayString();
    final params = {
      'weeklyDataJsonString': _storage.getString(AppConstants.keyWeeklyStats),
      'breaksCompleted': _storage.getInt(AppConstants.keyBreaksCompleted),
      'breaksSkipped': _storage.getInt(AppConstants.keyBreaksSkipped),
      'dailyUsageMinutes': _storage.getInt(AppConstants.keyDailyUsageMinutes),
      'lastActiveDate': _storage.getString(AppConstants.keyLastActiveDate),
      'currentStreak': _storage.getInt(AppConstants.keyCurrentStreak),
      'longestStreak': _storage.getInt(AppConstants.keyLongestStreak),
      'totalWorkSessions': _storage.getInt(AppConstants.keyTotalWorkSessions),
      'today': today,
      'breaksCompletedDelta': breaksCompletedDelta,
      'breaksSkippedDelta': breaksSkippedDelta,
      'usageMinutesDelta': usageMinutesDelta,
      'wellnessActionsDelta': wellnessActionsDelta,
      'workSessionsDelta': workSessionsDelta,
      'breaksPerDayForStreak': AppConstants.breaksPerDayForStreak,
    };

    try {
      final result = await compute(_updateStatsIsolate, params);

      // Write results to storage on the main isolate
      _storage.setInt(AppConstants.keyBreaksCompleted, result.breaksCompleted);
      _storage.setInt(AppConstants.keyBreaksSkipped, result.breaksSkipped);
      _storage.setInt(
        AppConstants.keyDailyUsageMinutes,
        result.dailyUsageMinutes,
      );
      _storage.setInt(AppConstants.keyCurrentStreak, result.currentStreak);
      _storage.setInt(AppConstants.keyLongestStreak, result.longestStreak);
      _storage.setInt(
        AppConstants.keyTotalWorkSessions,
        result.totalWorkSessions,
      );
      _storage.setString(
        AppConstants.keyWeeklyStats,
        result.updatedWeeklyDataJson,
      );

      _cachedStats = result.stats;
      _cachedInsights = result.insights;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating stats in isolate: $e');
    }
  }

  void _checkAndUpdateStreak(String today) {
    final yesterday = _getYesterdayString();
    final lastActive = _storage.getString(AppConstants.keyLastActiveDate);

    if (lastActive == yesterday) {
      // Streak continues
    } else if (lastActive != today) {
      // Streak broken
      _storage.setInt(AppConstants.keyCurrentStreak, 0);
    }
  }

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
      if ((_storage.getInt(key)) == 0) {
        _storage.setInt(key, 0);
      }
    }

    // Initialize weekly data if not exists
    if (_storage.getString(AppConstants.keyWeeklyStats).isEmpty) {
      final List<DailyStats> initialWeeklyData = [];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        initialWeeklyData.add(
          DailyStats(
            date: dateStr,
            breaksCompleted: 0,
            breaksSkipped: 0,
            usageMinutes: 0,
            wellnessActions: 0,
          ),
        );
      }
      final jsonData = initialWeeklyData.map((e) => e.toJson()).toList();
      _storage.setString(AppConstants.keyWeeklyStats, jsonEncode(jsonData));
    }
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

// ============ Background Isolate Handlers ============

StatsCalculationResult _calculateStatsIsolate(Map<String, dynamic> params) {
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

StatsUpdateResult _updateStatsIsolate(Map<String, dynamic> params) {
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
  final updatedTodayBreaks = todayIndex != -1
      ? weeklyData[todayIndex].breaksCompleted
      : breaksCompletedDelta;

  if (breaksCompletedDelta > 0 && updatedTodayBreaks >= breaksPerDayForStreak) {
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

// ============ Data Structures for Isolate communication ============

class StatsCalculationResult {
  final StatsModel stats;
  final ProductivityInsights insights;
  StatsCalculationResult({required this.stats, required this.insights});
}

class StatsUpdateResult {
  final StatsModel stats;
  final ProductivityInsights insights;
  final int breaksCompleted;
  final int breaksSkipped;
  final int dailyUsageMinutes;
  final int currentStreak;
  final int longestStreak;
  final int totalWorkSessions;
  final String updatedWeeklyDataJson;

  StatsUpdateResult({
    required this.stats,
    required this.insights,
    required this.breaksCompleted,
    required this.breaksSkipped,
    required this.dailyUsageMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalWorkSessions,
    required this.updatedWeeklyDataJson,
  });
}

// ============ Models ============

/// Daily statistics model
class DailyStats {
  final String date;
  final int breaksCompleted;
  final int breaksSkipped;
  final int usageMinutes;
  final int wellnessActions;

  DailyStats({
    required this.date,
    required this.breaksCompleted,
    required this.breaksSkipped,
    required this.usageMinutes,
    this.wellnessActions = 0,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: json['date'] ?? '',
      breaksCompleted: json['breaksCompleted'] ?? 0,
      breaksSkipped: json['breaksSkipped'] ?? 0,
      usageMinutes: json['usageMinutes'] ?? 0,
      wellnessActions: json['wellnessActions'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'breaksCompleted': breaksCompleted,
      'breaksSkipped': breaksSkipped,
      'usageMinutes': usageMinutes,
      'wellnessActions': wellnessActions,
    };
  }

  String get dayName {
    try {
      final parts = date.split('-');
      final dateTime = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
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
