import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/balance_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/flowline_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/zen_ink_template.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BreakSession session(MotionTier tier, {int remaining = 195}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return BreakSession(
    totalSeconds: 300,
    remainingSeconds: remaining,
    targetEndMs: now + remaining * 1000,
    startedAtMs: now - (300 - remaining) * 1000,
    tier: tier,
  );
}

Widget host(
  Size size,
  Widget Function(BuildContext, MotionClock) build,
  BreakSession s,
) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: MotionScope(
            startedAtMs: s.startedAtMs,
            tier: s.tier,
            builder: build,
          ),
        ),
      ),
    ),
  );
}

void main() {
  const templates = <WellnessTemplate>[
    BalanceTemplate(),
    ZenInkTemplate(),
    FlowlineTemplate(),
  ];

  for (final t in templates) {
    for (final tier in MotionTier.values) {
      testWidgets('${t.id} renders at tier ${tier.name}', (tester) async {
        final s = session(tier);
        final cases = <(Size, Widget Function(BuildContext, MotionClock))>[
          (const Size(1280, 800), (c, k) => t.immersive(c, s, k)),
          (const Size(340, 84), (c, k) => t.compactArt(c, s, k)),
          (
            const Size(40, 40),
            (c, k) => t.reminderArt(c, ReminderKind.hydration, k),
          ),
          for (final kind in ReminderKind.values)
            (const Size(40, 40), (c, k) => t.reminderArt(c, kind, k)),
        ];
        for (final (size, build) in cases) {
          tester.view.physicalSize = const Size(1400, 900);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(host(size, build, s));
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        addTearDown(tester.view.reset);
      });
    }
  }

  testWidgets('immersive handles paused, complete and eyes focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final t in templates) {
      for (final s in [
        session(MotionTier.full).copyWith(paused: true),
        session(MotionTier.full, remaining: 0).copyWith(complete: true),
      ]) {
        await tester.pumpWidget(
          host(const Size(1280, 800), (c, k) => t.immersive(c, s, k), s),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  test('flowline progress is monotonic over time', () {
    final s = session(MotionTier.full);
    var last = -1.0;
    for (var i = 0; i <= 300; i += 10) {
      final p = s.progressAt(s.startedAtMs + i * 1000);
      expect(p, greaterThanOrEqualTo(last));
      expect(p, inInclusiveRange(0, 1));
      last = p;
    }
  });

  test('palettes are stable and distinct', () {
    final colors = <Color>{};
    for (final t in templates) {
      expect(t.palette.canvas, t.palette.canvas);
      expect(
        const [
          BalanceTemplate(),
          ZenInkTemplate(),
          FlowlineTemplate(),
        ].firstWhere((x) => x.id == t.id).palette.textPrimary,
        t.palette.textPrimary,
      );
      colors.add(t.palette.canvas);
    }
    expect(colors.length, templates.length);
  });
}
