import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _frame(WidgetTester t, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await t.runAsync(() async {
    final img = await boundary.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  }))!;
}

Future<void> _pump(
  WidgetTester t,
  GlobalKey key,
  String id,
  BreakSession s,
) async {
  t.view.physicalSize = const Size(640, 400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: MotionScope(
          startedAtMs: s.startedAtMs,
          tier: s.tier,
          builder: (c, clock) =>
              wellnessTemplateById(id).immersive(c, s, clock),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
}

BreakSession _s({
  MotionTier tier = MotionTier.full,
  int remaining = 150,
  double intensity = 0.6,
}) => BreakSession(
  totalSeconds: 300,
  remainingSeconds: remaining,
  startedAtMs: DateTime.now().millisecondsSinceEpoch - 5000,
  tier: tier,
  intensity: intensity,
);

void main() {
  for (final t in wellnessTemplates) {
    group(t.id, () {
      testWidgets('moves over time at full motion', (tester) async {
        final key = GlobalKey();
        await _pump(tester, key, t.id, _s());
        final a = await _frame(tester, key);
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(a, isNot(equals(await _frame(tester, key))));
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('is frozen when still', (tester) async {
        final key = GlobalKey();
        await _pump(tester, key, t.id, _s(tier: MotionTier.still));
        final a = await _frame(tester, key);
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(a, equals(await _frame(tester, key)));
      });

      testWidgets('reflects progress', (tester) async {
        final key = GlobalKey();
        await _pump(
          tester,
          key,
          t.id,
          _s(tier: MotionTier.still, remaining: 290),
        );
        final early = await _frame(tester, key);
        await _pump(
          tester,
          key,
          t.id,
          _s(tier: MotionTier.still, remaining: 10),
        );
        expect(early, isNot(equals(await _frame(tester, key))));
      });
    });
  }
}
