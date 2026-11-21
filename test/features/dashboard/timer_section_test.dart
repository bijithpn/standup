import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    hide DailyStats;
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/timer_section.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import '../../core/services/timer_engine_drift_test.dart'
    show FakeStorageService;

class _Settings extends SettingsRepository {
  _Settings() : super(storage: FakeStorageService());
  @override
  SettingsModel get currentSettings => const SettingsModel();
}

class _Presentation extends PresentationDetectionService {
  _Presentation() : super(displayManager: DisplayManager());
}

void main() {
  late BreakController controller;
  late _Settings settings;

  setUp(() {
    settings = _Settings();
    controller = BreakController(
      timerEngine: TimerEngine(
        settingsRepository: settings,
        meetingDetectionService: MeetingDetectionService(),
        presentationDetectionService: _Presentation(),
        eventBus: EventBus.instance,
      ),
      settingsRepo: settings,
      statsService: StatsService(storage: FakeStorageService()),
    );
  });

  Future<void> pump(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(1100, 750);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BreakController>.value(value: controller),
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
            body: SingleChildScrollView(child: TimerSection()),
          ),
        ),
      ),
    );
  }

  for (final scale in [1.0, 1.5]) {
    testWidgets('hero shows countdown and pause at text scale $scale', (
      tester,
    ) async {
      await pump(tester, scale);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data ?? ''),
        ),
        findsOneWidget,
      );
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Take break now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
