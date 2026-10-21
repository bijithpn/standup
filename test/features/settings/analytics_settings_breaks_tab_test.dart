import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';
import 'package:breakmate/features/analytics/focus_streak_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/companion/services/companion_streak_service.dart';
import 'package:breakmate/features/settings/presentation/sections/analytics_settings_section.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

void main() {
  // The Overview tab (the default) now renders an Insights card that reads
  // AppUsageService/FocusSessionService/BreakHistoryService via Provider and
  // FocusStreakService/CompanionStreakService (the Habits summary card) via
  // GetIt — register real, un-initialized instances (their storage calls go
  // through SimplePrefs, no ObjectBox init needed) so the widget can build
  // before the test taps over to the Breaks tab.
  late StorageService storage;

  setUp(() {
    storage = StorageService();
    sl.registerSingleton<AppUsageService>(AppUsageService(storage: storage));
    sl.registerSingleton<FocusSessionService>(
      FocusSessionService(storage: storage),
    );
    sl.registerSingleton<BreakHistoryService>(
      BreakHistoryService(storage: storage),
    );
    sl.registerSingleton<FocusStreakService>(
      FocusStreakService(
        focusSessionService: sl(),
        usageService: sl(),
        storage: storage,
        eventBus: EventBus.instance,
      ),
    );
    sl.registerSingleton<StatsService>(StatsService(storage: storage));
    sl.registerSingleton<CompanionStreakService>(
      CompanionStreakService(
        statsService: sl(),
        storage: storage,
        eventBus: EventBus.instance,
      ),
    );
  });

  tearDown(() {
    sl.unregister<CompanionStreakService>();
    sl.unregister<StatsService>();
    sl.unregister<FocusStreakService>();
    sl.unregister<BreakHistoryService>();
    sl.unregister<FocusSessionService>();
    sl.unregister<AppUsageService>();
  });

  testWidgets('selecting the Breaks tab shows the break statistics section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sl<AppUsageService>()),
          ChangeNotifierProvider.value(value: sl<FocusSessionService>()),
          ChangeNotifierProvider.value(value: sl<BreakHistoryService>()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsSettingsSection(
                stats: const StatsModel(currentStreak: 2, longestStreak: 5),
                settings: const SettingsModel(),
                onSave: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Breaks'));
    await tester.pumpAndSettle();

    expect(find.text('Break Statistics'), findsOneWidget);
    expect(find.text('Current Streak'), findsOneWidget);
  });
}
