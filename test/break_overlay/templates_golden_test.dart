import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

/// Blurred layers (aurora, glow, moon) rasterise a fraction of a percent
/// differently across macOS / GPU versions, so a CI runner never matches a
/// golden made on another machine pixel for pixel. Real layout or colour
/// regressions move far more than this.
const _goldenTolerance = 0.005;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    return result.passed || result.diffPercent <= _goldenTolerance;
  }
}

/// Mid-break goldens at 1280x800 (thumbnail-style static frame, so animated
/// templates render their representative frame rather than t=0).
///
/// Regenerate with: flutter test --update-goldens test/break_overlay
void main() {
  setUpAll(() async {
    await setUpBreakTestEnvironment();
    final current = goldenFileComparator;
    if (current is LocalFileComparator) {
      goldenFileComparator = _TolerantComparator(
        Uri.parse('${current.basedir}templates_golden_test.dart'),
      );
    }
  });

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
          if (id == 'classic') {
            // The bundled photo decodes on the real event loop.
            for (var i = 0; i < 3; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 300)),
              );
              await tester.pump(const Duration(milliseconds: 400));
            }
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      });
    }
  }
}
