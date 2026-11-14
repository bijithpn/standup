import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/shared/utils/accessibility_preferences.dart';
import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/themes/domain/app_theme_preset.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/experience_preferences.dart';
import 'package:breakmate/features/settings/widgets/advanced_settings.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_keyboard_handler.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';

void main() {
  tearDown(() {
    AppMotion.reduceMotion = false;
    AppTheme.highContrast = false;
    AppTheme.applyPreset(AppThemePreset.nordicSlate);
  });
  test(
    'text sizing preserves system scaling and honors both motion controls',
    () {
      final media = accessibleMediaData(
        const MediaQueryData(textScaler: TextScaler.linear(1.2)),
        const SettingsModel(
          experience: ExperiencePreferences(textScale: 1.5, highContrast: true),
          reduceMotion: true,
        ),
      );
      expect(media.textScaler.scale(10), closeTo(18, 0.0001));
      expect(media.highContrast, isTrue);
      expect(media.disableAnimations, isTrue);
      expect(
        accessibleMediaData(
          const MediaQueryData(),
          const SettingsModel(enableAnimations: false),
        ).disableAnimations,
        isTrue,
      );
      AppMotion.reduceMotion = true;
      expect(prefersReducedMotion, isTrue);
    },
  );
  test(
    'high contrast text and surfaces stay distinct in light and dark themes',
    () {
      for (final preset in [
        AppThemePreset.nordicSlate,
        AppThemePreset.eInkPaper,
      ]) {
        AppTheme.applyPreset(preset);
        final originalText = AppTheme.textPrimary;
        AppTheme.highContrast = true;
        final light = AppTheme.textPrimary.computeLuminance();
        final dark = AppTheme.surface.computeLuminance();
        final ratio = light > dark
            ? (light + 0.05) / (dark + 0.05)
            : (dark + 0.05) / (light + 0.05);
        expect(ratio, greaterThanOrEqualTo(7));
        expect(AppTheme.textSecondary, AppTheme.textPrimary);
        AppTheme.highContrast = false;
        expect(AppTheme.textPrimary, originalText);
      }
    },
  );
  testWidgets(
    'reduced motion shows entrance content immediately with tickers disabled',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: TickerMode(
              enabled: false,
              child: BreakEntrance(child: Text('Visible guidance')),
            ),
          ),
        ),
      );
      expect(find.text('Visible guidance'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BreakEntrance),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('advanced controls are hidden until explicitly expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdvancedSettings(children: [Text('Less frequent control')]),
        ),
      ),
    );
    expect(find.text('Less frequent control'), findsNothing);
    await tester.tap(find.text('Advanced settings'));
    await tester.pumpAndSettle();
    expect(find.text('Less frequent control'), findsOneWidget);
  });
  testWidgets('advanced settings remain usable with reduced motion', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AdvancedSettings(
              children: [
                TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('Advanced action'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Advanced settings'));
    await tester.pump();
    await tester.tap(find.text('Advanced action'));
    expect(tapped, isTrue);
  });

  testWidgets('settings tabs can be selected using Tab and Enter', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: segmentedControl(
            ['Profiles', 'Intervals'],
            0,
            (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, 1);
  });
  testWidgets('Tab and Enter reach overlay controls, while Escape dismisses', (
    tester,
  ) async {
    var skipped = 0;
    var activated = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BreakOverlayKeyboardHandler(
            canDismiss: true,
            onSkip: () => skipped++,
            onQuitApp: () {},
            child: TextButton(
              onPressed: () => activated++,
              child: const Text('Action'),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(skipped, 0);
    expect(activated, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(skipped, 1);
  });
  testWidgets(
    'filtered guided break fits a short window with 150 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final animation = AnimationController(vsync: tester);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(640, 480),
              textScaler: TextScaler.linear(1.5),
            ),
            child: BreakTemplateSwitcher(
              breakTemplate: 'activities',
              breakInfo: const BreakModel(
                type: BreakType.short,
                durationSeconds: 30,
                title: 'Stretch',
                tip: 'Move your neck',
              ),
              settings: const SettingsModel(
                experience: ExperiencePreferences(
                  highContrast: true,
                  exercisePosition: 'seated',
                  avoidedAreas: ['neck'],
                ),
              ),
              remaining: 30,
              total: 30,
              onSkip: () {},
              kenBurnsController: animation,
              exerciseTitle: 'Quiet rest',
              exerciseInstructions: 'Rest comfortably.',
            ),
          ),
        ),
      );
      expect(find.text('Quiet rest'), findsOneWidget);
      expect(find.text('Move your neck'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      animation.dispose();
    },
  );
}
