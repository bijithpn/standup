import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'break_test_harness.dart';

void main() {
  setUpAll(setUpBreakTestEnvironment);
  for (final id in allBreakTemplateIds) {
    testWidgets('$id uses subdued surfaces and readable text', (tester) async {
      await pumpBreakTemplate(tester, id, preview: true);
      final frame = tester.widget<BreakScaffold>(
        find.byType(BreakScaffold).first,
      );
      final palette = frame.palette ?? BreakPalette.dark;
      for (final background in [palette.canvas, palette.surface]) {
        expect(
          background.computeLuminance(),
          lessThan(0.1),
          reason: '$id background',
        );
        for (final foreground in [
          palette.textPrimary,
          palette.textSecondary,
          palette.textMuted,
        ]) {
          expect(
            breakContrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$id text contrast',
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
