import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

void main() {
  testWidgets(
    'TapTarget activates with Enter and Space and exposes semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TapTarget(
              selected: true,
              onTap: () => taps++,
              child: const Text('Option'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Option'));
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 3);

      expect(
        tester.getSemantics(find.text('Option')),
        matchesSemantics(
          label: 'Option',
          isButton: true,
          isSelected: true,
          isEnabled: true,
          isFocusable: true,
          hasEnabledState: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    },
  );

  testWidgets('TapTarget with null onTap is disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TapTarget(onTap: null, child: Text('Off'))),
      ),
    );
    await tester.tap(find.text('Off'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // No crash and nothing to invoke.
    expect(find.text('Off'), findsOneWidget);
  });
}
