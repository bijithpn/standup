import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/widgets/notifications_section.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/features/themes/domain/app_theme_preset.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final original = AppTheme.activePreset;
  tearDown(() => AppTheme.applyPreset(original));
  for (final preset in [AppThemePreset.nordicSlate, AppThemePreset.eInkPaper]) {
    testWidgets('reminder inputs are themed and save values in ${preset.id}', (
      tester,
    ) async {
      AppTheme.applyPreset(preset);
      SettingsModel? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationsSection(
                settings: const SettingsModel(),
                onSave: (value) => saved = value,
              ),
            ),
          ),
        ),
      );
      final fields = find.byType(TextField);
      await tester.ensureVisible(fields.first);
      for (final field in tester.widgetList<TextField>(fields)) {
        expect(field.style!.color, AppTheme.textPrimary);
        expect(field.decoration!.fillColor, AppTheme.surfaceElevated);
        expect(field.decoration!.hintStyle!.color, AppTheme.textSecondary);
      }
      await tester.enterText(fields.first, 'Relax your shoulders');
      await tester.enterText(fields.last, '45');
      await tester.ensureVisible(find.text('Add reminder'));
      await tester.tap(find.text('Add reminder'));
      expect(saved!.customReminders.single.title, 'Relax your shoulders');
      expect(saved!.customReminders.single.minutes, 45);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'interval picker uses matching text and surface in ${preset.id}',
      (tester) async {
        AppTheme.applyPreset(preset);
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPicker(
                    context: context,
                    title: 'Short break interval',
                    options: ['20', '30'],
                    suffix: ' min',
                    onSelected: (value) => selected = value,
                  ),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('20 min')).style!.color,
          AppTheme.textPrimary,
        );
        await tester.tap(find.text('30 min'));
        await tester.pumpAndSettle();
        expect(selected, '30');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
