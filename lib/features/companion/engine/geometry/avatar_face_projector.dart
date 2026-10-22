import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:breakmate/features/companion/engine/geometry/avatar_body_shapes.dart';
import 'package:breakmate/features/companion/engine/geometry/vec3.dart';

class ProjectedFace3D {
  final bool isVisible;
  final List<ui.Offset> leftEyePoints;
  final List<ui.Offset> rightEyePoints;
  final List<ui.Offset>? mouthPoints;
  final List<ui.Offset>? nosePoints;
  final double meanDepth;

  const ProjectedFace3D({
    required this.isVisible,
    required this.leftEyePoints,
    required this.rightEyePoints,
    this.mouthPoints,
    this.nosePoints,
    required this.meanDepth,
  });

  static const ProjectedFace3D invisible = ProjectedFace3D(
    isVisible: false,
    leftEyePoints: [],
    rightEyePoints: [],
    meanDepth: -1000.0,
  );
}

/// Native Dart port of OneWorks 3D face projection & horizon occlusion (`avatarGeometry.ts`)
class AvatarFaceProjector {
  static ProjectedFace3D projectFace({
    required AvatarBodyShape shape,
    required double yaw,
    required double pitch,
    required double roll,
    double eyeGap = 40.0,
    double eyeWidth = 28.0,
    double eyeHeight = 54.0,
    double eyeRoundness = 100.0,
    double leftEyeTilt = 0.0,
    double rightEyeTilt = 0.0,
    bool hasMouth = false,
    double mouthWidth = 48.0,
    double mouthHeight = 12.0,
    double mouthCurve = 45.0,
    double mouthOffsetY = 52.0,
    bool hasNose = false,
    double noseWidth = 12.0,
    double noseHeight = 14.0,
    double noseOffsetY = 22.0,
    ui.Offset centerOffset = const ui.Offset(210, 202),
  }) {
    // 1. Calculate the 3D surface normal at the face anchor
    // Face center in canonical object space is pointing towards +Z (latitude 0, longitude 0)
    var faceNormal = const Vec3(0, 0, 1);
    if (yaw != 0.0) faceNormal = faceNormal.rotateY(yaw);
    if (pitch != 0.0) faceNormal = faceNormal.rotateX(pitch);
    if (roll != 0.0) faceNormal = faceNormal.rotateZ(roll);

    // Horizon occlusion check: if face is pointing away from viewer into the screen (+Z is viewer), occlude!
    if (faceNormal.z <= 0.05) {
      return ProjectedFace3D.invisible;
    }

    final spec =
        AvatarShapeSpec.specs[shape] ??
        AvatarShapeSpec.specs[AvatarBodyShape.sphere]!;
    final radiusX = spec.radiusX;
    final radiusY = spec.radiusY;
    final radiusZ = spec.radiusZ;

    Vec3 project2DTo3DSurface(double localX, double localY) {
      // Normalizes 2D local face coords onto curved surface of body
      final normX = (localX / radiusX).clamp(-0.95, 0.95);
      final normY = (localY / radiusY).clamp(-0.95, 0.95);

      final lat = math.asin(normY);
      final cosLat = math.max(math.cos(lat), 0.01);
      final lon = math.asin((normX / cosLat).clamp(-0.95, 0.95));

      final surfacePoint = Vec3(
        radiusX * cosLat * math.sin(lon),
        radiusY * math.sin(lat),
        radiusZ * cosLat * math.cos(lon),
      );

      var worldP = surfacePoint;
      if (yaw != 0.0) worldP = worldP.rotateY(yaw);
      if (pitch != 0.0) worldP = worldP.rotateX(pitch);
      if (roll != 0.0) worldP = worldP.rotateZ(roll);

      return worldP;
    }

    ui.Offset toScreen(Vec3 worldP) {
      return ui.Offset(centerOffset.dx + worldP.x, centerOffset.dy + worldP.y);
    }

    // Helper to generate rounded rectangle eye polygon
    List<ui.Offset> buildEyePolygon(
      double eyeCenterX,
      double eyeCenterY,
      double tilt,
    ) {
      final points = <ui.Offset>[];
      const steps = 16;
      final hw = eyeWidth / 2.0;
      final hh = eyeHeight / 2.0;

      for (int i = 0; i < steps; i++) {
        final theta = (i / steps) * math.pi * 2.0;
        final rawX = math.cos(theta) * hw;
        final rawY = math.sin(theta) * hh;

        // Apply individual eye tilt
        final cosT = math.cos(tilt);
        final sinT = math.sin(tilt);
        final tiltedX = rawX * cosT - rawY * sinT;
        final tiltedY = rawX * sinT + rawY * cosT;

        final localX = eyeCenterX + tiltedX;
        final localY = eyeCenterY + tiltedY;

        final p3D = project2DTo3DSurface(localX, localY);
        points.add(toScreen(p3D));
      }
      return points;
    }

    final leftEyeCenterX = -(eyeGap / 2.0) - (eyeWidth / 2.0);
    final rightEyeCenterX = (eyeGap / 2.0) + (eyeWidth / 2.0);
    const eyeCenterY = -10.0;

    final leftEye = buildEyePolygon(leftEyeCenterX, eyeCenterY, leftEyeTilt);
    final rightEye = buildEyePolygon(rightEyeCenterX, eyeCenterY, rightEyeTilt);

    // Mouth projection
    List<ui.Offset>? mouth;
    if (hasMouth) {
      mouth = [];
      const mouthSteps = 16;
      final halfMouthW = mouthWidth / 2.0;
      for (int i = 0; i <= mouthSteps; i++) {
        final t = (i / mouthSteps) * 2.0 - 1.0; // -1 to +1
        final mx = t * halfMouthW;
        // Curve equation: parabola
        final my = mouthOffsetY + (t * t - 1.0) * (mouthCurve * 0.2);
        final p3D = project2DTo3DSurface(mx, my);
        mouth.add(toScreen(p3D));
      }
    }

    // Nose projection
    List<ui.Offset>? nose;
    if (hasNose) {
      nose = [];
      final pTop = project2DTo3DSurface(0, noseOffsetY - noseHeight / 2.0);
      final pBottomLeft = project2DTo3DSurface(
        -noseWidth / 2.0,
        noseOffsetY + noseHeight / 2.0,
      );
      final pBottomRight = project2DTo3DSurface(
        noseWidth / 2.0,
        noseOffsetY + noseHeight / 2.0,
      );
      nose.addAll([
        toScreen(pTop),
        toScreen(pBottomLeft),
        toScreen(pBottomRight),
      ]);
    }

    final centerFaceP = project2DTo3DSurface(0, 0);

    return ProjectedFace3D(
      isVisible: true,
      leftEyePoints: leftEye,
      rightEyePoints: rightEye,
      mouthPoints: mouth,
      nosePoints: nose,
      meanDepth: centerFaceP.z,
    );
  }
}
