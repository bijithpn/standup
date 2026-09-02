import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_trend.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  setUp(() {
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
    SimplePrefs.instance.remove(AppConstants.keyFocusSessionData);
  });

  tearDown(() {
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
    SimplePrefs.instance.remove(AppConstants.keyFocusSessionData);
  });

  test('returns one point per day, most recent last', () {
    final usageService = AppUsageService(storage: StorageService());
    final focusSessionService = FocusSessionService(storage: StorageService());
    final today = DateTime(2026, 9, 6);

    final points = computeFocusTrend(
      focusSessionService: focusSessionService,
      usageService: usageService,
      days: 7,
      now: today,
    );

    expect(points, hasLength(7));
    expect(points.last.date, today);
    expect(points.first.date, today.subtract(const Duration(days: 6)));
  });

  test('a day with no tracked activity has a zero focus score', () {
    final usageService = AppUsageService(storage: StorageService());
    final focusSessionService = FocusSessionService(storage: StorageService());
    final today = DateTime(2026, 9, 6);

    final points = computeFocusTrend(
      focusSessionService: focusSessionService,
      usageService: usageService,
      days: 1,
      now: today,
    );

    expect(points.single.focusScore, 0.0);
  });

  test('computes the correct share of tracked time spent focused', () {
    final usageService = AppUsageService(storage: StorageService());
    final focusSessionService = FocusSessionService(storage: StorageService());
    final today = DateTime(2026, 9, 6);
    final dateKey = '2026-09-06';

    usageService.addUsageSeconds(
      date: dateKey,
      appKey: 'com.test.app',
      name: 'TestApp',
      category: AppCategory.general,
      seconds: 3600, // 1 hour tracked
    );
    focusSessionService.recordSession(
      FocusSession(
        category: AppCategory.coding,
        start: DateTime(2026, 9, 6, 9),
        durationSeconds: 1800, // 30 min focused
      ),
    );

    final points = computeFocusTrend(
      focusSessionService: focusSessionService,
      usageService: usageService,
      days: 1,
      now: today,
    );

    expect(points.single.focusScore, closeTo(0.5, 0.001));
  });
}
