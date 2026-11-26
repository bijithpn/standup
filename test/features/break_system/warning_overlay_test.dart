import 'package:breakmate/features/break_system/presentation/widgets/break_start_warning_overlay.dart';
import 'package:breakmate/features/break_system/presentation/widgets/skip_reason_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  Widget warning({VoidCallback? onSkip, VoidCallback? onSnooze}) => _host(
    BreakStartWarningOverlay(
      fadeAnimation: const AlwaysStoppedAnimation(1),
      title: 'Eye break',
      durationSeconds: 20,
      isPreBreak: true,
      onSkip: onSkip,
      onSnooze: onSnooze,
    ),
  );

  testWidgets('skip and snooze buttons fire their callbacks', (tester) async {
    var skipped = 0, snoozed = 0;
    await tester.pumpWidget(
      warning(onSkip: () => skipped++, onSnooze: () => snoozed++),
    );
    await tester.tap(find.text('Skip'));
    await tester.tap(find.text('Snooze 5 min'));
    expect(skipped, 1);
    expect(snoozed, 1);
  });

  testWidgets('dismiss and drag work even when skipping is not allowed', (
    tester,
  ) async {
    var closed = 0, dragged = 0;
    await tester.pumpWidget(
      _host(
        BreakStartWarningOverlay(
          fadeAnimation: const AlwaysStoppedAnimation(1),
          title: 'Eye break',
          durationSeconds: 3,
          isPreBreak: true,
          onClose: () => closed++,
          onDragStart: () => dragged++,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.drag(
      find.textContaining('Break starting'),
      const Offset(50, 0),
    );
    expect(closed, 1);
    expect(dragged, 1);
  });

  testWidgets('buttons are hidden when skipping is not allowed', (
    tester,
  ) async {
    await tester.pumpWidget(warning());
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Snooze 5 min'), findsNothing);
  });

  testWidgets('reason picker reports the chosen reason and can be dismissed', (
    tester,
  ) async {
    String? reason;
    var cancelled = false;
    await tester.pumpWidget(
      _host(
        Stack(
          children: [
            SkipReasonPicker(
              onReason: (r) => reason = r,
              onCancel: () => cancelled = true,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Deep focus'));
    expect(reason, 'Deep focus');
    await tester.tap(find.text('Back to break'));
    expect(cancelled, isTrue);
  });

  testWidgets('Escape closes the reason picker', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      _host(
        Stack(
          children: [
            SkipReasonPicker(
              onReason: (_) {},
              onCancel: () => cancelled = true,
            ),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelled, isTrue);
  });

  testWidgets(
    'closing the reason picker restores focus and Escape closes once',
    (tester) async {
      var closes = 0;
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      late StateSetter setOpen;
      var open = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, set) {
              setOpen = set;
              return Stack(
                children: [
                  TextButton(
                    focusNode: trigger,
                    onPressed: () {},
                    child: const Text('Skip'),
                  ),
                  if (open)
                    SkipReasonPicker(
                      onReason: (_) {},
                      onCancel: () {
                        closes++;
                        setOpen(() => open = false);
                      },
                    ),
                ],
              );
            },
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pump();
      setOpen(() => open = true);
      await tester.pump();
      expect(trigger.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(closes, 1);
      expect(trigger.hasFocus, isTrue);
    },
  );
}
