import 'package:breakmate/features/break_overlay/wellness/wellness_registry.dart';
import 'package:breakmate/features/settings/presentation/sections/breaks/break_appearance_settings.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    SettingsModel settings,
    ValueChanged<SettingsModel> onSave,
  ) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BreakAppearanceSettings(settings: settings, onSave: onSave),
          ),
        ),
      ),
    );
  }

  testWidgets('shows six static cards and settles', (tester) async {
    await show(tester, const SettingsModel(enableAnimations: false), (_) {});
    await tester.pumpAndSettle();
    expect(wellnessTemplates, hasLength(6));
    for (final t in wellnessTemplates) {
      expect(find.text(t.name), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection is applied through copyWith', (tester) async {
    SettingsModel? saved;
    await show(
      tester,
      const SettingsModel(enableAnimations: false),
      (v) => saved = v,
    );
    final target = wellnessTemplates.firstWhere((t) => t.id != 'balance');
    await tester.tap(find.bySemanticsLabel(RegExp('^${target.name}\\.')));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(saved!.breakTemplate, target.id);
    await tester.pump(const Duration(seconds: 4));
  });
}
