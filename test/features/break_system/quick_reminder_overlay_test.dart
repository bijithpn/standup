// Regression coverage: posture/eye-rest/meeting-break reminders must render
// the minimal pill (icon + short label), never the old full break template
// with long instructional copy.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets(
    'posture reminder shows only the minimal pill: icon + short label',
    (tester) async {
      await pumpReminder(tester, reminderType: 'posture');

      expect(find.text('Posture check'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_crop_circle), findsOneWidget);

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

      expect(find.text('Rest your eyes'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.eye_fill), findsOneWidget);
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
    expect(find.byIcon(CupertinoIcons.videocam_fill), findsOneWidget);
  });

  testWidgets(
    'the pill uses a translucent dark background, not the full break card style',
    (tester) async {
      await pumpReminder(tester, reminderType: 'posture');

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Posture check'),
              matching: find.byType(Container),
            )
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

    expect(find.text('Posture check'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person_crop_circle), findsOneWidget);
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
}
