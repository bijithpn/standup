import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/privacy_section.dart';

void main() {
  testWidgets('toggling app usage tracking calls onSave with the new value', (tester) async {
    SettingsModel? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrivacySection(
              settings: const SettingsModel(appUsageTrackingEnabled: false),
              onSave: (updated) => saved = updated,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Track App Usage'), findsOneWidget);

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.appUsageTrackingEnabled, isTrue);
  });
}
