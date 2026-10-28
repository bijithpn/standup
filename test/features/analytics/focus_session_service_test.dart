import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  final testClock = Clock.fixed(DateTime(2026, 8, 31, 12, 0));

  setUp(() {
    SimplePrefs.instance.remove(AppConstants.keyFocusSessionData);
  });

  tearDown(() {
    SimplePrefs.instance.remove(AppConstants.keyFocusSessionData);
  });

  test('records a session and sums focus seconds for its date', () {
    withClock(testClock, () {
      final service = FocusSessionService(storage: StorageService());
      final start = DateTime(2026, 8, 31, 9, 0);

      service.recordSession(
        FocusSession(
          category: AppCategory.coding,
          start: start,
          durationSeconds: 1200,
        ),
      );
      service.recordSession(
        FocusSession(
          category: AppCategory.writing,
          start: start.add(const Duration(hours: 1)),
          durationSeconds: 900,
        ),
      );

      expect(service.focusSecondsForDate('2026-08-31'), 2100);
      expect(service.sessionsForDate('2026-08-31'), hasLength(2));
    });
  });

  test('clear removes sessions from memory, storage and notifies', () {
    withClock(testClock, () {
      final service = FocusSessionService(storage: StorageService());
      service.recordSession(
        FocusSession(
          category: AppCategory.coding,
          start: DateTime(2026, 8, 31, 9, 0),
          durationSeconds: 1200,
        ),
      );
      var notified = 0;
      service.addListener(() => notified++);

      service.clear();

      expect(service.sessionsForDate('2026-08-31'), isEmpty);
      expect(service.focusSecondsForDate('2026-08-31'), 0);
      expect(notified, 1);
      // A fresh instance reading storage sees nothing either.
      expect(
        FocusSessionService(
          storage: StorageService(),
        ).sessionsForDate('2026-08-31'),
        isEmpty,
      );
    });
  });

  test('focusScore is the share of total active seconds', () {
    withClock(testClock, () {
      final service = FocusSessionService(storage: StorageService());
      service.recordSession(
        FocusSession(
          category: AppCategory.coding,
          start: DateTime(2026, 8, 31, 9, 0),
          durationSeconds: 1800,
        ),
      );

      expect(
        service.focusScore('2026-08-31', totalActiveSeconds: 3600),
        closeTo(0.5, 0.0001),
      );
      expect(service.focusScore('2026-08-31', totalActiveSeconds: 0), 0.0);
    });
  });

  test('persists sessions across a fresh service instance', () {
    withClock(testClock, () {
      final storage = StorageService();
      FocusSessionService(storage: storage).recordSession(
        FocusSession(
          category: AppCategory.design,
          start: DateTime(2026, 8, 31, 9, 0),
          durationSeconds: 1500,
        ),
      );

      final reloaded = FocusSessionService(storage: storage);
      expect(reloaded.focusSecondsForDate('2026-08-31'), 1500);
    });
  });

  test(
    'sessionsForPeriod filters by today/week/month like AppUsageService',
    () {
      withClock(testClock, () {
        final service = FocusSessionService(storage: StorageService());
        final now = DateTime(2026, 8, 31, 12, 0);

        service.recordSession(
          FocusSession(
            category: AppCategory.coding,
            start: now,
            durationSeconds: 900,
          ),
        );
        service.recordSession(
          FocusSession(
            category: AppCategory.writing,
            start: now.subtract(const Duration(days: 3)),
            durationSeconds: 900,
          ),
        );
        service.recordSession(
          FocusSession(
            category: AppCategory.design,
            start: now.subtract(const Duration(days: 40)),
            durationSeconds: 900,
          ),
        );

        expect(
          service.sessionsForPeriod(UsagePeriod.today, now: now),
          hasLength(1),
        );
        expect(
          service.sessionsForPeriod(UsagePeriod.week, now: now),
          hasLength(2),
        );
        expect(
          service.sessionsForPeriod(UsagePeriod.month, now: now),
          hasLength(2),
        );
      });
    },
  );

  test('sessionsBetween returns sessions overlapping a window, sorted', () {
    withClock(testClock, () {
      final service = FocusSessionService(storage: StorageService());
      final start = DateTime(2026, 8, 31, 9, 0);

      service.recordSession(
        FocusSession(
          category: AppCategory.coding,
          start: start,
          durationSeconds: 600,
        ),
      );
      service.recordSession(
        FocusSession(
          category: AppCategory.writing,
          start: start.add(const Duration(hours: 2)),
          durationSeconds: 600,
        ),
      );

      final result = service.sessionsBetween(
        start,
        start.add(const Duration(hours: 1)),
      );

      expect(result, hasLength(1));
      expect(result.first.category, AppCategory.coding);
    });
  });
}
