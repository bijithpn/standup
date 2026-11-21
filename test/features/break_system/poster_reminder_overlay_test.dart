import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_overlay.dart';

void main() {
  testWidgets(
    'shows the reminder-specific icon and text with no opaque background '
    "of its own — the parent overlay is responsible for the low-opacity "
    "scrim so the user's actual desktop stays visible behind it",
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 400),
      )..value = 1.0;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            color: Colors.transparent,
            child: PosterReminderOverlay(
              icon: CupertinoIcons.person_crop_circle,
              text: 'Watch your posture!',
              fadeAnimation: controller,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Watch your posture!'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_crop_circle), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
