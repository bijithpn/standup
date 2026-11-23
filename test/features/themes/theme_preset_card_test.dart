import 'package:breakmate/features/themes/domain/app_theme_preset.dart';
import 'package:breakmate/features/themes/presentation/widgets/theme_preset_card.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'all presets fit the compact tiles at text scale 1.5 without overflow',
    (tester) async {
      for (final width in [160.0, 240.0]) {
        for (final preset in AppThemePreset.allPresets) {
          for (final selected in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.materialTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: width,
                      height: 88,
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
            expect(find.text(preset.name), findsOneWidget);
            expect(
              find.byIcon(CupertinoIcons.checkmark_alt),
              selected ? findsOneWidget : findsNothing,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${preset.id}, width: $width, selected: $selected',
            );
          }
        }
      }
    },
  );
}
