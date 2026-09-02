import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/animated_nature_backdrop.dart';

void main() {
  testWidgets('builds and animates several frames without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedNatureBackdrop(
            baseColorTop: Color(0xFF0D1F16),
            baseColorBottom: Color(0xFF060B08),
            blobColors: [Color(0xFF2D6A4F), Color(0xFF74C69D), Color(0xFF1B4332)],
          ),
        ),
      ),
    );
    expect(find.byType(AnimatedNatureBackdrop), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposes its controllers cleanly on unmount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedNatureBackdrop(
            baseColorTop: Color(0xFF1E3A8A),
            baseColorBottom: Color(0xFF1E1B4B),
            blobColors: [Color(0xFFF97316), Color(0xFF3B82F6)],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
