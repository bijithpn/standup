import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/analytics/segments/productivity_repository.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    show StatsService;
import 'package:breakmate/features/settings/settings_repository.dart';

/// Wipes every piece of user data BreakMate owns: settings, companion
/// preferences, statistics, key/value records (app usage, focus sessions, break
/// history), the activity timeline, and the SimplePrefs mirror.
///
/// Only application-owned storage is touched; exported backups and CSVs the
/// user saved elsewhere are theirs and are left alone.
Future<void> wipeAllLocalData() async {
  final storage = sl<StorageService>();
  storage.settingsBox?.removeAll();
  storage.companionPreferencesBox?.removeAll();
  storage.globalStatsBox?.removeAll();
  storage.dailyStatsBox?.removeAll();
  storage.kvBox?.removeAll();
  storage.activitySegmentBox?.removeAll();

  SimplePrefs.instance.clear();

  // In-memory copies would otherwise be written straight back on the next flush.
  if (sl.isRegistered<ActivitySegmentRepository>()) {
    sl<ActivitySegmentRepository>().clearAll();
  }
  if (sl.isRegistered<AppUsageService>()) {
    sl<AppUsageService>().clear();
  }
  if (sl.isRegistered<FocusSessionService>()) {
    sl<FocusSessionService>().clear();
  }
  if (sl.isRegistered<ProductivityRepository>()) {
    sl<ProductivityRepository>().invalidate();
  }

  await sl<SettingsRepository>().load();
  if (sl.isRegistered<StatsService>()) {
    await sl<StatsService>().initialize();
  }
}
