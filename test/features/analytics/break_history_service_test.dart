import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';

void main() {
  final testClock = Clock.fixed(DateTime(2026, 8, 31, 12, 0));

  setUp(() {
    SimplePrefs.instance.remove(AppConstants.keyBreakHistoryData);
  });

  tearDown(() {
    SimplePrefs.instance.remove(AppConstants.keyBreakHistoryData);
  });

  test('records completed and skipped breaks', () {
    withClock(testClock, () {
      final service = BreakHistoryService(storage: StorageService());
      final t1 = DateTime(2026, 8, 31, 9, 0);
      final t2 = DateTime(2026, 8, 31, 10, 0);

      service.recordBreak(time: t1, completed: true);
      service.recordBreak(time: t2, completed: false);

      expect(service.events, hasLength(2));
      expect(service.events.first.completed, isTrue);
      expect(service.events.last.completed, isFalse);
    });
  });

  test('eventsBetween filters and sorts by time', () {
    withClock(testClock, () {
      final service = BreakHistoryService(storage: StorageService());
      final base = DateTime(2026, 8, 31, 9, 0);

      service.recordBreak(
        time: base.add(const Duration(hours: 2)),
        completed: true,
      );
      service.recordBreak(time: base, completed: false);
      service.recordBreak(
        time: base.add(const Duration(days: 5)),
        completed: true,
      );

      final result = service.eventsBetween(
        base,
        base.add(const Duration(hours: 3)),
      );

      expect(result, hasLength(2));
      expect(result.first.time, base);
    });
  });

  test('persists events across a fresh service instance', () {
    withClock(testClock, () {
      final storage = StorageService();
      BreakHistoryService(
        storage: storage,
      ).recordBreak(time: DateTime(2026, 8, 31, 9, 0), completed: true);

      final reloaded = BreakHistoryService(storage: storage);
      expect(reloaded.events, hasLength(1));
    });
  });
}
