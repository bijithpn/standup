import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

/// Mid-break goldens at 1280x800 (thumbnail-style static frame, so animated
/// templates render their representative frame rather than t=0).
///
/// Regenerate with: flutter test --update-goldens test/break_overlay
void main() {
  setUpAll(setUpBreakTestEnvironment);

  for (final id in allBreakTemplateIds) {
    // The companion's pet animates from wall-clock state, so its light frame
    // is not reproducible between runs.
    for (final dark in id == 'companion' ? [true] : [true, false]) {
      final name = dark ? id : '$id.light';
      testWidgets('golden: $name', (tester) async {
        // Pinned wall clock: several templates show the time of day, the moon
        // phase or a time-selected poem.
        await withClock(Clock.fixed(DateTime(2026, 3, 14, 14, 5)), () async {
          await pumpBreakTemplate(
            tester,
            id,
            preview: true,
            dark: dark,
            // Activity Studio's eye-sync game uses an unseeded Random, so the
            // golden uses the (deterministic) breathing tab.
            breakInfo: id == 'activities' ? longBreak : shortBreak,
            onSkip: () {},
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      });
    }
  }
}
