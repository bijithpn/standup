import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/engine/geometry/avatar_body_shapes.dart';
import 'package:breakmate/features/companion/engine/geometry/avatar_face_projector.dart';

void main() {
  group('AvatarFaceProjector', () {
    test('projects front-facing eyes onto curved 3D surface', () {
      final face = AvatarFaceProjector.projectFace(
        shape: AvatarBodyShape.sphere,
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        eyeGap: 40.0,
        eyeWidth: 28.0,
        eyeHeight: 54.0,
      );

      expect(face.isVisible, isTrue);
      expect(face.leftEyePoints.isNotEmpty, isTrue);
      expect(face.rightEyePoints.isNotEmpty, isTrue);
      expect(face.leftEyePoints.first.dx, lessThan(face.rightEyePoints.first.dx));
    });

    test('occludes face when avatar rotates toward the back (> 90 degrees)', () {
      final backFace = AvatarFaceProjector.projectFace(
        shape: AvatarBodyShape.sphere,
        yaw: math.pi, // 180 degrees (looking away)
        pitch: 0.0,
        roll: 0.0,
      );

      expect(backFace.isVisible, isFalse);
    });

    test('projects mouth and nose when enabled', () {
      final faceWithMouthNose = AvatarFaceProjector.projectFace(
        shape: AvatarBodyShape.sphere,
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        hasMouth: true,
        mouthWidth: 48.0,
        mouthCurve: 20.0,
        hasNose: true,
        noseWidth: 16.0,
        noseHeight: 14.0,
      );

      expect(faceWithMouthNose.mouthPoints, isNotNull);
      expect(faceWithMouthNose.mouthPoints!.isNotEmpty, isTrue);
      expect(faceWithMouthNose.nosePoints, isNotNull);
      expect(faceWithMouthNose.nosePoints!.isNotEmpty, isTrue);
    });
  });
}
