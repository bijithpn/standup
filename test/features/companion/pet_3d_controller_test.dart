import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/pet_animation.dart';
import 'package:breakmate/features/companion/presentation/controllers/pet_3d_controller.dart';

void main() {
  group('Pet3DController & Orbit Camera', () {
    test('camera rotation and clamping', () {
      final controller = Pet3DController();

      expect(controller.cameraState.azimuth, equals(0.0));
      expect(controller.cameraState.elevation, equals(0.0));

      // Rotate azimuth and elevation
      controller.rotate(deltaAzimuth: 45.0, deltaElevation: 20.0);
      expect(controller.cameraState.azimuth, closeTo(45.0, 1e-5));
      expect(controller.cameraState.elevation, closeTo(20.0, 1e-5));

      // Elevation clamping to -45..+45
      controller.rotate(deltaAzimuth: 0.0, deltaElevation: 60.0);
      expect(controller.cameraState.elevation, equals(45.0));

      controller.resetCamera();
      expect(controller.cameraState.azimuth, equals(0.0));
      expect(controller.cameraState.elevation, equals(0.0));
      expect(controller.cameraState.distance, equals(1.0));
    });

    test('zoom with limits', () {
      final controller = Pet3DController();
      controller.zoom(1.5);
      expect(controller.cameraState.distance, closeTo(1.5, 1e-5));

      // Limit check
      controller.zoom(10.0);
      expect(controller.cameraState.distance, equals(3.0));

      controller.zoom(0.01);
      expect(controller.cameraState.distance, equals(0.5));
    });

    test('lookAt target updates pose', () {
      final controller = Pet3DController();
      controller.lookAt(x: 0.5, y: -0.2);

      expect(controller.pose.yaw, closeTo(0.5 * 0.48, 1e-5));
      expect(controller.pose.pitch, closeTo(0.2 * 0.38, 1e-5));
    });

    test('playAnimation & setExpression', () {
      final controller = Pet3DController();
      controller.playAnimation(PetAnimation.happy);
      expect(controller.currentAnimation, equals(PetAnimation.happy));

      controller.setExpression(PetExpression.excited);
      expect(controller.currentExpression, equals(PetExpression.excited));
    });
  });
}
