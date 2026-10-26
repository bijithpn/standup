import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/night_sky_template.dart';

void main() {
  const testBreakInfo = BreakModel(
    type: BreakType.long,
    durationSeconds: 300,
    title: 'Long Break',
    tip: 'Step away from the screen.',
  );
  const testSettings = SettingsModel();

  testWidgets('shows the running-state copy while time remains', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NightSkyTemplate(
            breakInfo: testBreakInfo,
            settings: testSettings,
            remainingSeconds: 200,
            totalSeconds: 300,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Recovery'), findsOneWidget);
    expect(find.text('Recharged & Ready'), findsNothing);
    expect(find.text('Skip'), findsNothing); // onSkip is null
  });

  testWidgets(
    'crossfades to the ending-state copy and Complete Session button',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NightSkyTemplate(
              breakInfo: testBreakInfo,
              settings: testSettings,
              remainingSeconds: 0,
              totalSeconds: 300,
              onSkip: () => completed = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Recharged & Ready'), findsOneWidget);
      expect(find.text('Recovery'), findsNothing);
      expect(find.text('Complete Session'), findsOneWidget);

      await tester.tap(find.text('Complete Session'));
      expect(completed, isTrue);
    },
  );

  testWidgets(
    'shows a Skip pill mid-break when onSkip is provided and not strict',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NightSkyTemplate(
              breakInfo: testBreakInfo,
              settings: testSettings,
              remainingSeconds: 200,
              totalSeconds: 300,
              onSkip: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Skip'), findsOneWidget);
    },
  );
}
