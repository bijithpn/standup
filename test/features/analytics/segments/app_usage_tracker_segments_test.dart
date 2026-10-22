import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/app_usage_tracker.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_repository.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class MockAppTrackingService extends Mock implements AppTrackingService {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockActivityMonitor extends Mock implements ActivityMonitor {}

/// Captures what the tracker records, without needing a real ObjectBox store.
class RecordingSegmentRepository extends ActivitySegmentRepository {
  RecordingSegmentRepository() : super(storage: StorageService());

  final List<ActivitySegment> recorded = <ActivitySegment>[];

  @override
  void record(ActivitySegment segment) {
    if (segment.isValid) recorded.add(segment);
  }

  @override
  void flush() {}

  @override
  void applyRetention(int retentionDays, {DateTime? now}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAppTrackingService tracking;
  late MockSettingsRepository settings;
  late MockActivityMonitor activity;
  late RecordingSegmentRepository segments;
  late AppUsageTracker tracker;
  late EventBus eventBus;

  const enabled = SettingsModel(appUsageTrackingEnabled: true);

  setUp(() {
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
    tracking = MockAppTrackingService();
    settings = MockSettingsRepository();
    activity = MockActivityMonitor();
    segments = RecordingSegmentRepository();
    eventBus = EventBus.instance;

    tracker = AppUsageTracker(
      appTracking: tracking,
      usageService: AppUsageService(storage: StorageService()),
      settingsRepo: settings,
      activityMonitor: activity,
      segmentRepository: segments,
      eventBus: eventBus,
    );

    when(() => settings.currentSettings).thenReturn(enabled);
    when(() => activity.isIdle).thenReturn(false);
  });

  tearDown(() {
    tracker.stop();
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
  });

  void whenActiveApp(String bundleId, String executable) {
    when(() => tracking.getActiveApp()).thenAnswer(
      (_) async => ActiveAppInfo(
        name: executable,
        bundleId: bundleId,
        executableName: executable,
      ),
    );
  }

  Future<void> tickAt(DateTime at) async {
    await withClock(Clock.fixed(at), () => tracker.tickOnce());
  }

  final start = DateTime(2026, 9, 20, 9);

  test('records a segment when the active app changes', () async {
    whenActiveApp('com.microsoft.VSCode', 'Code.exe');
    await tickAt(start);
    await tickAt(start.add(const Duration(seconds: 10)));

    whenActiveApp('com.google.Chrome', 'chrome.exe');
    await tickAt(start.add(const Duration(seconds: 20)));

    expect(segments.recorded, hasLength(1));
    final segment = segments.recorded.single;
    expect(segment.appName, 'Code');
    expect(segment.categoryName, 'coding');
    expect(segment.seconds, 20);
    expect(segment.activityKind, ActivityKind.active);
  });

  test('staying in one app records nothing until it ends', () async {
    whenActiveApp('com.microsoft.VSCode', 'Code.exe');
    await tickAt(start);
    await tickAt(start.add(const Duration(seconds: 10)));
    await tickAt(start.add(const Duration(seconds: 20)));

    expect(segments.recorded, isEmpty);
  });

  test('idle time is recorded rather than dropped', () async {
    whenActiveApp('com.microsoft.VSCode', 'Code.exe');
    await tickAt(start);

    when(() => activity.isIdle).thenReturn(true);
    await tickAt(start.add(const Duration(seconds: 10)));

    // The active stretch closed when idle began.
    expect(segments.recorded, hasLength(1));
    expect(segments.recorded.single.activityKind, ActivityKind.active);

    when(() => activity.isIdle).thenReturn(false);
    await tickAt(start.add(const Duration(seconds: 30)));

    expect(segments.recorded, hasLength(2));
    final idle = segments.recorded.last;
    expect(idle.activityKind, ActivityKind.idle);
    expect(idle.seconds, 20);
    expect(idle.appKey, isEmpty);
  });

  test('a break is bracketed on the timeline', () async {
    whenActiveApp('com.microsoft.VSCode', 'Code.exe');
    await tickAt(start);

    tracker.start();
    addTearDown(tracker.stop);

    // Events carry their own timestamp, and the tracker must use it — the
    // listener runs some time after the break actually began.
    eventBus.emit(
      BreakStartedEvent(
        isLongBreak: false,
        durationSeconds: 300,
        title: 'Stretch',
        timestamp: start.add(const Duration(seconds: 10)),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    eventBus.emit(
      BreakEndedEvent(
        skipped: false,
        timestamp: start.add(const Duration(seconds: 70)),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final kinds = segments.recorded.map((s) => s.activityKind).toList();
    expect(kinds, contains(ActivityKind.onBreak));

    final onBreak = segments.recorded.firstWhere(
      (s) => s.activityKind == ActivityKind.onBreak,
    );
    expect(onBreak.seconds, 60);
  });

  test('records nothing at all while tracking is disabled', () async {
    when(() => settings.currentSettings).thenReturn(const SettingsModel());
    whenActiveApp('com.microsoft.VSCode', 'Code.exe');

    await tickAt(start);
    await tickAt(start.add(const Duration(seconds: 10)));

    expect(segments.recorded, isEmpty);
  });

  test('BreakMate watching itself is never recorded', () async {
    whenActiveApp('com.bijith.breakmate.dev', 'BreakMate.exe');
    await tickAt(start);
    await tickAt(start.add(const Duration(seconds: 10)));

    expect(segments.recorded, isEmpty);
  });

  test('stopping closes the open stretch', () async {
    whenActiveApp('com.microsoft.VSCode', 'Code.exe');
    await tickAt(start);

    withClock(
      Clock.fixed(start.add(const Duration(seconds: 40))),
      tracker.stop,
    );

    expect(segments.recorded, hasLength(1));
    expect(segments.recorded.single.seconds, 40);
  });

  test('daily totals keep working alongside segments', () async {
    whenActiveApp('com.microsoft.VSCode', 'Code.exe');
    await tickAt(start);

    // The existing aggregate path is untouched by the segment recording, so
    // upgrading does not lose the usage history users already have.
    expect(() => tracker.flushNow(), returnsNormally);
  });
}
