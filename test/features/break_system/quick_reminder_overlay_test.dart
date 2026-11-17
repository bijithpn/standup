// Regression coverage: reminders render a compact card with short copy, never the full break template.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/health_reminder_messages.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_overlay.dart';
import 'package:breakmate/features/break_system/presentation/widgets/quick_reminder_overlay.dart';

void main() {
  Future<void> pumpReminder(
    WidgetTester tester, {
    required String? reminderType,
    String overlayType = 'quickReminder',
    bool allowFullPoster = false,
  }) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: QuickReminderOverlay(
            reminderType: reminderType,
            overlayType: overlayType,
            fadeAnimation: controller,
            title: 'Break ready',
            durationSeconds: 2,
            allowFullPoster: allowFullPoster,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The pill wording is one of a few variants; find whichever was chosen.
  Finder pillText(String type) {
    final variants = <String>{
      for (var seed = 0; seed < 200; seed++)
        HealthReminderMessages.pill(type, Random(seed)),
    };
    return find.byWidgetPredicate(
      (w) => w is Text && variants.contains(w.data),
    );
  }

  testWidgets('posture reminder shows a compact card with its short label', (
    tester,
  ) async {
    await pumpReminder(tester, reminderType: 'posture');

    expect(pillText('posture'), findsOneWidget);
    expect(
      find.textContaining('sit up straight', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('default reminder shows short wording only', (tester) async {
    await pumpReminder(tester, reminderType: 'eyeblink');

    expect(pillText('eyeblink'), findsOneWidget);
    expect(find.textContaining('look away', findRichText: true), findsNothing);
  });

  testWidgets('meeting-break reminder shows the quiet card', (tester) async {
    await pumpReminder(tester, reminderType: 'meetingBreak');

    expect(find.text('Break ready after your meeting'), findsOneWidget);
  });

  testWidgets('the card is announced as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpReminder(tester, reminderType: 'meetingBreak');

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Break ready after your meeting'),
      ),
      matchesSemantics(
        label: 'Break ready after your meeting',
        isLiveRegion: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('shows the full poster when allowFullPoster is true', (
    tester,
  ) async {
    await pumpReminder(tester, reminderType: 'posture', allowFullPoster: true);

    expect(find.text('Sit up'), findsOneWidget);
    // Icon names what the reminder is about, not the app's own logo.
    expect(find.byIcon(Icons.accessibility_new_rounded), findsOneWidget);
    expect(find.byType(PosterReminderOverlay), findsOneWidget);
  });

  testWidgets(
    'falls back to the compact card when allowFullPoster is false, even for meetingBreak',
    (tester) async {
      await pumpReminder(
        tester,
        reminderType: 'meetingBreak',
        allowFullPoster: false,
      );

      expect(find.text('Break ready after your meeting'), findsOneWidget);
      expect(find.byType(PosterReminderOverlay), findsNothing);
    },
  );

  for (final entry in {
    'hydration': Icons.water_drop_rounded,
    'stretch': Icons.self_improvement_rounded,
    'standup': Icons.directions_walk_rounded,
  }.entries) {
    testWidgets('${entry.key} reminder shows its own wording', (tester) async {
      await pumpReminder(tester, reminderType: entry.key);
      expect(pillText(entry.key), findsOneWidget);
    });
  }

  test('every reminder type has several wording variants', () {
    for (final type in [
      'eyeblink',
      'posture',
      'hydration',
      'stretch',
      'standup',
    ]) {
      final pills = {
        for (var s = 0; s < 100; s++)
          HealthReminderMessages.pill(type, Random(s)),
      };
      final lines = {
        for (var s = 0; s < 100; s++)
          HealthReminderMessages.text(type, Random(s)),
      };
      expect(pills.length, greaterThan(1), reason: '$type pill');
      expect(lines.length, greaterThan(1), reason: '$type text');
    }
  });
}
