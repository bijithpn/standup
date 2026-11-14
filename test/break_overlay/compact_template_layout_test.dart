import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_skip_icon.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_draggable.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/overlay_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'break_test_harness.dart';

void main() {
  setUpAll(setUpBreakTestEnvironment);
  for (final id in ['quiet_pill', 'floating']) {
    testWidgets('$id reserves space between the countdown and skip', (
      tester,
    ) async {
      await pumpBreakTemplate(
        tester,
        id,
        size: const Size(380, 240),
        onSkip: () {},
      );
      final timer = tester.getRect(find.text('00:39'));
      final skip = tester.getRect(find.byType(BreakSkipIcon));
      expect(timer.overlaps(skip), isFalse);
      expect(skip.left - timer.right, greaterThanOrEqualTo(8));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$id thumbnail centers a legible compact widget', (
      tester,
    ) async {
      await pumpBreakTemplate(
        tester,
        id,
        size: const Size(380, 220),
        preview: true,
      );
      final draggable = tester.widget<BreakDraggable>(
        find.byType(BreakDraggable),
      );
      expect(draggable.initialAnchor, Alignment.center);
      final timer = tester.getRect(find.text('00:39'));
      expect(timer.width, greaterThan(30));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$id.thumbnail.png'),
      );
      expect(timer.center.dx, inInclusiveRange(30, 350));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('compact overlays omit shared dismiss controls and hints', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverlayChrome(
            compactControls: true,
            templateOwnsChrome: true,
            isInternalPreview: false,
            canDismiss: true,
            breakInfo: shortBreak,
            intensityLevel: 'standard',
            onSkip: () {},
            child: const SizedBox(),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Skip break'), findsNothing);
  });
}
