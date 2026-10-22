import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_icon_cache.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import '../../helpers/fake_calendar_sync_controller.dart';
import 'package:breakmate/features/settings/local_data_wiper.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/widgets/privacy_section.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

class _CountingSettingsRepository extends SettingsRepository {
  int loads = 0;
  _CountingSettingsRepository(StorageService storage) : super(storage: storage);

  @override
  Future<void> load() async => loads++;
}

void main() {
  late StorageService storage;
  late AppUsageService usage;
  late FocusSessionService focus;
  late _CountingSettingsRepository settingsRepo;

  setUp(() {
    SimplePrefs.instance.clear();
    storage = StorageService();
    usage = AppUsageService(storage: storage);
    focus = FocusSessionService(storage: storage);
    settingsRepo = _CountingSettingsRepository(storage);

    final today = DateTime.now();
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    usage.addUsageSeconds(
      date: date,
      appKey: 'com.apple.dt.xcode',
      name: 'Xcode',
      category: AppCategory.coding,
      seconds: 60,
    );
    focus.recordSession(
      FocusSession(
        category: AppCategory.coding,
        start: today,
        durationSeconds: 1500,
      ),
    );
    SimplePrefs.instance.setString('some_user_key', 'value');

    sl.registerSingleton<StorageService>(storage);
    sl.registerSingleton<AppUsageService>(usage);
    sl.registerSingleton<FocusSessionService>(focus);
    sl.registerSingleton<SettingsRepository>(settingsRepo);
    sl.registerSingleton<CalendarSyncController>(FakeCalendarSyncController());
    sl.registerLazySingleton<AppTrackingService>(() => AppTrackingService());
    sl.registerLazySingleton<AppIconCache>(
      () => AppIconCache(appTracking: sl()),
    );
  });

  tearDown(() async {
    SimplePrefs.instance.clear();
    await sl.reset();
  });

  test(
    'wipeAllLocalData clears usage, focus sessions, prefs and reloads',
    () async {
      expect(usage.topApps(UsagePeriod.today), isNotEmpty);
      expect(focus.sessionsForPeriod(UsagePeriod.today), isNotEmpty);

      await wipeAllLocalData();

      expect(usage.topApps(UsagePeriod.today), isEmpty);
      expect(focus.sessionsForPeriod(UsagePeriod.today), isEmpty);
      expect(SimplePrefs.instance.getString('some_user_key'), isEmpty);
      expect(settingsRepo.loads, 1);
      // Nothing is written back from memory after the wipe.
      expect(
        AppUsageService(storage: storage).topApps(UsagePeriod.today),
        isEmpty,
      );
    },
  );

  testWidgets('confirming Delete on the Privacy page performs the wipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangeNotifierProvider<AppUsageService>.value(
              value: usage,
              child: PrivacySection(settings: SettingsModel(), onSave: (_) {}),
            ),
          ),
        ),
      ),
    );

    final wipe = find.text('Delete…');
    await tester.ensureVisible(wipe);
    await tester.tap(wipe);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(settingsRepo.loads, 1);
    expect(usage.topApps(UsagePeriod.today), isEmpty);
    expect(focus.sessionsForPeriod(UsagePeriod.today), isEmpty);
  });
}
