import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/presentation/sections/analytics_settings_section.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

void main() {
  testWidgets('selecting the Breaks tab shows the break statistics section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnalyticsSettingsSection(
              stats: const StatsModel(currentStreak: 2, longestStreak: 5),
              settings: const SettingsModel(),
              onSave: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Breaks'));
    await tester.pumpAndSettle();

    expect(find.text('Break Statistics'), findsOneWidget);
    expect(find.text('Current Streak'), findsOneWidget);
  });
}
