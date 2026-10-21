import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/presentation/controllers/pet_3d_controller.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_3d_view.dart';

void main() {
  group('Pet3DView Widget', () {
    testWidgets('renders native 3D geometry painter and reacts to drag gestures', (tester) async {
      final controller = Pet3DController();
      final definition = AvatarDefinition.fromSpecies(AvatarSpecies.cat);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Pet3DView(
                  controller: controller,
                  definition: definition,
                  enableRotation: true,
                  enableZoom: true,
                  autoRotate: false,
                  transparentBackground: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Pet3DView), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify drag rotates camera in controller
      expect(controller.cameraState.azimuth, equals(0.0));
      await tester.drag(find.byType(Pet3DView), const Offset(40, 20));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.cameraState.azimuth, isNot(equals(0.0)));
    });

    testWidgets('double tap resets camera', (tester) async {
      final controller = Pet3DController();
      final definition = AvatarDefinition.fromSpecies(AvatarSpecies.dog);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Pet3DView(
                  controller: controller,
                  definition: definition,
                ),
              ),
            ),
          ),
        ),
      );

      controller.rotate(deltaAzimuth: 60.0, deltaElevation: 20.0);
      expect(controller.cameraState.azimuth, equals(60.0));

      await tester.tap(find.byType(Pet3DView));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(Pet3DView));
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.cameraState.azimuth, equals(0.0));
      expect(controller.cameraState.elevation, equals(0.0));
    });
  });
}
