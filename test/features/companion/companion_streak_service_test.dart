import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';

class InMemoryStorageService extends FakeStorageService {
  final Map<String, int> _ints = {};

  @override
  int getInt(String key, {int defaultValue = 0}) => _ints[key] ?? defaultValue;

  @override
  Future<bool> setInt(String key, int value) async {
    _ints[key] = value;
    return true;
  }

  @override
  String getString(String key, {String defaultValue = ''}) => defaultValue;

  @override
  Future<bool> setString(String key, String value) async => true;
}

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A StatsService whose `stats` getter can be driven directly from a test,
/// bypassing storage/isolate flushing entirely.
class FakeStatsService extends StatsService {
  StatsModel _fakeStats = const StatsModel();

  FakeStatsService(StorageService storage) : super(storage: storage);

  @override
  StatsModel get stats => _fakeStats;

  void setCurrentStreak(int streak) {
    _fakeStats = StatsModel(currentStreak: streak);
    notifyListeners();
  }
}

void main() {
  late InMemoryStorageService storage;
  late FakeStatsService statsService;
  late EventBus eventBus;
  late CompanionStreakService streakService;
  late List<CompanionInteractionEvent> emittedInteractions;
  late StreamSubscription<CompanionInteractionEvent> subscription;

  setUp(() {
    storage = InMemoryStorageService();
    statsService = FakeStatsService(storage);
    eventBus = EventBus.instance;
    emittedInteractions = [];
    subscription = eventBus.on<CompanionInteractionEvent>().listen(
      emittedInteractions.add,
    );
    streakService = CompanionStreakService(
      statsService: statsService,
      storage: storage,
      eventBus: eventBus,
    );
  });

  tearDown(() async {
    // EventBus.instance is a process-wide singleton — without this, each
    // test's listener stays subscribed and keeps firing (harmlessly, but
    // wastefully) for the rest of the run.
    await subscription.cancel();
  });

  test('starts with no milestone reached', () {
    expect(streakService.highestMilestone, isNull);
    expect(streakService.nextMilestone?.days, equals(3));
    expect(streakService.currentStreakDays, equals(0));
  });

  test(
    'crossing the first tier unlocks it and celebrates the companion',
    () async {
      statsService.setCurrentStreak(3);
      await Future<void>.delayed(Duration.zero);

      expect(streakService.highestMilestone?.days, equals(3));
      expect(streakService.nextMilestone?.days, equals(7));
      expect(emittedInteractions, hasLength(1));
      expect(emittedInteractions.single.interactionType, equals('happy'));
      expect(
        emittedInteractions.single.metadata?['reason'],
        equals('streak_milestone'),
      );
      expect(emittedInteractions.single.metadata?['days'], equals(3));
    },
  );

  test(
    'jumping several tiers at once only celebrates the highest one',
    () async {
      statsService.setCurrentStreak(10);
      await Future<void>.delayed(Duration.zero);

      expect(streakService.highestMilestone?.days, equals(7));
      expect(emittedInteractions, hasLength(1));
      expect(emittedInteractions.single.metadata?['days'], equals(7));
    },
  );

  test('does not re-celebrate a tier already reached', () async {
    statsService.setCurrentStreak(3);
    await Future<void>.delayed(Duration.zero);
    statsService.setCurrentStreak(3);
    await Future<void>.delayed(Duration.zero);

    expect(emittedInteractions, hasLength(1));
  });

  test(
    'a streak reset does not un-celebrate a previously reached milestone',
    () async {
      statsService.setCurrentStreak(7);
      await Future<void>.delayed(Duration.zero);
      statsService.setCurrentStreak(0);
      await Future<void>.delayed(Duration.zero);

      expect(streakService.highestMilestone?.days, equals(7));
      expect(streakService.currentStreakDays, equals(0));
      expect(emittedInteractions, hasLength(1));
    },
  );

  test(
    'the highest milestone persists across a fresh service instance',
    () async {
      statsService.setCurrentStreak(14);
      await Future<void>.delayed(Duration.zero);

      final rehydrated = CompanionStreakService(
        statsService: FakeStatsService(storage),
        storage: storage,
        eventBus: eventBus,
      );

      expect(rehydrated.highestMilestone?.days, equals(14));
    },
  );

  test('reaches the final tier without exceeding the tier list', () async {
    statsService.setCurrentStreak(1000);
    await Future<void>.delayed(Duration.zero);

    expect(streakService.highestMilestone?.days, equals(100));
    expect(streakService.nextMilestone, isNull);
  });
}
