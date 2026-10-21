import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/focus_session_detector.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  late DateTime base;

  setUp(() {
    base = DateTime(2026, 1, 1, 9, 0, 0);
  });

  test('does not emit a session while under the minimum duration', () {
    final detector = FocusSessionDetector();
    // 10 ticks of 10s = 100s of coding, well under the 15-minute minimum.
    for (var i = 0; i < 10; i++) {
      final result = detector.onTick(
        AppCategory.coding,
        base.add(Duration(seconds: i * 10)),
      );
      expect(result, isNull);
    }
    // Switching away closes the (too-short) session — still nothing emitted.
    final result = detector.onTick(
      AppCategory.browsing,
      base.add(const Duration(seconds: 100)),
    );
    expect(result, isNull);
  });

  test('emits a session once it reaches the minimum duration and closes', () {
    final detector = FocusSessionDetector();
    DateTime? closeTime;
    // 15 minutes = 90 ticks of 10s.
    for (var i = 0; i <= 90; i++) {
      final now = base.add(Duration(seconds: i * 10));
      final result = detector.onTick(AppCategory.coding, now);
      expect(result, isNull);
      closeTime = now;
    }

    final session = detector.onTick(
      AppCategory.browsing,
      closeTime!.add(const Duration(seconds: 10)),
    );

    expect(session, isNotNull);
    expect(session!.category, AppCategory.coding);
    expect(session.start, base);
    expect(session.durationSeconds, greaterThanOrEqualTo(15 * 60));
  });

  test('switching between two focus categories closes the first session', () {
    final detector = FocusSessionDetector();
    for (var i = 0; i <= 90; i++) {
      detector.onTick(AppCategory.coding, base.add(Duration(seconds: i * 10)));
    }

    final session = detector.onTick(
      AppCategory.design,
      base.add(const Duration(seconds: 910)),
    );

    expect(session, isNotNull);
    expect(session!.category, AppCategory.coding);
  });

  test('a gap longer than maxGap splits into separate sessions', () {
    final detector = FocusSessionDetector(maxGap: const Duration(seconds: 30));

    for (var i = 0; i <= 90; i++) {
      detector.onTick(AppCategory.coding, base.add(Duration(seconds: i * 10)));
    }
    final lastTick = base.add(const Duration(seconds: 900));

    // A big gap (idle for 10 minutes) before resuming the same category.
    final closed = detector.onTick(
      AppCategory.coding,
      lastTick.add(const Duration(minutes: 10)),
    );

    expect(closed, isNotNull);
    expect(closed!.durationSeconds, greaterThanOrEqualTo(15 * 60));
  });

  test('non-focus categories never accumulate a session', () {
    final detector = FocusSessionDetector();
    for (var i = 0; i <= 200; i++) {
      final result = detector.onTick(
        AppCategory.browsing,
        base.add(Duration(seconds: i * 10)),
      );
      expect(result, isNull);
    }
  });

  test('closeOpenSession finalizes an in-progress session on demand', () {
    final detector = FocusSessionDetector();
    for (var i = 0; i <= 90; i++) {
      detector.onTick(AppCategory.writing, base.add(Duration(seconds: i * 10)));
    }

    final session = detector.closeOpenSession();

    expect(session, isNotNull);
    expect(session!.category, AppCategory.writing);
    // A second call has nothing left to close.
    expect(detector.closeOpenSession(), isNull);
  });
}
