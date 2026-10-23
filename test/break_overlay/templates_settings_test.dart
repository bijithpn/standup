import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/looked_away_button.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_config_loader.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/overlay_chrome.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'break_test_harness.dart';

void main() {
  setUpAll(setUpBreakTestEnvironment);

  group('break screen theme mode', () {
    test('dark is the default and unknown values mean dark', () {
      expect(BreakPalette.forMode('dark', Brightness.light), BreakPalette.dark);
      expect(BreakPalette.forMode('nope', Brightness.light), BreakPalette.dark);
    });

    test('light is always light; system follows the OS', () {
      expect(
        BreakPalette.forMode('light', Brightness.dark),
        BreakPalette.light,
      );
      expect(
        BreakPalette.forMode('system', Brightness.light),
        BreakPalette.light,
      );
      expect(
        BreakPalette.forMode('system', Brightness.dark),
        BreakPalette.dark,
      );
    });
  });

  group('new settings travel to the overlay', () {
    test('defaults', () {
      const s = SettingsModel();
      expect(s.overlayThemeMode, 'dark');
      expect(s.breathPreset, 'box');
      expect(s.breakChimeEnabled, isFalse);
      expect(s.lookedAwayPromptEnabled, isFalse);
    });

    test('SettingsModel survives toMap / fromMap', () {
      final s = const SettingsModel().copyWith(
        overlayThemeMode: 'system',
        breathPreset: 'relax',
        breakChimeEnabled: true,
        lookedAwayPromptEnabled: true,
      );
      final back = SettingsModel.fromMap(s.toMap());
      expect(back.overlayThemeMode, 'system');
      expect(back.breathPreset, 'relax');
      expect(back.breakChimeEnabled, isTrue);
      expect(back.lookedAwayPromptEnabled, isTrue);
    });

    test('OverlayWindowConfig carries theme, preset and prompt', () {
      final config = OverlayWindowConfig.fromJson({
        'overlayThemeMode': 'light',
        'breathPreset': 'even',
        'lookedAwayPromptEnabled': true,
        'template': 'zen',
      });
      expect(config.breakTemplate, 'zen'); // legacy key still accepted
      final s = config.toSettingsModel();
      expect(s.overlayThemeMode, 'light');
      expect(s.breathPreset, 'even');
      expect(s.lookedAwayPromptEnabled, isTrue);
      expect(OverlayWindowConfig.fromJson(config.toJson()), config);
    });

    test('an older payload without the fields falls back to defaults', () {
      final config = OverlayWindowConfig.fromJson({'title': 'Break'});
      expect(config.overlayThemeMode, 'dark');
      expect(config.breathPreset, 'box');
      expect(config.lookedAwayPromptEnabled, isFalse);
    });
  });

  group('saved breathing preset', () {
    testWidgets('Zen starts on the saved pattern', (tester) async {
      // 10 s in: box is breathing out, 4-7-8 is still holding.
      await pumpBreakTemplate(
        tester,
        'zen',
        settings: const SettingsModel(breathPreset: 'relax'),
      );
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Hold'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Breathe Line uses it too', (tester) async {
      // 6.4 s in: box is holding, 5-5 is breathing out.
      await pumpBreakTemplate(
        tester,
        'breathe_line',
        settings: const SettingsModel(breathPreset: 'even'),
      );
      await tester.pump(const Duration(milliseconds: 4400));
      expect(find.text('Breathe out'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('"I looked away" button', () {
    testWidgets('calls back once, then rests as confirmed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => LookedAwayButton(
              confirmed: taps > 0,
              onPressed: () => setState(() => taps++),
            ),
          ),
        ),
      );
      await tester.tap(find.text('I looked away'));
      await tester.pump();
      expect(taps, 1);
      expect(find.text('Looked away'), findsOneWidget);
      await tester.tap(find.text('Looked away'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('OverlayChrome shows it only when asked', (tester) async {
      Widget chrome({VoidCallback? onLookedAway}) => MaterialApp(
        home: Scaffold(
          body: OverlayChrome(
            templateOwnsChrome: false,
            isInternalPreview: false,
            canDismiss: true,
            breakInfo: shortBreak,
            intensityLevel: 'standard',
            onSkip: () {},
            onLookedAway: onLookedAway,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpWidget(chrome());
      expect(find.text('I looked away'), findsNothing);

      var tapped = false;
      await tester.pumpWidget(chrome(onLookedAway: () => tapped = true));
      await tester.tap(find.text('I looked away'));
      expect(tapped, isTrue);
    });
  });

  group('completion hold', () {
    testWidgets('templates see a completing overlay as complete', (
      tester,
    ) async {
      bool? seen;
      Widget probe(bool completing) => BreakCompletionScope(
        completing: completing,
        child: Builder(
          builder: (context) {
            seen = breakIsComplete(context, 5, 60);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(probe(false));
      expect(seen, isFalse);
      await tester.pumpWidget(probe(true));
      expect(seen, isTrue);
    });

    testWidgets('a finished countdown is complete without the scope', (
      tester,
    ) async {
      late bool done;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            done = breakIsComplete(context, 0, 60);
            return const SizedBox();
          },
        ),
      );
      expect(done, isTrue);
    });
  });
}
