import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    hide DailyStats;
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_system/presentation/standalone_break_overlay.dart';

import 'standalone_break_overlay_test.dart' show FakeStatsService;

/// Drives the real overlay widget with the native bridge mocked, the closest
/// thing to the running app that `flutter test` offers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sl = GetIt.instance;
  const bridge = MethodChannel('com.breakmate.desktop/bridge');
  final calls = <MethodCall>[];

  void serve(Map<String, Object?> overlayData) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          calls.add(call);
          return call.method == 'getOverlayData' ? overlayData : null;
        });
  }

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StandaloneBreakOverlay()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Map<String, Object?> shortBreak({
    Map<String, Object?> extra = const {},
    int endsInMs = 600000,
  }) => {
    'title': 'Eye Rest',
    'breakType': 'short',
    'tip': 'Look 20 feet away.',
    'durationSeconds': 20,
    'remainingSeconds': 20,
    'targetEndTime': DateTime.now()
        .add(Duration(milliseconds: endsInMs))
        .millisecondsSinceEpoch,
    'enableAnimations': false,
    'breakTemplate': 'minimal',
    ...extra,
  };

  setUp(() {
    calls.clear();
    sl.allowReassignment = true;
    sl.registerSingleton<StatsService>(FakeStatsService());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
    await sl.reset();
  });

  group('break screen theme', () {
    for (final (mode, expected) in [
      ('dark', BreakPalette.dark),
      ('light', BreakPalette.light),
    ]) {
      testWidgets('$mode data gives a $mode overlay', (tester) async {
        serve(shortBreak(extra: {'overlayThemeMode': mode}));
        await show(tester);
        final scope = tester.widget<BreakPaletteScope>(
          find.byType(BreakPaletteScope).first,
        );
        expect(scope.palette, expected);
        // The window behind the template matches, so no black frame shows.
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(FadeTransition).first,
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, expected.canvas);
      });
    }

    testWidgets('system follows the OS brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      serve(shortBreak(extra: {'overlayThemeMode': 'system'}));
      await show(tester);
      expect(
        tester
            .widget<BreakPaletteScope>(find.byType(BreakPaletteScope).first)
            .palette,
        BreakPalette.light,
      );
    });
  });

  group('"I looked away" button', () {
    testWidgets('is hidden unless the setting is on', (tester) async {
      serve(shortBreak());
      await show(tester);
      expect(find.text('I looked away'), findsNothing);
    });

    testWidgets('is hidden on long breaks', (tester) async {
      serve(
        shortBreak(
          extra: {'lookedAwayPromptEnabled': true, 'breakType': 'long'},
        ),
      );
      await show(tester);
      expect(find.text('I looked away'), findsNothing);
    });

    testWidgets('shows on eye-rest breaks and confirms on tap', (tester) async {
      serve(shortBreak(extra: {'lookedAwayPromptEnabled': true}));
      await show(tester);
      expect(find.text('I looked away'), findsOneWidget);
      await tester.tap(find.text('I looked away'));
      await tester.pump();
      expect(find.text('Looked away'), findsOneWidget);
    });

    for (final tapped in [true, false]) {
      testWidgets(
        'a break that runs out reports lookedAway=$tapped to the main app',
        (tester) async {
          serve(
            shortBreak(
              extra: {'lookedAwayPromptEnabled': true},
              endsInMs: 1900,
            ),
          );
          await show(tester);
          if (tapped) {
            await tester.tap(find.text('I looked away'));
            await tester.pump();
          }
          // The overlay measures the countdown against the wall clock but ticks
          // on a (fake) timer: let real time pass, then tick, then run the
          // 400 ms completion hold and the dismiss timer.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1100)),
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 3));
          final done = calls.where((c) => c.method == 'completeBreak');
          expect(done, hasLength(1));
          expect(done.single.arguments, {'lookedAway': tapped});
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets('skipping does not report a completion', (tester) async {
      serve(shortBreak(extra: {'lookedAwayPromptEnabled': true}));
      await show(tester);
      await tester.tap(find.text('I looked away'));
      await tester.tap(find.byTooltip('Skip break'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(calls.any((c) => c.method == 'completeBreak'), isFalse);
      expect(calls.any((c) => c.method == 'skipBreak'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a quick reminder never shows the looked-away button', (
    tester,
  ) async {
    serve({
      'overlayType': 'quickReminder',
      'reminderType': 'posture',
      'lookedAwayPromptEnabled': true,
      'durationSeconds': 2,
      'remainingSeconds': 2,
    });
    await show(tester);
    expect(find.text('I looked away'), findsNothing);
    // Let the reminder's own auto-dismiss timer run out.
    await tester.pump(AppConstants.healthReminderDismissDuration);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
