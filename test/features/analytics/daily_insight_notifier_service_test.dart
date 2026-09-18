// Coverage for the daily proactive insight (plan doc §7.5) — the single
// highest-priority OverviewInsight, delivered once/day via a local
// notification, gated the same way FocusInsightService gates its one-shot
// correlation notification.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/daily_insight_notifier_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InMemoryStorageService extends FakeStorageService {
  final Map<String, String> _strings = {};

  @override
  String getString(String key, {String defaultValue = ''}) =>
      _strings[key] ?? defaultValue;

  @override
  Future<bool> setString(String key, String value) async {
    _strings[key] = value;
    return true;
  }

  @override
  int getInt(String key, {int defaultValue = 0}) => defaultValue;

  @override
  Future<bool> setInt(String key, int value) async => true;
}

class FakeSettingsRepository extends SettingsRepository {
  final SettingsModel _fakeSettings;

  FakeSettingsRepository(StorageService storage, [SettingsModel? settings])
    : _fakeSettings = settings ?? const SettingsModel(),
      super(storage: storage);

  @override
  SettingsModel get currentSettings => _fakeSettings;
}

class FakeNotificationService extends NotificationService {
  final List<String> shown = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showDailyInsight(String text) async {
    shown.add(text);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryStorageService storage;
  late AppUsageService usageService;
  late FocusSessionService focusSessionService;
  late BreakHistoryService breakHistoryService;
  late FocusStreakService streakService;
  late SettingsRepository settingsRepository;
  late FakeNotificationService notificationService;
  late DailyInsightNotifierService service;
  final ipcChannel = const MethodChannel('com.breakmate/ipc');
  final List<MethodCall> ipcCalls = [];

  setUp(() {
    ipcCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ipcChannel, (call) async {
          ipcCalls.add(call);
          return null;
        });
    storage = InMemoryStorageService();
    usageService = AppUsageService(storage: storage);
    focusSessionService = FocusSessionService(storage: storage);
    breakHistoryService = BreakHistoryService(storage: storage);
    streakService = FocusStreakService(
      focusSessionService: focusSessionService,
      usageService: usageService,
      storage: storage,
      eventBus: EventBus.instance,
    );
    settingsRepository = FakeSettingsRepository(storage);
    notificationService = FakeNotificationService();
    service = DailyInsightNotifierService(
      storage: storage,
      usageService: usageService,
      focusSessionService: focusSessionService,
      breakHistoryService: breakHistoryService,
      streakService: streakService,
      settingsRepository: settingsRepository,
      notificationService: notificationService,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ipcChannel, null);
  });

  test('shows nothing when there is no insight to surface', () {
    service.checkAndMaybeShow(now: DateTime(2026, 9, 6));
    expect(notificationService.shown, isEmpty);
  });

  test('shows the top insight once there is one', () {
    final now = DateTime(2026, 9, 6);
    // 4 of 6 breaks skipped this week — crosses the skip-rate threshold.
    for (var i = 0; i < 4; i++) {
      breakHistoryService.recordBreak(
        time: now.subtract(Duration(days: i)),
        completed: false,
      );
    }
    for (var i = 4; i < 6; i++) {
      breakHistoryService.recordBreak(
        time: now.subtract(Duration(days: i)),
        completed: true,
      );
    }

    service.checkAndMaybeShow(now: now);

    expect(notificationService.shown, hasLength(1));
    expect(notificationService.shown.single, contains('skipped'));
  });

  test(
    'also relays the top insight to the companion window over IPC',
    () async {
      final now = DateTime(2026, 9, 6);
      for (var i = 0; i < 4; i++) {
        breakHistoryService.recordBreak(
          time: now.subtract(Duration(days: i)),
          completed: false,
        );
      }
      for (var i = 4; i < 6; i++) {
        breakHistoryService.recordBreak(
          time: now.subtract(Duration(days: i)),
          completed: true,
        );
      }

      service.checkAndMaybeShow(now: now);
      await Future<void>.delayed(Duration.zero);

      expect(ipcCalls, hasLength(1));
      expect(ipcCalls.single.method, 'sendEvent');
      final args = ipcCalls.single.arguments as Map;
      expect(args['event'], 'companion.interaction');
      final data = args['data'] as Map;
      expect(data['interactionType'], 'speech');
      expect((data['metadata'] as Map)['text'], contains('skipped'));
    },
  );

  test('does not show twice on the same day', () {
    final now = DateTime(2026, 9, 6);
    for (var i = 0; i < 4; i++) {
      breakHistoryService.recordBreak(
        time: now.subtract(Duration(days: i)),
        completed: false,
      );
    }
    for (var i = 4; i < 6; i++) {
      breakHistoryService.recordBreak(
        time: now.subtract(Duration(days: i)),
        completed: true,
      );
    }

    service.checkAndMaybeShow(now: now);
    service.checkAndMaybeShow(now: now.add(const Duration(hours: 2)));

    expect(notificationService.shown, hasLength(1));
  });

  test('shows again the following day', () {
    final day1 = DateTime(2026, 9, 6);
    for (var i = 0; i < 4; i++) {
      breakHistoryService.recordBreak(
        time: day1.subtract(Duration(days: i)),
        completed: false,
      );
    }
    for (var i = 4; i < 6; i++) {
      breakHistoryService.recordBreak(
        time: day1.subtract(Duration(days: i)),
        completed: true,
      );
    }

    service.checkAndMaybeShow(now: day1);
    service.checkAndMaybeShow(now: day1.add(const Duration(days: 1)));

    expect(notificationService.shown, hasLength(2));
  });
}
