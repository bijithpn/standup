import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/widgets/goals_section.dart';

import '../../core/services/timer_engine_drift_test.dart'
    show FakeStorageService, MockCalendarService, MockSmartDetectionService;
import '../../helpers/in_memory_settings_repository.dart';

void main() {
  group('activeDaysThisWeek', () {
    final now = DateTime(2026, 3, 10); // Tuesday

    DailyStats day(String date, int completed) => DailyStats(
      date: date,
      breaksCompleted: completed,
      breaksSkipped: 0,
      usageMinutes: 0,
      wellnessActions: 0,
    );

    test('counts only days in the last 7 with a completed break', () {
      final weekly = [
        day('2026-03-10', 3),
        day('2026-03-09', 0),
        day('2026-03-08', 1),
        day('2026-03-04', 2), // 6 days back: inside
        day('2026-03-03', 5), // 7 days back: outside
        day('2026-02-01', 9),
      ];
      expect(GoalsSection.activeDaysThisWeek(weekly, now), 3);
    });

    test('works across a month boundary', () {
      final weekly = [day('2026-02-28', 1), day('2026-03-01', 1)];
      expect(GoalsSection.activeDaysThisWeek(weekly, DateTime(2026, 3, 3)), 2);
    });

    test('empty history is zero', () {
      expect(GoalsSection.activeDaysThisWeek(const [], now), 0);
    });
  });

  group('GoalsSection', () {
    late InMemorySettingsRepository settings;
    late StatsService stats;

    setUp(() async {
      await sl.reset();
      settings = InMemorySettingsRepository(
        const SettingsModel(
          dailyWorkGoalHours: 6,
          dailyBreakGoalCount: 8,
          weeklyConsistencyTargetDays: 5,
        ),
      );
      final storage = FakeStorageService();
      stats = StatsService(storage: storage);
      final calendar = MockCalendarService();
      final detection = MockSmartDetectionService();
      when(() => calendar.isMeetingActive()).thenAnswer((_) async => false);
      when(() => detection.isVideoCallActive).thenReturn(false);
      when(() => detection.isVideoPlaying).thenReturn(false);
      when(() => detection.isFocusModeActive).thenReturn(false);
      sl.registerSingleton<StorageService>(storage);
      sl.registerSingleton<TimerEngine>(
        TimerEngine(
          settingsRepository: settings,
          smartDetectionService: detection,
          calendarService: calendar as CalendarService,
          eventBus: EventBus.instance,
        ),
      );
    });

    tearDown(() async {
      sl<TimerEngine>().dispose();
      await sl.reset();
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider<SettingsRepository>.value(
                    value: settings,
                  ),
                  ChangeNotifierProvider<StatsService>.value(value: stats),
                ],
                child: const GoalsSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows only goals that have an implementation', (tester) async {
      await pump(tester);
      expect(find.text('Daily focus time'), findsOneWidget);
      expect(find.text('Daily breaks'), findsOneWidget);
      expect(find.text('Weekly consistency'), findsOneWidget);
      // Not enforced anywhere, so not offered.
      expect(find.text('Sitting Limit'), findsNothing);
      // Calendar Sync has its own screen.
      expect(find.text('Enable Calendar Sync'), findsNothing);
      expect(find.text('Calendar Integration'), findsNothing);
    });

    testWidgets('shows progress against each target', (tester) async {
      await pump(tester);
      expect(find.text('0m of 6h today'), findsOneWidget);
      expect(find.text('0 of 8 today'), findsOneWidget);
      expect(find.text('0 of 5 days'), findsOneWidget);
    });

    testWidgets('app time budgets explain why they are unavailable', (
      tester,
    ) async {
      await pump(tester);
      expect(find.textContaining('Turn it on in Privacy'), findsOneWidget);
    });

    testWidgets('dragging a slider saves the new target', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pump();
      expect(settings.currentSettings.dailyWorkGoalHours, isNot(6));
    });
  });
}
