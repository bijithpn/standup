import 'dart:io';
import 'dart:ui' as ui;

import 'package:breakmate/features/break_overlay/presentation/templates/dusk_glow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/soft_floating_widget_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/time_slice_template.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_draggable.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/eye_sync_game_widget.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/guided_breathing_widget.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_glass.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/breath_preset.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

void main() {
  setUpAll(setUpBreakTestEnvironment);

  test('evening tint ramps from 18:00 to 21:00 and holds until 06:00', () {
    expect(breakEveningTint(DateTime(2026, 1, 1, 14)), 0);
    expect(breakEveningTint(DateTime(2026, 1, 1, 18)), 0);
    expect(breakEveningTint(DateTime(2026, 1, 1, 19, 30)), closeTo(0.3, 1e-9));
    expect(breakEveningTint(DateTime(2026, 1, 1, 21)), closeTo(0.6, 1e-9));
    expect(breakEveningTint(DateTime(2026, 1, 1, 3)), closeTo(0.6, 1e-9));
    expect(breakEveningTint(DateTime(2026, 1, 1, 7)), 0);
  });

  testWidgets('quiet_pill: Enter pins the tip open until Enter again', (
    tester,
  ) async {
    Future<void> settle() => tester.pump(const Duration(milliseconds: 600));
    await pumpBreakTemplate(tester, 'quiet_pill');
    expect(find.text(shortBreak.tip), findsNothing);

    // Focus the pill and press Enter: pinned.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle();
    expect(find.text(shortBreak.tip), findsOneWidget);

    // Losing focus keeps it open: only the pin holds it now.
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    expect(find.text(shortBreak.tip), findsOneWidget);

    // Enter again (refocus first) unpins; after blur it collapses.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    expect(find.text(shortBreak.tip), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('activities', () {
    testWidgets('golden: short break shows Eye sync', (tester) async {
      EyeSyncGameWidget.randomFactory = () => math.Random(7);
      addTearDown(() => EyeSyncGameWidget.randomFactory = null);
      await pumpBreakTemplate(
        tester,
        'activities',
        preview: true,
        onSkip: () {},
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/activities.eye_sync.png'),
      );
    });

    testWidgets('arrow keys switch tabs', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBreakTemplate(tester, 'activities', breakInfo: longBreak);
      await tester.tap(find.text('Eye sync'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(GuidedBreathingWidget), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(EyeSyncGameWidget), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    });
  });

  testWidgets('activities: breathing ring announces its progress', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpBreakTemplate(tester, 'activities', breakInfo: longBreak);
    expect(
      find.semantics.byPredicate(
        (n) =>
            n.label.contains('Breathing phase') &&
            RegExp(r'\d+ percent complete').hasMatch(n.value),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });

  group('floating card anchors', () {
    testWidgets('snaps to each of the six anchors', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final landed = <Alignment>[];
      await tester.pumpWidget(
        MaterialApp(
          home: BreakDraggable(
            animateEntrance: false,
            onAnchorChanged: landed.add,
            child: const SizedBox(key: Key('card'), width: 200, height: 80),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final a in breakSixAnchors) {
        // Drag the card's centre onto the target anchor's resting centre.
        final from = tester.getCenter(find.byKey(const Key('card')));
        final to = Offset(
          32 + 100 + (1280 - 200 - 64) * (a.x + 1) / 2,
          32 + 40 + (800 - 80 - 64) * (a.y + 1) / 2,
        );
        await tester.dragFrom(from, to - from);
        await tester.pumpAndSettle();
        expect(landed.last, a);
      }
      expect(landed, breakSixAnchors);
    });

    testWidgets('the template reopens at the last anchor', (tester) async {
      addTearDown(() {
        SoftFloatingWidgetTemplate.lastAnchor = Alignment.bottomRight;
      });
      SoftFloatingWidgetTemplate.lastAnchor = Alignment.topLeft;
      await pumpBreakTemplate(tester, 'floating');
      final center = tester.getCenter(find.byType(BreakDraggable));
      final card = tester.getTopLeft(find.byType(BreakGlass));
      expect(card.dx, lessThan(center.dx));
      expect(card.dy, lessThan(center.dy));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('BreathPreset', () {
    test('cycle lengths', () {
      expect(BreathPreset.box.cycleSeconds, 16);
      expect(BreathPreset.relax.cycleSeconds, 19);
      expect(BreathPreset.even.cycleSeconds, 10);
    });

    test('4-7-8 phases and fullness', () {
      const p = BreathPreset.relax;
      expect(p.phaseAt(1), BreathPhase.inhale);
      expect(p.phaseAt(5), BreathPhase.holdFull);
      expect(p.phaseAt(12), BreathPhase.exhale);
      expect(p.phaseAt(19.5), BreathPhase.inhale);
      expect(p.fullnessAt(0), 0);
      expect(p.fullnessAt(4), closeTo(1, 1e-9));
      expect(p.fullnessAt(10), 1);
      expect(p.fullnessAt(19), 0);
    });

    test('byId falls back to box', () {
      expect(BreathPreset.byId('nope'), BreathPreset.box);
      expect(BreathPreset.byId('even'), BreathPreset.even);
    });
  });

  group('zen presets', () {
    testWidgets('a new preset starts at the next cycle', (tester) async {
      await pumpBreakTemplate(tester, 'zen'); // 2 s into the box cycle
      expect(find.text('4-7-8'), findsOneWidget);
      await tester.tap(find.text('4-7-8'));
      var now = 2.0;
      Future<void> at(double seconds) async {
        await tester.pump(
          Duration(milliseconds: ((seconds - now) * 1000).round()),
        );
        await tester.pump(const Duration(milliseconds: 400));
        now = seconds + 0.4;
      }

      // Still on the box cycle: 8-12 s is breathe out.
      await at(9);
      expect(find.text('Breathe out'), findsOneWidget);
      // Box cycle ends at 16 s; 4-7-8 begins.
      await at(17);
      expect(find.text('Breathe in'), findsOneWidget);
      await at(16 + 6);
      expect(find.text('Hold'), findsOneWidget);
      await at(16 + 13);
      expect(find.text('Breathe out'), findsOneWidget);
      // 4-7-8 is 19 s long: the next breath in starts at 35 s.
      await at(35 + 1);
      expect(find.text('Breathe in'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('breathe_line holds between in and out', (tester) async {
    await pumpBreakTemplate(tester, 'breathe_line');
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Hold'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Breathe out'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('moon phase', () {
    // Reference new and full moons (UTC).
    test('new moon on 2000-01-06 and 2024-01-11', () {
      expect(DuskGlowTemplate.moonAge(DateTime.utc(2000, 1, 6, 18, 14)), 0);
      final age = DuskGlowTemplate.moonAge(DateTime.utc(2024, 1, 11, 11, 57));
      expect(DuskGlowTemplate.moonPhaseName(age), 'New moon');
    });

    test('full moon on 2000-01-21 and 2024-02-24', () {
      for (final d in [
        DateTime.utc(2000, 1, 21, 4, 40),
        DateTime.utc(2024, 2, 24, 12, 30),
      ]) {
        expect(
          DuskGlowTemplate.moonPhaseName(DuskGlowTemplate.moonAge(d)),
          'Full moon',
        );
      }
    });
  });

  group('time_slice', () {
    test('a 15 s break has 3 segments', () {
      expect(TimeSliceTemplate.segmentCountFor(15), 3);
    });

    testWidgets('golden: 15 s break at 6 s elapsed', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 14, 14, 5)), () async {
        await pumpBreakTemplate(
          tester,
          'time_slice',
          preview: true,
          remaining: 9,
          total: 15,
          onSkip: () {},
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/time_slice.15s.png'),
        );
      });
    });
  });

  group('paper_light e-ink flash', () {
    bool hasBlackFlash(WidgetTester tester) => tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .any((b) => b.color.a > 0.9 && b.color.r < 0.05 && b.color.g < 0.05);

    testWidgets('runs on entrance', (tester) async {
      await pumpBreakTemplate(tester, 'paper_light', remaining: 39);
      // pumpBreakTemplate waits 2 s; re-enter to catch the first frames.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpBreakTemplate(
        tester,
        'paper_light',
        settleFor: const Duration(milliseconds: 50),
      );
      expect(hasBlackFlash(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('is skipped under reduced motion', (tester) async {
      await pumpBreakTemplate(
        tester,
        'paper_light',
        reducedMotion: true,
        settleFor: const Duration(milliseconds: 50),
      );
      expect(hasBlackFlash(tester), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('step_guide tips', () {
    for (final (tip, steps) in [
      ('Look away.', 1),
      ('Look away. Blink slowly.', 2),
      ('Look away. Blink slowly. Relax. Breathe.', 4),
      ('One. Two. Three. Four. Five.', 4),
    ]) {
      testWidgets('"$tip" renders $steps step(s)', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpBreakTemplate(
          tester,
          'step_guide',
          breakInfo: BreakModel(
            type: BreakType.short,
            durationSeconds: 60,
            title: 'Rest',
            tip: tip,
          ),
        );
        expect(
          find.bySemanticsLabel(RegExp(r'^Step \d of \d, ')),
          findsNWidgets(steps),
        );
        expect(
          find.bySemanticsLabel(RegExp('^Step \\d of $steps, ')),
          findsNWidgets(steps),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        handle.dispose();
      });
    }
  });

  testWidgets('golden: open_field with a photo', (tester) async {
    late String path;
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const size = Size(640, 400);
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9CC3E6), Color(0xFF4F7A3F)],
          ).createShader(Offset.zero & size),
      );
      c.drawCircle(
        const Offset(440, 120),
        46,
        Paint()..color = const Color(0xFFFFF2B0),
      );
      final img = await rec.endRecording().toImage(640, 400);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      final dir = Directory.systemTemp.createTempSync('open_field_photo');
      addTearDown(() => dir.deleteSync(recursive: true));
      path = '${dir.path}/photo.png';
      File(path).writeAsBytesSync(bytes.buffer.asUint8List());
    });
    await pumpBreakTemplate(
      tester,
      'open_field',
      preview: true,
      settings: SettingsModel(customImagePath: path),
      onSkip: () {},
    );
    // Decode on the real event loop, then play the 900 ms fade-in.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/open_field.photo.png'),
    );
  });
}
