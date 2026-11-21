import 'package:breakmate/features/themes/domain/app_theme_preset.dart';
import 'package:breakmate/features/themes/presentation/widgets/theme_preset_card.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all presets fit the 130 pixel grid cards without overflow', (
    tester,
  ) async {
    for (final width in [260.0, 373.0]) {
      for (final preset in AppThemePreset.allPresets) {
        for (final selected in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.materialTheme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: 130,
                    child: ThemePresetCard(
                      preset: preset,
                      isSelected: selected,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(preset.description), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '${preset.id}, width: $width, selected: $selected',
          );
        }
      }
    }
  });
}
