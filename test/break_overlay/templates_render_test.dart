import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

/// Every template, at tiny / desktop / 4K sizes, in both themes, with and
/// without reduced motion, must build and lay out without any exception
/// (overflow errors surface through `takeException`).
void main() {
  setUpAll(setUpBreakTestEnvironment);

  const sizes = {
    '320x200': Size(320, 200),
    '1280x800': Size(1280, 800),
    '2560x1440': Size(2560, 1440),
  };

  for (final id in allBreakTemplateIds) {
    for (final entry in sizes.entries) {
      for (final dark in [true, false]) {
        for (final reduced in [false, true]) {
          final name =
              '$id @ ${entry.key} ${dark ? 'dark' : 'light'}'
              '${reduced ? ' reduced-motion' : ''}';
          testWidgets(name, (tester) async {
            await pumpBreakTemplate(
              tester,
              id,
              size: entry.value,
              dark: dark,
              reducedMotion: reduced,
              onSkip: () {},
            );
            expect(tester.takeException(), isNull);

            // Unmount so timers and tickers are cancelled before teardown.
            await tester.pumpWidget(const SizedBox.shrink());
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
