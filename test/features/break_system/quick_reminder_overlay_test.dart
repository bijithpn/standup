// Regression coverage: posture/eye-rest/meeting-break reminders must render
// the minimal pill (icon + short label), never the old full break template
// with long instructional copy.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/health_reminder_copy.dart';
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
        HealthReminderCopy.pill(type, Random(seed)),
    };
    return find.byWidgetPredicate(
      (w) => w is Text && variants.contains(w.data),
    );
  }

  testWidgets(
    'posture reminder shows only the minimal pill: icon + short label',
    (tester) async {
      await pumpReminder(tester, reminderType: 'posture');

      expect(pillText('posture'), findsOneWidget);
      expect(find.byIcon(Icons.accessibility_new_rounded), findsOneWidget);

      // Must not contain the old full-template long instructional copy.
      expect(
        find.textContaining('sit up straight', findRichText: true),
        findsNothing,
      );
    },
  );

  testWidgets(
    'eye rest reminder shows only the minimal pill: icon + short label',
    (tester) async {
      await pumpReminder(tester, reminderType: 'eyeblink');

      expect(pillText('eyeblink'), findsOneWidget);
      expect(find.byIcon(Icons.remove_red_eye_rounded), findsOneWidget);
      expect(
        find.textContaining('look away', findRichText: true),
        findsNothing,
      );
    },
  );

  testWidgets('meeting-break reminder shows the quiet minimal pill', (
    tester,
  ) async {
    await pumpReminder(tester, reminderType: 'meetingBreak');

    expect(find.text('Break ready after your meeting'), findsOneWidget);
    expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
  });

  testWidgets(
    'the pill uses a translucent dark background, not the full break card style',
    (tester) async {
      await pumpReminder(tester, reminderType: 'posture');

      final container = tester.widget<Container>(
        find
            .ancestor(of: pillText('posture'), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      final color = decoration.color!;

      expect(color.a, closeTo(0.36, 0.01));
      // Fully opaque black (the old full-screen break card look) would be a=1.0.
      expect(color.a, lessThan(0.5));
    },
  );

  testWidgets('shows the full poster when allowFullPoster is true', (
    tester,
  ) async {
    await pumpReminder(tester, reminderType: 'posture', allowFullPoster: true);

    expect(find.text('Watch your posture!'), findsOneWidget);
    // Icon names what the reminder is about, not the app's own logo.
    expect(find.byIcon(Icons.accessibility_new_rounded), findsOneWidget);
    // The poster has no 0.36-alpha pill container — it's full-bleed.
    final pillContainers = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final color = decoration.color;
      return color != null && (color.a - 0.36).abs() < 0.01;
    });
    expect(pillContainers, findsNothing);
  });

  testWidgets(
    'falls back to the minimal pill when allowFullPoster is false, even for meetingBreak',
    (tester) async {
      await pumpReminder(
        tester,
        reminderType: 'meetingBreak',
        allowFullPoster: false,
      );

      expect(find.text('Break ready after your meeting'), findsOneWidget);
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Break ready after your meeting'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color!.a, closeTo(0.36, 0.01));
    },
  );

  for (final entry in {
    'hydration': Icons.water_drop_rounded,
    'stretch': Icons.self_improvement_rounded,
    'standup': Icons.directions_walk_rounded,
  }.entries) {
    testWidgets('${entry.key} reminder shows its own icon and wording', (
      tester,
    ) async {
      await pumpReminder(tester, reminderType: entry.key);
      expect(find.byIcon(entry.value), findsOneWidget);
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
        for (var s = 0; s < 100; s++) HealthReminderCopy.pill(type, Random(s)),
      };
      final lines = {
        for (var s = 0; s < 100; s++) HealthReminderCopy.text(type, Random(s)),
      };
      expect(pills.length, greaterThan(1), reason: '$type pill');
      expect(lines.length, greaterThan(1), reason: '$type text');
    }
  });
}
