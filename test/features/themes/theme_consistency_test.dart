import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/app_dropdown.dart';
import 'package:breakmate/features/themes/domain/app_theme_preset.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/settings_page.dart';
import 'package:breakmate/features/settings/widgets/advanced_settings.dart';
import 'package:breakmate/features/settings/widgets/exercise_preferences_section.dart';
import 'package:breakmate/features/settings/experience_preferences.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import '../../helpers/in_memory_settings_repository.dart';

class _BreakController extends ChangeNotifier implements BreakController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  tearDown(() {
    AppTheme.highContrast = false;
    AppTheme.applyPreset(AppThemePreset.nordicSlate);
  });

  test(
    'accent labels stay readable across presets and custom accent extremes',
    () {
      for (final preset in AppThemePreset.allPresets) {
        AppTheme.applyPreset(preset);
        expect(
          contrast(
            AppTheme.accent,
            AppTheme.materialTheme.colorScheme.onPrimary,
          ),
          greaterThanOrEqualTo(4.5),
          reason: preset.id,
        );
      }
      for (final accent in [
        Colors.white,
        Colors.black,
        Colors.cyanAccent,
        Colors.pink,
        Colors.yellow,
      ]) {
        AppTheme.applyCustomAccent(accent);
        expect(contrast(accent, AppTheme.onAccent), greaterThanOrEqualTo(4.5));
        AppTheme.highContrast = true;
        expect(AppTheme.materialTheme.colorScheme.primary, accent);
      }
    },
  );

  testWidgets(
    'open groups and selected filters follow live palette changes without losing state',
    (tester) async {
      tester.view.physicalSize = const Size(700, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AppTheme.applyPreset(AppThemePreset.forestMatcha);
      final themes = ValueNotifier(AppTheme.materialTheme);
      addTearDown(themes.dispose);
      const settings = SettingsModel(
        experience: ExperiencePreferences(exercisePosition: 'seated'),
      );
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeData>(
          valueListenable: themes,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ExercisePreferencesSection(
                    settings: settings,
                    onSave: (_) {},
                  ),
                  const AdvancedSettings(children: [Text('Expanded content')]),
                ],
              ),
            ),
          ),
          builder: (_, theme, child) => MaterialApp(theme: theme, home: child),
        ),
      );
      await tester.tap(find.text('Advanced settings'));
      await tester.pumpAndSettle();
      final expandedState = tester.state(find.byType(ExpansionTile));
      for (final preset in [
        AppThemePreset.softLight,
        AppThemePreset.eInkPaper,
        AppThemePreset.crimsonEmber,
      ]) {
        AppTheme.applyPreset(preset, customAccent: const Color(0xFFB846AD));
        themes.value = AppTheme.materialTheme;
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(ExpansionTile)), same(expandedState));
        expect(find.text('Expanded content'), findsOneWidget);
        final selected = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Seated'),
        );
        expect(selected.selected, isTrue);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Seated'),
        );
        expect(paragraph.text.style!.color, AppTheme.textPrimary);
        expect(paragraph.text.style!.fontFamily, 'Inter');
        final unselected = tester.renderObject<RenderParagraph>(
          find.text('Standing'),
        );
        expect(unselected.text.style!.color, AppTheme.textSecondary);
        expect(unselected.text.style!.fontFamily, 'Inter');
        expect(
          contrast(
            paragraph.text.style!.color!,
            themes.value.colorScheme.secondaryContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'a cached settings page repaints its background and labels on theme changes',
    (tester) async {
      tester.view.physicalSize = const Size(520, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = InMemorySettingsRepository();
      addTearDown(settings.dispose);
      AppTheme.applyPreset(AppThemePreset.forestMatcha);
      final themes = ValueNotifier(AppTheme.materialTheme);
      addTearDown(themes.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsRepository>.value(value: settings),
            ChangeNotifierProvider<BreakController>(
              create: (_) => _BreakController(),
            ),
          ],
          child: ValueListenableBuilder<ThemeData>(
            valueListenable: themes,
            child: const SettingsPage(section: 'General'),
            builder: (_, theme, child) => MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: child,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      AppTheme.applyPreset(AppThemePreset.softLight);
      themes.value = AppTheme.materialTheme;
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        AppTheme.surface,
      );
      expect(
        tester.widget<Text>(find.text('High contrast')).style!.color,
        AppTheme.textPrimary,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dropdown menus use the selected light surface', (tester) async {
    AppTheme.applyPreset(AppThemePreset.softLight);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.materialTheme,
        home: Scaffold(
          body: Center(
            child: AppDropdown<String>(
              value: 'one',
              items: const [
                AppDropdownItem(value: 'one', label: 'One'),
                AppDropdownItem(value: 'two', label: 'Two'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    final popup = tester.widget<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    );
    expect(popup.color, AppTheme.surfaceElevated);
    expect(find.text('Two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
