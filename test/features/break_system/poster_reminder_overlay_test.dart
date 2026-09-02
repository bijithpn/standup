import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_overlay.dart';

void main() {
  testWidgets('shows the icon and text over a full-bleed animated background', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PosterReminderOverlay(
            icon: CupertinoIcons.person_crop_circle,
            text: 'Posture check',
            fadeAnimation: controller,
            baseColorTop: const Color(0xFF1E3A8A),
            baseColorBottom: const Color(0xFF1E1B4B),
            blobColors: const [Color(0xFFF97316), Color(0xFF3B82F6)],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Posture check'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person_crop_circle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
