import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/daily_summary_section.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import '../../core/services/timer_engine_drift_test.dart'
    show FakeStorageService, MockCalendarService, MockSmartDetectionService;
import '../../helpers/in_memory_settings_repository.dart';

void main() {
  late FakeStorageService storage;
  late InMemorySettingsRepository settings;
  late StatsService stats;
  late BreakHistoryService history;

  setUp(() async {
    await sl.reset();
    storage = FakeStorageService();
    settings = InMemorySettingsRepository(
      const SettingsModel(dailyBreakGoalCount: 4),
    );
    stats = StatsService(storage: storage);
    history = BreakHistoryService(storage: storage);
    final calendar = MockCalendarService();
    final detection = MockSmartDetectionService();
    when(() => calendar.isMeetingActive()).thenAnswer((_) async => false);
    when(() => detection.isVideoCallActive).thenReturn(false);
    when(() => detection.isVideoPlaying).thenReturn(false);
    sl.registerSingleton<StorageService>(storage);
    sl.registerSingleton<TimerEngine>(
      TimerEngine(
        settingsRepository: settings,
        smartDetectionService: detection,
        calendarService: calendar,
        eventBus: EventBus.instance,
      ),
    );
  });

  tearDown(() async {
    sl<TimerEngine>().dispose();
    await sl.reset();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StatsService>.value(value: stats),
          ChangeNotifierProvider<BreakHistoryService>.value(value: history),
          ChangeNotifierProvider<SettingsRepository>.value(value: settings),
          ChangeNotifierProvider<ContextSwitchTracker>(
            create: (_) => ContextSwitchTracker(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DailySummarySection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty day: explains and shows the goal at zero', (tester) async {
    await pump(tester);
    expect(find.text('Break activity'), findsOneWidget);
    expect(find.text('0 / 4 breaks'), findsOneWidget);
    expect(find.textContaining('No breaks yet today'), findsOneWidget);
  });

  testWidgets('shows today\'s breaks on a timeline and progress to the goal', (
    tester,
  ) async {
    final now = clock.now();
    final morning = DateTime(now.year, now.month, now.day, 0, 5);
    history.recordBreak(time: morning, completed: true);
    history.recordBreak(
      time: morning.add(const Duration(minutes: 1)),
      completed: false,
    );
    stats.recordCompletedBreak();
    stats.recordCompletedBreak();
    stats.recordSkippedBreak();
    stats.flush();
    await tester.pump();

    await pump(tester);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.text('00:05'), findsOneWidget);
    expect(find.text('2 / 4 breaks'), findsOneWidget);
  });

  testWidgets('reaching the goal is celebrated', (tester) async {
    for (var i = 0; i < 4; i++) {
      stats.recordCompletedBreak();
    }
    stats.flush();
    await pump(tester);
    expect(find.textContaining('Goal reached'), findsOneWidget);
  });
}
