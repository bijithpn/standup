import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

/// The same overflow check as the render matrix, but with no real fonts
/// loaded, so every glyph is the test framework's very wide fallback. It
/// catches rows that only fit by luck with Inter's narrow metrics.
void main() {
  setUpAll(() async {
    skipFonts = true;
    await setUpBreakTestEnvironment();
  });

  for (final id in allBreakTemplateIds) {
    for (final size in const [Size(1280, 800), Size(320, 200)]) {
      testWidgets('$id @ ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        await pumpBreakTemplate(tester, id, size: size, onSkip: () {});
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
