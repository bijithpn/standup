import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

class InMemoryStorageService extends FakeStorageService {
  final Map<String, String> _strings = {};
  final Map<String, int> _ints = {};

  @override
  String getString(String key, {String defaultValue = ''}) =>
      _strings[key] ?? defaultValue;

  @override
  Future<bool> setString(String key, String value) async {
    _strings[key] = value;
    return true;
  }

  @override
  int getInt(String key, {int defaultValue = 0}) => _ints[key] ?? defaultValue;

  @override
  Future<bool> setInt(String key, int value) async {
    _ints[key] = value;
    return true;
  }
}

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryStorageService storage;
  late FocusSessionService focusSessionService;
  late AppUsageService usageService;
  late EventBus eventBus;
  late FocusStreakService streakService;

  String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Populates one day with enough tracked time and a focus session hitting
  /// [scoreFraction] of it (e.g. 0.5 = half the day was deep work).
  void seedDay(DateTime day, double scoreFraction) {
    withClock(Clock.fixed(day), () {
      usageService.addUsageSeconds(
        date: dateKey(day),
        appKey: 'com.test.app',
        name: 'TestApp',
        category: AppCategory.general,
        seconds: 3600,
      );
      if (scoreFraction > 0) {
        focusSessionService.recordSession(
          FocusSession(
            category: AppCategory.coding,
            start: DateTime(day.year, day.month, day.day, 9),
            durationSeconds: (3600 * scoreFraction).round(),
          ),
        );
      }
    });
  }

  setUp(() {
    storage = InMemoryStorageService();
    focusSessionService = FocusSessionService(storage: storage);
    usageService = AppUsageService(storage: storage);
    eventBus = EventBus.instance;
    streakService = FocusStreakService(
      focusSessionService: focusSessionService,
      usageService: usageService,
      storage: storage,
      eventBus: eventBus,
    );
  });

  test('starts with no streak and no milestone', () {
    expect(streakService.currentStreakDays(), 0);
    expect(streakService.highestMilestone, isNull);
    expect(streakService.nextMilestone?.days, 3);
  });

  test('counts consecutive qualifying days ending today', () {
    final today = DateTime(2026, 9, 6);
    for (var i = 0; i < 3; i++) {
      seedDay(today.subtract(Duration(days: i)), 0.5); // well above 0.3
    }

    expect(streakService.currentStreakDays(now: today), 3);
  });

  test('a day below the threshold breaks the streak', () {
    final today = DateTime(2026, 9, 6);
    seedDay(today, 0.5);
    seedDay(today.subtract(const Duration(days: 1)), 0.1); // below 0.3
    seedDay(today.subtract(const Duration(days: 2)), 0.5);

    expect(streakService.currentStreakDays(now: today), 1);
  });

  test('a day with no tracked activity yet does not break the streak', () {
    final today = DateTime(2026, 9, 6);
    // No seed for `today` at all (usageService.categoryTotals -> 0).
    seedDay(today.subtract(const Duration(days: 1)), 0.5);
    seedDay(today.subtract(const Duration(days: 2)), 0.5);

    expect(streakService.currentStreakDays(now: today), 2);
  });

  test('a day off in the middle (zero activity) does not break the streak', () {
    final today = DateTime(2026, 9, 6);
    seedDay(today, 0.5);
    // No seed for yesterday at all — a genuine day away from the computer.
    seedDay(today.subtract(const Duration(days: 2)), 0.5);
    seedDay(today.subtract(const Duration(days: 3)), 0.5);

    expect(streakService.currentStreakDays(now: today), 3);
  });

  test('celebrates the first milestone and emits a companion event', () async {
    final today = DateTime(2026, 9, 6);
    for (var i = 0; i < 3; i++) {
      seedDay(today.subtract(Duration(days: i)), 0.5);
    }

    final events = <CompanionInteractionEvent>[];
    final sub = eventBus.on<CompanionInteractionEvent>().listen(events.add);

    streakService.checkAndMaybeCelebrate(now: today);
    await Future<void>.delayed(Duration.zero);

    expect(streakService.highestMilestone?.days, 3);
    expect(events, hasLength(1));
    expect(events.single.metadata?['reason'], 'focus_streak_milestone');
    expect(events.single.metadata?['days'], 3);

    await sub.cancel();
  });

  test('does not re-celebrate an already-reached tier', () async {
    final today = DateTime(2026, 9, 6);
    for (var i = 0; i < 3; i++) {
      seedDay(today.subtract(Duration(days: i)), 0.5);
    }

    final events = <CompanionInteractionEvent>[];
    final sub = eventBus.on<CompanionInteractionEvent>().listen(events.add);

    streakService.checkAndMaybeCelebrate(now: today);
    streakService.checkAndMaybeCelebrate(now: today);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    await sub.cancel();
  });

  test('the highest milestone persists across a fresh service instance', () {
    final today = DateTime(2026, 9, 6);
    for (var i = 0; i < 7; i++) {
      seedDay(today.subtract(Duration(days: i)), 0.5);
    }
    streakService.checkAndMaybeCelebrate(now: today);

    final rehydrated = FocusStreakService(
      focusSessionService: focusSessionService,
      usageService: usageService,
      storage: storage,
      eventBus: eventBus,
    );

    expect(rehydrated.highestMilestone?.days, 7);
  });
}
