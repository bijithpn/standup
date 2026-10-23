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
    testWidgets('golden: $id', (tester) async {
      // Pinned wall clock: several templates show the time of day, the moon
      // phase or a time-selected poem.
      await withClock(Clock.fixed(DateTime(2026, 3, 14, 14, 5)), () async {
        await pumpBreakTemplate(
          tester,
          id,
          preview: true,
          // Activity Studio's eye-sync game uses an unseeded Random, so the
          // golden uses the (deterministic) breathing tab.
          breakInfo: id == 'activities' ? longBreak : shortBreak,
          onSkip: () {},
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$id.png'),
        );
      });
    });
  }
}
