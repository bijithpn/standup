import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_models.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_overlay_view.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_registry.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OverlayWindowConfig config({
  String windowMode = 'compact',
  bool strict = false,
  String template = 'balance',
  int? startedAt,
}) => OverlayWindowConfig(
  windowMode: windowMode,
  strictMode: strict,
  breakTemplate: template,
  durationSeconds: 300,
  remainingSeconds: 195,
  breakFocus: 'eyes',
  breakStartedAtMs: startedAt ?? DateTime.now().millisecondsSinceEpoch - 105000,
);

Widget host(
  OverlayWindowConfig c,
  ValueNotifier<int> remaining, {
  VoidCallback? onSkip,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(1280, 800)),
    child: Material(
      child: WellnessOverlayView(
        config: c,
        remainingSecondsNotifier: remaining,
        onSkip: onSkip,
      ),
    ),
  ),
);

void main() {
  group('AutoModeRules', () {
    test('long breaks go immersive only when enabled', () {
      const on = AutoModeRules();
      const off = AutoModeRules(longBreaksImmersive: false);
      expect(on.resolve(isLongBreak: true), BreakDisplayMode.immersive);
      expect(on.resolve(isLongBreak: false), BreakDisplayMode.compact);
      expect(off.resolve(isLongBreak: true), BreakDisplayMode.compact);
    });
  });

  group('template id migration', () {
    test('every retired id maps to a registered template', () {
      const retired = [
        'activities',
        'breathe_line',
        'classic',
        'clock_face',
        'companion',
        'floating',
        'focus_orb',
        'haiku_card',
        'hud',
        'iris_rest',
        'minimal',
        'night_sky',
        'one_word',
        'paper_light',
        'quiet_pill',
        'split_view',
        'step_guide',
        'zen',
        'wind_down',
        'dusk_glow',
        'warm_amber',
        'wave_calm',
        'time_slice',
        'open_field',
        'soft_arc',
        'pulse_dot',
        'error_template',
        'something_unknown',
      ];
      final ids = wellnessTemplates.map((t) => t.id).toSet();
      expect(ids, {
        'balance',
        'zen_ink',
        'flowline',
        'aurora',
        'midnight',
        'liquid',
      });
      for (final id in [...retired, ...ids]) {
        expect(ids, contains(migrateTemplateId(id)), reason: id);
      }
      expect(migrateTemplateId(null), 'balance');
      expect(migrateTemplateId('aurora'), 'aurora');
      expect(wellnessTemplateById('zen').id, 'zen_ink');
    });
  });

  group('WellnessOverlayView', () {
    testWidgets('compact renders the card, immersive does not', (t) async {
      final remaining = ValueNotifier(195);
      addTearDown(remaining.dispose);

      await t.pumpWidget(host(config(), remaining, onSkip: () {}));
      expect(find.byType(CompactBreakCard), findsOneWidget);

      await t.pumpWidget(
        host(config(windowMode: 'immersive'), remaining, onSkip: () {}),
      );
      expect(find.byType(CompactBreakCard), findsNothing);
      expect(find.textContaining('Skip'), findsOneWidget);
    });

    testWidgets('skip hidden in strict mode', (t) async {
      final remaining = ValueNotifier(195);
      addTearDown(remaining.dispose);

      await t.pumpWidget(host(config(strict: true), remaining, onSkip: () {}));
      expect(find.text('Skip'), findsNothing);

      await t.pumpWidget(host(config(), remaining, onSkip: () {}));
      expect(find.text('Skip'), findsOneWidget);

      await t.pumpWidget(host(config(), remaining));
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('time follows the notifier without a new timer', (t) async {
      final remaining = ValueNotifier(195);
      addTearDown(remaining.dispose);

      await t.pumpWidget(host(config(), remaining));
      expect(find.text('03:15'), findsOneWidget);

      remaining.value = 194;
      await t.pump();
      expect(find.text('03:14'), findsOneWidget);
      expect(find.text('03:15'), findsNothing);
      expect(t.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('eyes focus adds look-away guidance', (t) async {
      final remaining = ValueNotifier(195);
      addTearDown(remaining.dispose);

      await t.pumpWidget(host(config(), remaining));
      expect(find.textContaining('20 feet'), findsOneWidget);
    });

    testWidgets('disposing the tree stops every ticker', (t) async {
      final remaining = ValueNotifier(195);
      addTearDown(remaining.dispose);

      await t.pumpWidget(host(config(), remaining));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.transientCallbackCount, greaterThan(0));

      await t.pumpWidget(const SizedBox());
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('completion scope marks the break complete', (t) async {
      final remaining = ValueNotifier(195);
      addTearDown(remaining.dispose);
      await t.pumpWidget(
        BreakCompletionScope(
          completing: true,
          child: host(config(), remaining),
        ),
      );
      expect(t.takeException(), isNull);
    });
  });
}
