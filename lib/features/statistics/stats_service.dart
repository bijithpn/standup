import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/services/storage_service.dart';
import 'package:standup/features/statistics/stats_model.dart';

class StatsService {
  final StorageService _storage;

  StatsService({required StorageService storage}) : _storage = storage;

  StatsModel load() {
    final today = _todayString();
    final lastDate = _storage.getString(
      AppConstants.keyLastActiveDate,
    );

    // Reset daily stats if it's a new day
    if (lastDate != today) {
      _storage.setString(AppConstants.keyLastActiveDate, today);
      _storage.setInt(AppConstants.keyDailyUsageMinutes, 0);
    }

    return StatsModel(
      breaksCompleted: _storage.getInt(AppConstants.keyBreaksCompleted),
      breaksSkipped: _storage.getInt(AppConstants.keyBreaksSkipped),
      dailyUsageMinutes: _storage.getInt(AppConstants.keyDailyUsageMinutes),
      lastActiveDate: today,
    );
  }

  void recordCompletedBreak() {
    final current = _storage.getInt(AppConstants.keyBreaksCompleted);
    _storage.setInt(AppConstants.keyBreaksCompleted, current + 1);
  }

  void recordSkippedBreak() {
    final current = _storage.getInt(AppConstants.keyBreaksSkipped);
    _storage.setInt(AppConstants.keyBreaksSkipped, current + 1);
  }

  void addUsageMinutes(int minutes) {
    final current = _storage.getInt(AppConstants.keyDailyUsageMinutes);
    _storage.setInt(AppConstants.keyDailyUsageMinutes, current + minutes);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
