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
      await pumpBreakTemplate(tester, id, preview: true, onSkip: () {});
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$id.png'),
      );
    });
  }
}
