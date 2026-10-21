import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/weekly_digest.dart';
import 'package:breakmate/features/analytics/weekly_digest_service.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

class FakeSettingsRepository extends SettingsRepository {
  final SettingsModel _fakeSettings;

  FakeSettingsRepository(StorageService storage, [SettingsModel? settings])
      : _fakeSettings = settings ?? const SettingsModel(),
        super(storage: storage);

  @override
  SettingsModel get currentSettings => _fakeSettings;
}

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

class FakeStatsService extends StatsService {
  StatsModel _fakeStats = const StatsModel();

  FakeStatsService(StorageService storage) : super(storage: storage);

  @override
  StatsModel get stats => _fakeStats;

  void setWeeklyData(List<DailyStats> data) {
    _fakeStats = StatsModel(weeklyData: data);
  }
}

class FakeNotificationService extends NotificationService {
  final List<WeeklyDigest> shown = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showWeeklyDigest(WeeklyDigest digest) async {
    shown.add(digest);
  }
}

String _dateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

void main() {
  late InMemoryStorageService storage;
  late FakeStatsService statsService;
  late FocusSessionService focusSessionService;
  late CompanionStreakService streakService;
  late FakeNotificationService notificationService;
  late AppUsageService usageService;
  late SettingsRepository settingsRepository;
  late WeeklyDigestService digestService;

  setUp(() {
    storage = InMemoryStorageService();
    statsService = FakeStatsService(storage);
    focusSessionService = FocusSessionService(storage: storage);
    streakService = CompanionStreakService(
      statsService: statsService,
      storage: storage,
      eventBus: EventBus.instance,
    );
    notificationService = FakeNotificationService();
    usageService = AppUsageService(storage: storage);
    settingsRepository = SettingsRepository(storage: storage);
    digestService = WeeklyDigestService(
      storage: storage,
      statsService: statsService,
      focusSessionService: focusSessionService,
      streakService: streakService,
      notificationService: notificationService,
      usageService: usageService,
      settingsRepository: settingsRepository,
    );
  });

  test('does nothing outside the configured day/hour', () {
    // Wednesday, well before the 18:00 threshold.
    digestService.checkAndMaybeShow(now: DateTime(2026, 9, 2, 10, 0));
    expect(notificationService.shown, isEmpty);
  });

  test('shows the digest on Sunday evening', () {
    // 2026-09-06 is a Sunday.
    digestService.checkAndMaybeShow(now: DateTime(2026, 9, 6, 18, 0));
    expect(notificationService.shown, hasLength(1));
  });

  test('does not show the digest twice in the same week', () {
    digestService.checkAndMaybeShow(now: DateTime(2026, 9, 6, 18, 0));
    digestService.checkAndMaybeShow(now: DateTime(2026, 9, 6, 20, 0));
    expect(notificationService.shown, hasLength(1));
  });

  test('shows again the following week', () {
    digestService.checkAndMaybeShow(now: DateTime(2026, 9, 6, 18, 0));
    digestService.checkAndMaybeShow(now: DateTime(2026, 9, 13, 18, 0));
    expect(notificationService.shown, hasLength(2));
  });

  test('buildDigest composes break adherence, top focus category, and streak', () {
    final now = DateTime(2026, 9, 6, 18, 0);
    withClock(Clock.fixed(now), () {
      statsService.setWeeklyData([
        DailyStats(date: '2026-09-01', breaksCompleted: 4, breaksSkipped: 1, usageMinutes: 0),
        DailyStats(date: '2026-09-02', breaksCompleted: 3, breaksSkipped: 2, usageMinutes: 0),
      ]);
      focusSessionService.recordSession(
        FocusSession(
          category: AppCategory.coding,
          start: DateTime(2026, 9, 1, 9, 0),
          durationSeconds: 3600,
        ),
      );

      final digest = digestService.buildDigest(now: now);

      expect(digest.breaksCompleted, 7);
      expect(digest.breaksSkipped, 3);
      expect(digest.breakAdherenceRate, closeTo(0.7, 0.001));
      expect(digest.topFocusCategory, AppCategory.coding);
      expect(digest.longestDeepWorkSessionSeconds, 3600);
      expect(digest.companionMilestoneLabel, isNull);
    });
  });

  test('buildDigest includes days-over-budget when a category exceeds its budget', () {
    final now = DateTime(2026, 9, 6, 18, 0);
    withClock(Clock.fixed(now), () {
      final budgetedSettings = FakeSettingsRepository(
        storage,
        const SettingsModel(categoryDailyBudgetMinutes: {'browsing': 60}),
      );
      final digestWithBudget = WeeklyDigestService(
        storage: storage,
        statsService: statsService,
        focusSessionService: focusSessionService,
        streakService: streakService,
        notificationService: notificationService,
        usageService: usageService,
        settingsRepository: budgetedSettings,
      );
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      usageService.addUsageSeconds(
        date: dateKey,
        appKey: 'com.apple.safari',
        name: 'Safari',
        category: AppCategory.browsing,
        seconds: 90 * 60, // 90 min, over the 60-min budget
      );

      final digest = digestWithBudget.buildDigest(now: now);

      expect(digest.daysOverBudgetByCategory[AppCategory.browsing], 1);
    });
  });

  group('trailingAverageAdherenceRate (§7.3)', () {
    test('is null with fewer than 7 days of prior history', () {
      final now = DateTime(2026, 9, 6, 18, 0);
      statsService.setWeeklyData([
        DailyStats(date: '2026-08-25', breaksCompleted: 3, breaksSkipped: 1, usageMinutes: 0),
      ]);
      final digest = digestService.buildDigest(now: now);
      expect(digest.trailingAverageAdherenceRate, isNull);
    });

    test('averages breaks from days 8-35 back, excluding this week', () {
      final now = DateTime(2026, 9, 6, 18, 0);
      statsService.setWeeklyData([
        // This week (days 0-6 back) — must not be included in the average.
        DailyStats(date: '2026-09-06', breaksCompleted: 10, breaksSkipped: 0, usageMinutes: 0),
        // Trailing window (days 7-34 back): 7 days, 70% adherence.
        for (var i = 8; i < 15; i++)
          DailyStats(
            date: _dateKey(now.subtract(Duration(days: i))),
            breaksCompleted: 7,
            breaksSkipped: 3,
            usageMinutes: 0,
          ),
      ]);

      final digest = digestService.buildDigest(now: now);

      expect(digest.trailingAverageAdherenceRate, closeTo(0.7, 0.001));
    });
  });

  test('buildDigest has no budget data when nothing is configured', () {
    final digest = digestService.buildDigest(now: DateTime(2026, 9, 6, 18, 0));
    expect(digest.daysOverBudgetByCategory, isEmpty);
  });

  test('start() fires the digest once its periodic check crosses into the window', () {
    fakeAsync((async) {
      digestService.start();
      // Immediate check at construction time (Saturday) — too early.
      expect(notificationService.shown, isEmpty);

      // Advance past midnight Saturday->Sunday and up to 18:00 Sunday; the
      // 15-minute periodic check picks up the threshold once it's crossed.
      async.elapse(const Duration(hours: 30));

      expect(notificationService.shown, hasLength(1));
      digestService.stop();
    }, initialTime: DateTime(2026, 9, 5, 12, 0));
  });
}
