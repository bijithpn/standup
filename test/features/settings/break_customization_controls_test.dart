import 'package:breakmate/features/settings/presentation/sections/breaks/break_appearance_settings.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../break_overlay/break_test_harness.dart';

void main() {
  setUpAll(setUpBreakTestEnvironment);
  Future<void> show(
    WidgetTester tester,
    SettingsModel settings, {
    ValueChanged<SettingsModel>? onSave,
  }) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BreakAppearanceSettings(
                settings: settings,
                onSave: onSave ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('only relevant template options are offered', (tester) async {
    await show(tester, const SettingsModel(breakTemplate: 'quiet_pill'));
    expect(find.text('Accent color'), findsOneWidget);
    expect(find.text('Breathing pattern'), findsNothing);
    expect(find.text('Background image'), findsNothing);
    for (final removed in [
      'Clock Text Opacity',
      'Background Blur Intensity',
      'Break Screen Theme',
      'Per-Template Accent Pin',
    ]) {
      expect(find.text(removed), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, const SettingsModel(breakTemplate: 'zen'));
    expect(find.text('Breathing pattern'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, const SettingsModel(breakTemplate: 'classic'));
    expect(find.text('Background image'), findsOneWidget);
    expect(find.text('Accent color'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('template default clears its override and legacy timer opacity', (
    tester,
  ) async {
    SettingsModel? saved;
    await show(
      tester,
      const SettingsModel(
        breakTemplate: 'quiet_pill',
        clockFaceTextColorHex: 0x40202020,
        templateAccentOverrides: {'quiet_pill': 0xFFCB9F96, 'zen': 0xFFA7C4B5},
      ),
      onSave: (value) => saved = value,
    );
    await tester.ensureVisible(find.text('Template default'));
    await tester.tap(find.text('Template default'));
    expect(saved!.clockFaceTextColorHex, 0xFFFFFFFF);
    expect(saved!.templateAccentOverrides.containsKey('quiet_pill'), isFalse);
    expect(saved!.templateAccentOverrides['zen'], 0xFFA7C4B5);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
