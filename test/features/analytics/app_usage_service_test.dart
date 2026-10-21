import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  setUp(() {
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
  });

  tearDown(() {
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
  });

  group('formatUsageDuration', () {
    test('formats hours and minutes', () {
      expect(formatUsageDuration(3665), '1h 1m');
      expect(formatUsageDuration(90), '1m');
      expect(formatUsageDuration(0), '0m');
    });
  });

  group('AppUsageService', () {
    final testClock = Clock.fixed(DateTime(2026, 8, 31));

    test('accumulates seconds for the same app across multiple calls', () {
      withClock(testClock, () {
        final service = AppUsageService(storage: StorageService());
        final today = DateTime(2026, 8, 31);
        final dateStr = '2026-08-31';

        service.addUsageSeconds(
          date: dateStr,
          appKey: 'com.google.chrome',
          name: 'Chrome',
          category: AppCategory.browsing,
          seconds: 30,
        );
        service.addUsageSeconds(
          date: dateStr,
          appKey: 'com.google.chrome',
          name: 'Chrome',
          category: AppCategory.browsing,
          seconds: 40,
        );

        final apps = service.topApps(UsagePeriod.today, now: today);
        expect(apps.length, 1);
        expect(apps.first.seconds, 70);
        expect(apps.first.name, 'Chrome');
      });
    });

    test('topApps sorts descending and respects limit', () {
      withClock(testClock, () {
        final service = AppUsageService(storage: StorageService());
        final today = DateTime(2026, 8, 31);
        final dateStr = '2026-08-31';

        service.addUsageSeconds(
          date: dateStr, appKey: 'a', name: 'A',
          category: AppCategory.coding, seconds: 10,
        );
        service.addUsageSeconds(
          date: dateStr, appKey: 'b', name: 'B',
          category: AppCategory.browsing, seconds: 100,
        );
        service.addUsageSeconds(
          date: dateStr, appKey: 'c', name: 'C',
          category: AppCategory.meeting, seconds: 50,
        );

        final apps = service.topApps(UsagePeriod.today, limit: 2, now: today);
        expect(apps.map((e) => e.appKey).toList(), ['b', 'c']);
      });
    });

    test('categoryTotals sums seconds per category for the period', () {
      withClock(testClock, () {
        final service = AppUsageService(storage: StorageService());
        final today = DateTime(2026, 8, 31);
        final dateStr = '2026-08-31';

        service.addUsageSeconds(
          date: dateStr, appKey: 'a', name: 'A',
          category: AppCategory.coding, seconds: 10,
        );
        service.addUsageSeconds(
          date: dateStr, appKey: 'b', name: 'B',
          category: AppCategory.coding, seconds: 20,
        );
        service.addUsageSeconds(
          date: dateStr, appKey: 'c', name: 'C',
          category: AppCategory.browsing, seconds: 5,
        );

        final totals = service.categoryTotals(UsagePeriod.today, now: today);
        expect(totals[AppCategory.coding], 30);
        expect(totals[AppCategory.browsing], 5);
        expect(totals[AppCategory.meeting], 0);
      });
    });

    test('excludes dates outside the requested period', () {
      withClock(testClock, () {
        final service = AppUsageService(storage: StorageService());
        final today = DateTime(2026, 8, 31);

        service.addUsageSeconds(
          date: '2026-08-31', appKey: 'today-app', name: 'Today',
          category: AppCategory.general, seconds: 60,
        );
        service.addUsageSeconds(
          date: '2026-07-01', appKey: 'old-app', name: 'Old',
          category: AppCategory.general, seconds: 60,
        );

        final apps = service.topApps(UsagePeriod.today, now: today);
        expect(apps.map((e) => e.appKey), ['today-app']);
      });
    });

    test('persists across service instances via the shared storage key', () {
      withClock(testClock, () {
        final storage = StorageService();
        final first = AppUsageService(storage: storage);
        first.addUsageSeconds(
          date: '2026-08-31', appKey: 'x', name: 'X',
          category: AppCategory.general, seconds: 15,
        );

        final second = AppUsageService(storage: storage);
        final apps = second.topApps(UsagePeriod.today, now: DateTime(2026, 8, 31));
        expect(apps.first.seconds, 15);
      });
    });

    test('prunes dates older than 30 days on write', () {
      withClock(testClock, () {
        final storage = StorageService();
        final service = AppUsageService(storage: storage);
        final now = DateTime(2026, 8, 31);
        final staleDate = now.subtract(const Duration(days: 40));
        final staleDateStr =
            '${staleDate.year}-${staleDate.month.toString().padLeft(2, '0')}-${staleDate.day.toString().padLeft(2, '0')}';

        service.addUsageSeconds(
          date: staleDateStr, appKey: 'stale', name: 'Stale',
          category: AppCategory.general, seconds: 60,
        );
        // A fresh write triggers pruning.
        service.addUsageSeconds(
          date: '2026-08-31', appKey: 'fresh', name: 'Fresh',
          category: AppCategory.general, seconds: 60,
        );

        // Verify directly against the persisted blob, not via a period filter
        // that would already exclude the stale date on its own — this must
        // fail if _pruneOldDates is ever removed from the implementation.
        final raw = storage.getString(AppConstants.keyAppUsageData);
        expect(raw.contains(staleDateStr), isFalse);
        expect(raw.contains('2026-08-31'), isTrue);
      });
    });
  });
}
