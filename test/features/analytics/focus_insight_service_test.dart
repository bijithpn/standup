import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_insight_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

class InMemoryStorageService extends FakeStorageService {
  final Map<String, bool> _bools = {};
  final Map<String, String> _strings = {};

  @override
  bool getBool(String key, {bool defaultValue = false}) =>
      _bools[key] ?? defaultValue;

  @override
  Future<bool> setBool(String key, bool value) async {
    _bools[key] = value;
    return true;
  }

  @override
  String getString(String key, {String defaultValue = ''}) =>
      _strings[key] ?? defaultValue;

  @override
  Future<bool> setString(String key, String value) async {
    _strings[key] = value;
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

class FakeNotificationService extends NotificationService {
  final List<BreakFocusCorrelation> shown = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showFocusCorrelationInsight(BreakFocusCorrelation correlation) async {
    shown.add(correlation);
  }
}

void main() {
  late InMemoryStorageService storage;
  late BreakHistoryService breakHistoryService;
  late FocusSessionService focusSessionService;
  late FakeNotificationService notificationService;
  late FocusInsightService insightService;

  setUp(() {
    storage = InMemoryStorageService();
    breakHistoryService = BreakHistoryService(storage: storage);
    focusSessionService = FocusSessionService(storage: storage);
    notificationService = FakeNotificationService();
    insightService = FocusInsightService(
      storage: storage,
      breakHistoryService: breakHistoryService,
      focusSessionService: focusSessionService,
      notificationService: notificationService,
    );
  });

  test('does nothing without enough data', () {
    insightService.checkAndMaybeShow(now: DateTime(2026, 9, 6));
    expect(notificationService.shown, isEmpty);
  });

  test('does nothing when the gap is negligible', () {
    final t = DateTime(2026, 9, 6, 9, 0);
    breakHistoryService.recordBreak(time: t, completed: true);
    breakHistoryService.recordBreak(
      time: t.add(const Duration(hours: 2)),
      completed: false,
    );
    // Same focus coverage after both -> ~0 point gap.
    focusSessionService.recordSession(
      FocusSession(category: AppCategory.coding, start: t, durationSeconds: 1800),
    );
    focusSessionService.recordSession(
      FocusSession(
        category: AppCategory.coding,
        start: t.add(const Duration(hours: 2)),
        durationSeconds: 1800,
      ),
    );

    insightService.checkAndMaybeShow(now: t.add(const Duration(hours: 3)));

    expect(notificationService.shown, isEmpty);
  });

  test('shows once there is enough data and a meaningful gap', () {
    final t = DateTime(2026, 9, 6, 9, 0);
    breakHistoryService.recordBreak(time: t, completed: true);
    breakHistoryService.recordBreak(
      time: t.add(const Duration(hours: 2)),
      completed: false,
    );
    // Full focus coverage after the completed break, none after the skipped one.
    focusSessionService.recordSession(
      FocusSession(category: AppCategory.coding, start: t, durationSeconds: 3600),
    );

    insightService.checkAndMaybeShow(now: t.add(const Duration(hours: 3)));

    expect(notificationService.shown, hasLength(1));
    expect(storage.getBool(AppConstants.keyFocusInsightShown), isTrue);
  });

  test('never shows twice, even if checked again later', () {
    final t = DateTime(2026, 9, 6, 9, 0);
    breakHistoryService.recordBreak(time: t, completed: true);
    breakHistoryService.recordBreak(
      time: t.add(const Duration(hours: 2)),
      completed: false,
    );
    focusSessionService.recordSession(
      FocusSession(category: AppCategory.coding, start: t, durationSeconds: 3600),
    );

    final now = t.add(const Duration(hours: 3));
    insightService.checkAndMaybeShow(now: now);
    insightService.checkAndMaybeShow(now: now);

    expect(notificationService.shown, hasLength(1));
  });
}
