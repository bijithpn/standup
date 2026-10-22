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

  testWidgets('Statistics is one page: every section is on the same screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    await tester.pumpAndSettle();

    // No tabs to switch between: all the groups are present at once.
    for (final heading in ['Overview', 'Focus', 'Breaks']) {
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
    // Time and app usage are on the Productivity screen, not repeated here.
    expect(find.text('Where your time goes'), findsNothing);
    // Focus is the longest block, so it starts folded.
    expect(find.text('Focus Score'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Focus Score'), findsOneWidget);
    expect(find.text('Break Statistics'), findsOneWidget);
    expect(find.text('Current Streak'), findsWidgets);
    // One period selector for the whole page.
    expect(find.text('This Week'), findsOneWidget);
  });

  // Layout overflow shows up as a test failure, so render the page at the
  // widths the window can actually have.
  for (final width in [420.0, 700.0, 1100.0]) {
    testWidgets('Statistics lays out without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
                  settings: const SettingsModel(
                    appUsageTrackingEnabled: true,
                    categoryDailyBudgetMinutes: {'coding': 120},
                  ),
                  onSave: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Unfold the longest block too, so it is checked for overflow as well.
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
