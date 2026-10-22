/// OneWorks authentic 3D Body Shapes
enum AvatarBodyShape {
  sphere('sphere'),
  ellipse('ellipse'),
  square('square'),
  rounded('rounded'),
  capsule('capsule'),
  teardrop('teardrop'),
  diamond('diamond'),
  trapezoid('trapezoid'),
  cone('cone'),
  frustum('frustum'),
  halfCone('half-cone');

  final String id;
  const AvatarBodyShape(this.id);

  static AvatarBodyShape fromId(String id) {
    for (final shape in AvatarBodyShape.values) {
      if (shape.id == id || shape.name == id) return shape;
    }
    return AvatarBodyShape.sphere;
  }
}

/// Geometric profile definition for superellipsoid / quadric surface generation
class AvatarShapeSpec {
  final double exponent;
  final double faceCurvature;
  final double faceScale;
  final String
  profile; // 'superellipsoid', 'cone', 'frustum', 'half-cone', 'teardrop', 'trapezoid'
  final double radiusX;
  final double radiusY;
  final double radiusZ;

  const AvatarShapeSpec({
    required this.exponent,
    required this.faceCurvature,
    required this.faceScale,
    required this.profile,
    required this.radiusX,
    required this.radiusY,
    required this.radiusZ,
  });

  static const Map<AvatarBodyShape, AvatarShapeSpec> specs = {
    AvatarBodyShape.capsule: AvatarShapeSpec(
      exponent: 0.52,
      faceCurvature: 0.52,
      faceScale: 0.52,
      profile: 'superellipsoid',
      radiusX: 150,
      radiusY: 109,
      radiusZ: 109,
    ),
    AvatarBodyShape.cone: AvatarShapeSpec(
      exponent: 1.0,
      faceCurvature: 0.8,
      faceScale: 0.8,
      profile: 'cone',
      radiusX: 139,
      radiusY: 139,
      radiusZ: 124,
    ),
    AvatarBodyShape.diamond: AvatarShapeSpec(
      exponent: 1.65,
      faceCurvature: 0.72,
      faceScale: 1.12,
      profile: 'superellipsoid',
      radiusX: 139,
      radiusY: 139,
      radiusZ: 106,
    ),
    AvatarBodyShape.ellipse: AvatarShapeSpec(
      exponent: 1.0,
      faceCurvature: 1.0,
      faceScale: 1.0,
      profile: 'superellipsoid',
      radiusX: 153,
      radiusY: 118,
      radiusZ: 122,
    ),
    AvatarBodyShape.frustum: AvatarShapeSpec(
      exponent: 1.0,
      faceCurvature: 0.72,
      faceScale: 0.72,
      profile: 'frustum',
      radiusX: 139,
      radiusY: 139,
      radiusZ: 124,
    ),
    AvatarBodyShape.halfCone: AvatarShapeSpec(
      exponent: 1.0,
      faceCurvature: 0.8,
      faceScale: 0.8,
      profile: 'half-cone',
      radiusX: 139,
      radiusY: 139,
      radiusZ: 124,
    ),
    AvatarBodyShape.rounded: AvatarShapeSpec(
      exponent: 0.5,
      faceCurvature: 0.55,
      faceScale: 0.5,
      profile: 'superellipsoid',
      radiusX: 132,
      radiusY: 132,
      radiusZ: 116,
    ),
    AvatarBodyShape.sphere: AvatarShapeSpec(
      exponent: 1.0,
      faceCurvature: 1.0,
      faceScale: 1.0,
      profile: 'superellipsoid',
      radiusX: 139,
      radiusY: 139,
      radiusZ: 139,
    ),
    AvatarBodyShape.square: AvatarShapeSpec(
      exponent: 0.3,
      faceCurvature: 0.28,
      faceScale: 0.38,
      profile: 'superellipsoid',
      radiusX: 132,
      radiusY: 132,
      radiusZ: 108,
    ),
    AvatarBodyShape.teardrop: AvatarShapeSpec(
      exponent: 0.78,
      faceCurvature: 0.7,
      faceScale: 0.72,
      profile: 'teardrop',
      radiusX: 132,
      radiusY: 148,
      radiusZ: 112,
    ),
    AvatarBodyShape.trapezoid: AvatarShapeSpec(
      exponent: 0.65,
      faceCurvature: 0.6,
      faceScale: 0.65,
      profile: 'trapezoid',
      radiusX: 140,
      radiusY: 135,
      radiusZ: 115,
    ),
  };
}
