import 'dart:async' show Timer;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_calculator.dart';

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

  Timer? _statsFlushTimer;
  int _pendingBreaksCompleted = 0;
  int _pendingBreaksSkipped = 0;
  int _pendingUsageMinutes = 0;
  int _pendingWellnessActions = 0;
  int _pendingWorkSessions = 0;

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

    _ensureStorageKeys();

    if (lastDate != today) {
      // calculation will always see lastActive == today.
      _checkAndUpdateStreak(today);

      _storage.setString(AppConstants.keyLastActiveDate, today);
      _storage.setInt(AppConstants.keyDailyUsageMinutes, 0);
      _storage.setInt(AppConstants.keyBreaksCompleted, 0);
      _storage.setInt(AppConstants.keyBreaksSkipped, 0);

      final weeklyDataJson = _storage.getString(AppConstants.keyWeeklyStats);
      if (weeklyDataJson.isNotEmpty) {
        try {
          final List<dynamic> jsonData = jsonDecode(weeklyDataJson);
          final List<DailyStats> weeklyData = jsonData
              .map((e) => DailyStats.fromJson(e))
              .toList();

          if (!weeklyData.any((d) => d.date == today)) {
            weeklyData.add(
              DailyStats(
                date: today,
                breaksCompleted: 0,
                breaksSkipped: 0,
                usageMinutes: 0,
              ),
            );
            if (weeklyData.length > 365) weeklyData.removeAt(0);
            _storage.setString(
              AppConstants.keyWeeklyStats,
              jsonEncode(weeklyData.map((e) => e.toJson()).toList()),
            );
          }
        } catch (e) {
          debugPrint('Error migrating weekly data: $e');
        }
      }
    }

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
    _pendingBreaksCompleted++;
    _flushImmediately(); // Break completion is important, flush immediately
  }

  void recordSkippedBreak() {
    _pendingBreaksSkipped++;
    _scheduleFlush();
  }

  void recordWellnessAction() {
    _pendingWellnessActions++;
    _scheduleFlush();
  }

  void addUsageMinutes(int minutes) {
    _pendingUsageMinutes += minutes;
    _scheduleFlush();
  }

  void recordWorkSession() {
    _pendingWorkSessions++;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _statsFlushTimer?.cancel();
    _statsFlushTimer = Timer(const Duration(seconds: 10), _flushPendingStats);
  }

  void _flushImmediately() {
    _statsFlushTimer?.cancel();
    _flushPendingStats();
  }

  void flush() {
    _flushImmediately();
  }

  void _flushPendingStats() {
    if (_pendingBreaksCompleted == 0 &&
        _pendingBreaksSkipped == 0 &&
        _pendingUsageMinutes == 0 &&
        _pendingWellnessActions == 0 &&
        _pendingWorkSessions == 0) {
      return;
    }

    _updateStatsAsync(
      breaksCompletedDelta: _pendingBreaksCompleted,
      breaksSkippedDelta: _pendingBreaksSkipped,
      usageMinutesDelta: _pendingUsageMinutes,
      wellnessActionsDelta: _pendingWellnessActions,
      workSessionsDelta: _pendingWorkSessions,
    );

    _pendingBreaksCompleted = 0;
    _pendingBreaksSkipped = 0;
    _pendingUsageMinutes = 0;
    _pendingWellnessActions = 0;
    _pendingWorkSessions = 0;
  }

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
      final result = StatsCalculator.calculateStats(params);
      _cachedStats = result.stats;
      _cachedInsights = result.insights;
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating stats: $e');
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
      final result = StatsCalculator.updateStats(params);

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
      debugPrint('Error updating stats: $e');
    }
  }

  void _checkAndUpdateStreak(String today) {
    final yesterday = _getYesterdayString();
    final lastActive = _storage.getString(AppConstants.keyLastActiveDate);

    if (lastActive == yesterday) {
    } else if (lastActive != today) {
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

// Note: Isolate handlers have been removed in favor of StatsCalculator

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
