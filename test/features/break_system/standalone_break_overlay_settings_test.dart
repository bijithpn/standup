import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

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
}
