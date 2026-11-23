import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/break_system/application/skip_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 21, 14);

  test('skipsToday counts only skipped breaks from today', () {
    final events = [
      BreakEvent(time: DateTime(2026, 11, 21, 9), completed: false),
      BreakEvent(time: DateTime(2026, 11, 21, 10), completed: true),
      BreakEvent(time: DateTime(2026, 11, 20, 16), completed: false),
      BreakEvent(time: DateTime(2026, 11, 21, 13), completed: false),
    ];
    expect(SkipPolicy.skipsToday(events, now), 2);
  });

  test('snooze is locked after the daily cap and resets the next day', () {
    SimplePrefs.instance.clear();
    for (var i = 0; i < SkipPolicy.maxSnoozesPerDay; i++) {
      expect(SkipPolicy.isSnoozeLocked(now), isFalse);
      SkipPolicy.recordSnooze(now);
    }
    expect(SkipPolicy.isSnoozeLocked(now), isTrue);
    expect(
      SkipPolicy.isSnoozeLocked(now.add(const Duration(days: 1))),
      isFalse,
    );
  });

  test('reasons are counted per reason', () {
    SimplePrefs.instance.clear();
    SkipPolicy.recordReason('Deep focus', now);
    SkipPolicy.recordReason('Deep focus', now);
    SkipPolicy.recordReason('Not needed', now);
    expect(SkipPolicy.reasonCounts(), {'Deep focus': 2, 'Not needed': 1});
  });

  test('daily limit locks only when set and reached', () {
    SimplePrefs.instance.clear();
    final skips = [
      BreakEvent(time: now, completed: false),
      BreakEvent(time: now, completed: false),
    ];
    expect(SkipPolicy.isLocked(skips, now), isFalse);
    SkipPolicy.dailyLimit = 2;
    expect(SkipPolicy.isLocked(skips, now), isTrue);
    SkipPolicy.dailyLimit = 3;
    expect(SkipPolicy.isLocked(skips, now), isFalse);
  });

  test('periodAt splits the day into morning, afternoon and evening', () {
    DayPart at(int h) => TimeOfDayProfiles.periodAt(DateTime(2026, 11, 21, h));
    expect(at(4), DayPart.evening);
    expect(at(5), DayPart.morning);
    expect(at(11), DayPart.morning);
    expect(at(12), DayPart.afternoon);
    expect(at(16), DayPart.afternoon);
    expect(at(17), DayPart.evening);
  });
}
