import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
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

  setUp(() async {
    await sl.reset();
    storage = FakeStorageService();
    settings = InMemorySettingsRepository(
      const SettingsModel(dailyBreakGoalCount: 4),
    );
    stats = StatsService(storage: storage);
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

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StatsService>.value(value: stats),
          ChangeNotifierProvider<SettingsRepository>.value(value: settings),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: DailySummarySection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty day: shows zero breaks against the goal', (tester) async {
    await pump(tester);
    expect(find.text('Breaks today'), findsOneWidget);
    expect(find.text('0 / 4 breaks'), findsOneWidget);
    expect(find.text('Focus time'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
  });

  testWidgets('shows today\'s completed breaks against the goal', (
    tester,
  ) async {
    stats.recordCompletedBreak();
    stats.recordCompletedBreak();
    stats.recordSkippedBreak();
    stats.flush();
    await pump(tester);
    expect(find.text('2 / 4 breaks'), findsOneWidget);
  });

  testWidgets('lays out without overflow at 150 percent text', (tester) async {
    stats.recordCompletedBreak();
    stats.flush();
    await pump(tester, scale: 1.5);
    expect(tester.takeException(), isNull);
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
