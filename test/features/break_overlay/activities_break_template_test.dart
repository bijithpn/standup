import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/activities_break_template.dart';

void main() {
  testWidgets('ActivitiesBreakTemplate short break (eye sync) builds and runs without crash', (tester) async {
    final breakInfo = BreakModel(
      type: BreakType.short,
      durationSeconds: 20,
      title: 'Eye Rest',
      tip: 'Look away',
    );
    final settings = SettingsModel();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivitiesBreakTemplate(
            breakInfo: breakInfo,
            settings: settings,
            remainingSeconds: 20,
            totalSeconds: 20,
            onSkip: () {},
          ),
        ),
      ),
    );

    expect(find.text('Eye sync'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('ActivitiesBreakTemplate long break (breathing) builds and runs without crash', (tester) async {
    final breakInfo = BreakModel(
      type: BreakType.long,
      durationSeconds: 300,
      title: 'Take a Break',
      tip: 'Breathe deeply',
    );
    final settings = SettingsModel();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivitiesBreakTemplate(
            breakInfo: breakInfo,
            settings: settings,
            remainingSeconds: 300,
            totalSeconds: 300,
            onSkip: () {},
          ),
        ),
      ),
    );

    expect(find.text('Breathing'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
