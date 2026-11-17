import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_overlay/wellness/motion_kit.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/aurora_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/liquid_template.dart';
import 'package:breakmate/features/break_overlay/wellness/templates/midnight_template.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const templates = <WellnessTemplate>[
    AuroraTemplate(),
    MidnightTemplate(),
    LiquidTemplate(),
  ];

  for (final t in templates) {
    group(t.id, () {
      test('palette is constant and readable', () {
        final other = switch (t) {
          AuroraTemplate() => const AuroraTemplate(),
          MidnightTemplate() => const MidnightTemplate(),
          _ => const LiquidTemplate(),
        };
        expect(identical(t.palette, other.palette), isTrue);
        for (final c in [
          t.palette.textPrimary,
          t.palette.textSecondary,
          t.palette.textMuted,
        ]) {
          expect(_contrast(c, t.palette.canvas), greaterThanOrEqualTo(4.5));
        }
      });

      for (final tier in MotionTier.values) {
        for (final focus in BreakFocus.values) {
          testWidgets('renders $tier $focus', (tester) async {
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final handle = tester.ensureSemantics();
            final now = DateTime.now().millisecondsSinceEpoch;
            for (final (w, h, kind) in [
              (1280.0, 800.0, 0),
              (340.0, 84.0, 1),
              (40.0, 40.0, 2),
            ]) {
              tester.view.physicalSize = Size(w, h);
              for (final progressDone in [false, true]) {
                final s = BreakSession(
                  totalSeconds: 300,
                  remainingSeconds: progressDone ? 0 : 105,
                  complete: progressDone,
                  startedAtMs: now - 30000,
                  focus: focus,
                  tier: tier,
                  timeOfDay: true,
                );
                await tester.pumpWidget(
                  MaterialApp(
                    home: Material(
                      child: MotionScope(
                        startedAtMs: s.startedAtMs,
                        tier: tier,
                        builder: (c, clock) => SizedBox(
                          width: w,
                          height: h,
                          child: switch (kind) {
                            0 => t.immersive(c, s, clock),
                            1 => t.compactArt(c, s, clock),
                            _ => t.reminderArt(
                              c,
                              ReminderKind.values[focus.index],
                              clock,
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pump(const Duration(seconds: 1));
                expect(tester.takeException(), isNull);
                if (kind == 0) {
                  expect(
                    find.bySemanticsLabel(
                      RegExp(spokenRemaining(s.remainingSeconds)),
                    ),
                    findsOneWidget,
                  );
                }
              }
            }
            handle.dispose();
          });
        }
      }
    });
  }
}
