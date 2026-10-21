import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

void main() {
  testWidgets(
    'MinimalButton is keyboard-activatable and exposes button semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MinimalButton(
              onPressed: () => pressed++,
              child: const Text('Save'),
            ),
          ),
        ),
      );

      // Tab onto the button, then activate with Enter and Space.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(pressed, 2);

      expect(
        tester.getSemantics(find.text('Save')),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    },
  );

  testWidgets('disabled MinimalButton ignores the keyboard', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MinimalButton(onPressed: null, child: Text('Save')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MinimalSlider responds to arrow keys and exposes slider semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      var value = 0.5;
      double? committed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 300,
                child: MinimalSlider(
                  value: value,
                  onChanged: (v) => setState(() => value = v),
                  onChangeEnd: (v) => committed = v,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(0.55, 1e-9));
      expect(committed, closeTo(0.55, 1e-9));

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(value, 1.0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 1.0); // clamped

      expect(
        tester.getSemantics(
          find
              .descendant(
                of: find.byType(MinimalSlider),
                matching: find.byType(Semantics),
              )
              .first,
        ),
        isSemantics(
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
          value: '100%',
          increasedValue: '100%',
          decreasedValue: '95%',
        ),
      );
      handle.dispose();
    },
  );
}
