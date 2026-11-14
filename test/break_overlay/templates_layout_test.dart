import 'package:breakmate/features/break_overlay/presentation/templates/clock_face_template.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/overlay_chrome.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

void main() {
  setUpAll(setUpBreakTestEnvironment);

  group('extreme window sizes do not overflow', () {
    for (final id in ['hud', 'clock_face', 'haiku_card']) {
      for (final size in const [Size(320, 200), Size(3840, 2160)]) {
        testWidgets('$id @ ${size.width.toInt()}x${size.height.toInt()}', (
          tester,
        ) async {
          await pumpBreakTemplate(tester, id, size: size, onSkip: () {});
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  });

  testWidgets('haiku_card renders at 2x pixel ratio', (tester) async {
    // The poem is chosen by time of day, so pin the clock.
    await withClock(Clock.fixed(DateTime(2026, 3, 14, 14, 5)), () async {
      await pumpBreakTemplate(tester, 'haiku_card', onSkip: () {});
      tester.view.devicePixelRatio = 2.0;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/haiku_card.2x.png'),
      );
    });
  });

  testWidgets('clock_face keeps its clock clear of the chrome at 4K', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 3, 14, 14, 5)), () async {
      tester.view.physicalSize = const Size(3840, 2160);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverlayChrome(
              templateOwnsChrome: false,
              isInternalPreview: false,
              canDismiss: true,
              breakInfo: shortBreak,
              intensityLevel: 'standard',
              onSkip: () {},
              child: ClockFaceTemplate(
                breakInfo: shortBreak,
                settings: const SettingsModel(),
                remainingSeconds: 39,
                totalSeconds: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      final clock = tester.getRect(find.text('14:05'));
      final pill = tester.getRect(find.byType(BreakContextPill));
      final close = tester.getRect(find.byTooltip('Skip break'));
      expect(clock.overlaps(pill), isFalse);
      expect(clock.overlaps(close), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
