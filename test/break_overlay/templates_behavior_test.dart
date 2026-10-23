import 'package:breakmate/features/break_overlay/presentation/templates/time_slice_template.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

void main() {
  setUpAll(setUpBreakTestEnvironment);

  // wind_down has no skip: it closes through its own "Done for today" button.
  final skippable = allBreakTemplateIds.where((id) => id != 'wind_down');

  group('Esc triggers skip', () {
    for (final id in skippable) {
      testWidgets(id, (tester) async {
        var skipped = 0;
        await pumpBreakTemplate(tester, id, onSkip: () => skipped++);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(skipped, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('Esc does nothing in strict mode', () {
    for (final id in ['minimal', 'zen', 'floating']) {
      testWidgets(id, (tester) async {
        var skipped = 0;
        await pumpBreakTemplate(
          tester,
          id,
          settings: const SettingsModel(strictMode: true),
          onSkip: () => skipped++,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(skipped, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('skip control is announced as "Skip break"', () {
    // Templates that draw the kit's skip button or icon.
    const withSkip = [
      'minimal',
      'zen',
      'breathe_line',
      'one_word',
      'pulse_dot',
      'focus_orb',
      'wave_calm',
      'ring_only',
      'soft_arc',
      'classic',
      'hud',
      'clock_face',
      'mono_time',
      'time_slice',
      'day_stack',
      'split_view',
      'step_guide',
      'haiku_card',
      'open_field',
      'dusk_glow',
      'paper_light',
      'activities',
      'iris_rest',
      'companion',
      'floating',
      'quiet_pill',
    ];
    for (final id in withSkip) {
      testWidgets(id, (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBreakTemplate(tester, id, onSkip: () {});
        // The floating pill only reveals its skip icon when expanded.
        if (id == 'quiet_pill') {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(tester.getCenter(find.text('EYE REST')));
          await tester.pump(); // starts the expand spring
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.bySemanticsLabel('Skip break'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        handle.dispose();
      });
    }
  });

  group('countdown shows the remaining time', () {
    for (final id in allBreakTemplateIds) {
      testWidgets(id, (tester) async {
        await pumpBreakTemplate(tester, id, remaining: 39, total: 60);
        if (id == 'wind_down') {
          // No countdown: this screen is untimed.
          expect(find.textContaining('00:39'), findsNothing);
        } else {
          expect(find.textContaining('00:39'), findsWidgets);
        }
        await pumpBreakTemplate(tester, id, remaining: 7, total: 60);
        if (id != 'wind_down') {
          expect(find.textContaining('00:07'), findsWidgets);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  testWidgets('Zen Mode follows its 4-4-4-4 breathing preset', (tester) async {
    await pumpBreakTemplate(tester, 'zen');
    // pumpBreakTemplate already advanced 2s of the first inhale.
    expect(find.text('Breathe in'), findsOneWidget);

    Future<void> advanceTo(double seconds, double from) async {
      await tester.pump(
        Duration(milliseconds: ((seconds - from) * 1000).round()),
      );
      await tester.pump(const Duration(milliseconds: 400)); // cross-fade
    }

    // 2s elapsed so far; sample each phase well inside its window.
    await advanceTo(6, 2); // 4-8s: hold
    expect(find.text('Hold'), findsOneWidget);
    await advanceTo(10, 6.4); // 8-12s: breathe out
    expect(find.text('Breathe out'), findsOneWidget);
    await advanceTo(14, 10.4); // 12-16s: hold
    expect(find.text('Hold'), findsOneWidget);
    await advanceTo(18.4, 14.4); // wraps: breathe in
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('Time Slice segment count matches the break duration', () {
    test('one slice per 5 seconds, between 1 and 24', () {
      expect(TimeSliceTemplate.segmentCountFor(20), 4);
      expect(TimeSliceTemplate.segmentCountFor(60), 12);
      expect(TimeSliceTemplate.segmentCountFor(7), 2);
      expect(TimeSliceTemplate.segmentCountFor(1), 1);
      expect(TimeSliceTemplate.segmentCountFor(300), 24);
      expect(TimeSliceTemplate.segmentCountFor(120), 24);
    });

    for (final c in const [(60, 12), (20, 4), (300, 24)]) {
      testWidgets('${c.$1}s break -> ${c.$2} segments', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBreakTemplate(
          tester,
          'time_slice',
          remaining: c.$1,
          total: c.$1,
        );
        expect(
          find.bySemanticsLabel(
            RegExp('^${c.$2} of ${c.$2} segments remaining'),
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        handle.dispose();
      });
    }
  });
}
