import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/app_usage_tracker.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class MockAppTrackingService extends Mock implements AppTrackingService {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockActivityMonitor extends Mock implements ActivityMonitor {}

void main() {
  late MockAppTrackingService mockTracking;
  late MockSettingsRepository mockSettingsRepo;
  late MockActivityMonitor mockActivityMonitor;
  late AppUsageService usageService;
  late FocusSessionService focusSessionService;
  late AppUsageTracker tracker;

  setUp(() {
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
    SimplePrefs.instance.remove(AppConstants.keyFocusSessionData);
    mockTracking = MockAppTrackingService();
    mockSettingsRepo = MockSettingsRepository();
    mockActivityMonitor = MockActivityMonitor();
    usageService = AppUsageService(storage: StorageService());
    focusSessionService = FocusSessionService(storage: StorageService());
    tracker = AppUsageTracker(
      appTracking: mockTracking,
      usageService: usageService,
      settingsRepo: mockSettingsRepo,
      activityMonitor: mockActivityMonitor,
      focusSessionService: focusSessionService,
    );
  });

  tearDown(() {
    SimplePrefs.instance.remove(AppConstants.keyAppUsageData);
  });

  test('does nothing on a tick when tracking is disabled', () async {
    when(() => mockSettingsRepo.currentSettings).thenReturn(const SettingsModel());
    when(() => mockActivityMonitor.isIdle).thenReturn(false);

    await tracker.tickOnce();
    tracker.flushNow();

    final apps = usageService.topApps(UsagePeriod.today);
    expect(apps, isEmpty);
    verifyNever(() => mockTracking.getActiveApp());
  });

  test('does nothing on a tick when the user is idle', () async {
    when(() => mockSettingsRepo.currentSettings)
        .thenReturn(const SettingsModel(appUsageTrackingEnabled: true));
    when(() => mockActivityMonitor.isIdle).thenReturn(true);

    await tracker.tickOnce();
    tracker.flushNow();

    final apps = usageService.topApps(UsagePeriod.today);
    expect(apps, isEmpty);
    verifyNever(() => mockTracking.getActiveApp());
  });

  test('accumulates 10s for the active app and flushes it into AppUsageService', () async {
    when(() => mockSettingsRepo.currentSettings)
        .thenReturn(const SettingsModel(appUsageTrackingEnabled: true));
    when(() => mockActivityMonitor.isIdle).thenReturn(false);
    when(() => mockTracking.getActiveApp()).thenAnswer(
      (_) async => ActiveAppInfo(
        name: 'index.dart — Visual Studio Code',
        bundleId: 'com.microsoft.vscode',
        executableName: 'Code',
      ),
    );

    await tracker.tickOnce();
    await tracker.tickOnce();
    tracker.flushNow();

    final apps = usageService.topApps(UsagePeriod.today);
    expect(apps.length, 1);
    expect(apps.first.appKey, 'com.microsoft.vscode');
    expect(apps.first.seconds, 20);
    // Privacy: the stored name must come from the executable, never the
    // window title returned in ActiveAppInfo.name.
    expect(apps.first.name, 'Code');
  });

  test('records a focus session once 15 minutes of coding accumulate', () async {
    when(() => mockSettingsRepo.currentSettings)
        .thenReturn(const SettingsModel(appUsageTrackingEnabled: true));
    when(() => mockActivityMonitor.isIdle).thenReturn(false);
    when(() => mockTracking.getActiveApp()).thenAnswer(
      (_) async => ActiveAppInfo(
        name: 'index.dart — Visual Studio Code',
        bundleId: 'com.microsoft.vscode',
        executableName: 'Code',
      ),
    );

    final start = DateTime.now();
    // 90 ticks of 10s = 15 minutes, the minimum focus-session duration.
    for (var i = 0; i <= 90; i++) {
      await withClock(
        Clock.fixed(start.add(Duration(seconds: i * 10))),
        () => tracker.tickOnce(),
      );
    }
    // Switching to a non-focus app closes the open session.
    when(() => mockTracking.getActiveApp()).thenAnswer(
      (_) async => ActiveAppInfo(
        name: 'Safari',
        bundleId: 'com.apple.Safari',
        executableName: 'Safari',
      ),
    );
    await withClock(
      Clock.fixed(start.add(const Duration(seconds: 910))),
      () => tracker.tickOnce(),
    );

    final dateKey = '${start.year}-${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    expect(focusSessionService.sessionsForDate(dateKey), hasLength(1));
    expect(
      focusSessionService.focusSecondsForDate(dateKey),
      greaterThanOrEqualTo(15 * 60),
    );
  });

  test('stop() finalizes an in-progress focus session', () async {
    when(() => mockSettingsRepo.currentSettings)
        .thenReturn(const SettingsModel(appUsageTrackingEnabled: true));
    when(() => mockActivityMonitor.isIdle).thenReturn(false);
    when(() => mockTracking.getActiveApp()).thenAnswer(
      (_) async => ActiveAppInfo(
        name: 'Xcode',
        bundleId: 'com.apple.dt.Xcode',
        executableName: 'Xcode',
      ),
    );

    final start = DateTime.now();
    for (var i = 0; i <= 90; i++) {
      await withClock(
        Clock.fixed(start.add(Duration(seconds: i * 10))),
        () => tracker.tickOnce(),
      );
    }

    tracker.stop();

    final dateKey = '${start.year}-${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    expect(focusSessionService.sessionsForDate(dateKey), hasLength(1));
  });
}
