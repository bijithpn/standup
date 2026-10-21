import 'dart:math' as math;

import 'package:breakmate/features/companion/avatar3d/avatar_math.dart';

/// The primitive solids an avatar is built from, and how to sample them.
///
/// Ported from `avatarGeometry.ts`. Every radius and exponent below is authored
/// data from the editor — the shapes only read as the same creatures if these
/// match exactly.

enum AvatarBodyShape {
  sphere,
  ellipse,
  square,
  rounded,
  capsule,
  teardrop,
  diamond,
  trapezoid,
  cone,
  frustum,
  halfCone;

  /// The wire name used by the scene data.
  String get wireName => this == AvatarBodyShape.halfCone ? 'half-cone' : name;

  static AvatarBodyShape fromWire(String? value) {
    switch (value) {
      case 'half-cone':
        return AvatarBodyShape.halfCone;
      case null:
        return AvatarBodyShape.sphere;
      default:
        for (final shape in AvatarBodyShape.values) {
          if (shape.name == value) return shape;
        }
        return AvatarBodyShape.sphere;
    }
  }
}

/// How a primitive's surface is generated.
enum ShapeProfile { superellipsoid, cone, frustum, halfCone, teardrop, trapezoid }

class ShapeSpec {
  const ShapeSpec({
    required this.exponent,
    required this.faceCurvature,
    required this.faceScale,
    required this.profile,
    required this.radiusX,
    required this.radiusY,
    required this.radiusZ,
  });

  final double exponent;
  final double faceCurvature;
  final double faceScale;
  final ShapeProfile profile;
  final double radiusX;
  final double radiusY;
  final double radiusZ;
}

const Map<AvatarBodyShape, ShapeSpec> kShapeSpecs = <AvatarBodyShape, ShapeSpec>{
  AvatarBodyShape.capsule: ShapeSpec(
    exponent: 0.52,
    faceCurvature: 0.52,
    faceScale: 0.52,
    profile: ShapeProfile.superellipsoid,
    radiusX: 150,
    radiusY: 109,
    radiusZ: 109,
  ),
  AvatarBodyShape.cone: ShapeSpec(
    exponent: 1,
    faceCurvature: 0.8,
    faceScale: 0.8,
    profile: ShapeProfile.cone,
    radiusX: 139,
    radiusY: 139,
    radiusZ: 124,
  ),
  AvatarBodyShape.diamond: ShapeSpec(
    exponent: 1.65,
    faceCurvature: 0.72,
    faceScale: 1.12,
    profile: ShapeProfile.superellipsoid,
    radiusX: 139,
    radiusY: 139,
    radiusZ: 106,
  ),
  AvatarBodyShape.ellipse: ShapeSpec(
    exponent: 1,
    faceCurvature: 1,
    faceScale: 1,
    profile: ShapeProfile.superellipsoid,
    radiusX: 153,
    radiusY: 118,
    radiusZ: 122,
  ),
  AvatarBodyShape.frustum: ShapeSpec(
    exponent: 1,
    faceCurvature: 0.72,
    faceScale: 0.72,
    profile: ShapeProfile.frustum,
    radiusX: 139,
    radiusY: 139,
    radiusZ: 124,
  ),
  AvatarBodyShape.halfCone: ShapeSpec(
    exponent: 1,
    faceCurvature: 0.8,
    faceScale: 0.8,
    profile: ShapeProfile.halfCone,
    radiusX: 139,
    radiusY: 139,
    radiusZ: 124,
  ),
  AvatarBodyShape.rounded: ShapeSpec(
    exponent: 0.5,
    faceCurvature: 0.55,
    faceScale: 0.5,
    profile: ShapeProfile.superellipsoid,
    radiusX: 132,
    radiusY: 132,
    radiusZ: 116,
  ),
  AvatarBodyShape.sphere: ShapeSpec(
    exponent: 1,
    faceCurvature: 1,
    faceScale: 1,
    profile: ShapeProfile.superellipsoid,
    radiusX: 139,
    radiusY: 139,
    radiusZ: 139,
  ),
  AvatarBodyShape.square: ShapeSpec(
    exponent: 0.3,
    faceCurvature: 0.28,
    faceScale: 0.38,
    profile: ShapeProfile.superellipsoid,
    radiusX: 132,
    radiusY: 132,
    radiusZ: 108,
  ),
  AvatarBodyShape.teardrop: ShapeSpec(
    exponent: 0.78,
    faceCurvature: 0.7,
    faceScale: 0.72,
    profile: ShapeProfile.teardrop,
    radiusX: 132,
    radiusY: 148,
    radiusZ: 112,
  ),
  AvatarBodyShape.trapezoid: ShapeSpec(
    exponent: 0.56,
    faceCurvature: 0.62,
    faceScale: 0.72,
    profile: ShapeProfile.trapezoid,
    radiusX: 142,
    radiusY: 132,
    radiusZ: 116,
  ),
};

/// Per-part modifiers that change how its primitive is sampled.
class ShapeOptions {
  const ShapeOptions({
    this.bottomTaper = 0,
    this.cutAngle = 0,
    this.roundness,
    this.topScale,
    this.faceOffsetY = 0,
  });

  final double bottomTaper;
  final double cutAngle;

  /// Null means "use this profile's own default", which differs per profile.
  final double? roundness;
  final double? topScale;
  final double faceOffsetY;

  static const ShapeOptions none = ShapeOptions();
}

/// Keeps the ellipse profile's lower pole rounded instead of collapsing it
/// into a sharp V when a bottom taper is applied.
double _ellipseLowerTaper(
  ShapeSpec spec,
  double vertical,
  ShapeOptions options,
) {
  if (spec.profile != ShapeProfile.superellipsoid ||
      spec.radiusX != 153 ||
      options.bottomTaper <= 0) {
    return 1;
  }
  final intensity = clampDouble(options.bottomTaper, 0, 100) / 100;
  return 1 - intensity * 0.62 * math.pow(math.max(vertical, 0), 2).toDouble();
}

/// A point on the primitive's surface at the given longitude and latitude.
Vec3 surfacePoint(
  ShapeSpec spec,
  double longitude,
  double latitude, {
  bool faceCoordinates = false,
  ShapeOptions options = ShapeOptions.none,
}) {
  switch (spec.profile) {
    case ShapeProfile.teardrop:
      {
        final scale = faceCoordinates ? spec.faceScale : 1.0;
        final lon = longitude * scale;
        final lat = latitude * scale;
        final vertical = signedPow(math.sin(lat), spec.exponent);
        final progress = clampDouble((vertical + 1) / 2, 0, 1);
        final latitudeRadius = math.max(math.cos(lat), 0.0);
        final latitudeFactor = math.pow(latitudeRadius, spec.exponent).toDouble();
        final widthTaper = interpolate(0.46, 1.24, progress);
        final depthTaper = interpolate(0.7, 1.12, progress);

        return Vec3(
          spec.radiusX *
              widthTaper *
              latitudeFactor *
              signedPow(math.sin(lon), spec.exponent),
          spec.radiusY * vertical,
          spec.radiusZ *
              depthTaper *
              latitudeFactor *
              signedPow(math.cos(lon), spec.exponent),
        );
      }

    case ShapeProfile.trapezoid:
      {
        final scale = faceCoordinates ? spec.faceScale : 1.0;
        final lon = longitude * scale;
        final lat = latitude * scale;
        final roundness = clampDouble(options.roundness ?? 72, 0, 100) / 100;
        final exponent = interpolate(0.34, 0.76, roundness);
        final latitudeRadius = math.max(math.cos(lat), 0.0);
        final latitudeFactor = math.pow(latitudeRadius, exponent).toDouble();
        final vertical = signedPow(math.sin(lat), exponent);
        final progress = clampDouble((vertical + 1) / 2, 0, 1);
        final horizontalTaper =
            interpolate(options.topScale ?? 0.82, 1.08, progress);
        final depthTaper = interpolate(0.92, 1.04, progress);

        return Vec3(
          spec.radiusX *
              horizontalTaper *
              latitudeFactor *
              signedPow(math.sin(lon), exponent),
          spec.radiusY * vertical,
          spec.radiusZ *
              depthTaper *
              latitudeFactor *
              signedPow(math.cos(lon), exponent),
        );
      }

    case ShapeProfile.cone:
    case ShapeProfile.frustum:
    case ShapeProfile.halfCone:
      {
        if (faceCoordinates) break;
        final progress = clampDouble((latitude + math.pi / 2) / math.pi, 0, 1);
        final roundness = clampDouble(options.roundness ?? 24, 0, 100) / 100;
        final eased = progress * progress * (3 - 2 * progress);
        // A sub-linear radius keeps a true zero-radius apex while giving the
        // tip a rounded shoulder; a frustum instead eases toward a flat top.
        final tapered = spec.profile == ShapeProfile.frustum
            ? interpolate(progress, eased, roundness * 0.55)
            : math.pow(progress, interpolate(1, 0.56, roundness)).toDouble();
        final tipRatio = spec.profile == ShapeProfile.frustum ? 0.46 : 0.0;
        final ringRadius = interpolate(tipRatio, 1, tapered);
        final cutAngle = options.cutAngle * math.pi / 180;
        final sampledLongitude = spec.profile == ShapeProfile.halfCone
            ? cutAngle + longitude / 2
            : longitude;

        return Vec3(
          spec.radiusX * ringRadius * math.sin(sampledLongitude),
          spec.radiusY * (progress * 2 - 1),
          spec.radiusZ * ringRadius * math.cos(sampledLongitude),
        );
      }

    case ShapeProfile.superellipsoid:
      break;
  }

  final scale = faceCoordinates ? spec.faceScale : 1.0;
  final lon = longitude * scale;
  final lat = latitude * scale;
  final latitudeRadius = math.max(math.cos(lat), 0.0);
  final latitudeFactor = math.pow(latitudeRadius, spec.exponent).toDouble();
  final vertical = signedPow(math.sin(lat), spec.exponent);
  final lowerTaper = _ellipseLowerTaper(spec, vertical, options);

  return Vec3(
    spec.radiusX *
        latitudeFactor *
        lowerTaper *
        signedPow(math.sin(lon), spec.exponent),
    spec.radiusY * vertical,
    spec.radiusZ *
        latitudeFactor *
        lowerTaper *
        signedPow(math.cos(lon), spec.exponent),
  );
}

const double _normalDelta = 0.006;

/// The outward normal, taken from two neighbouring surface samples.
Vec3 surfaceNormal(
  ShapeSpec spec,
  double longitude,
  double latitude, {
  bool faceCoordinates = false,
  ShapeOptions options = ShapeOptions.none,
}) {
  final center = surfacePoint(
    spec,
    longitude,
    latitude,
    faceCoordinates: faceCoordinates,
    options: options,
  );
  final alongLongitude = surfacePoint(
    spec,
    longitude + _normalDelta,
    latitude,
    faceCoordinates: faceCoordinates,
    options: options,
  );
  final alongLatitude = surfacePoint(
    spec,
    longitude,
    latitude + _normalDelta,
    faceCoordinates: faceCoordinates,
    options: options,
  );

  return normalize(
    cross(
      subtract(alongLongitude, center),
      subtract(alongLatitude, center),
    ),
  );
}

/// Lifts a point from the flat face chart onto the primitive's surface.
///
/// The face is authored in 2D and then bowed outward by `faceCurvature`, which
/// is what keeps eyes sitting *on* a round head rather than floating in front
/// of it. The extra 0.8 lifts the feature clear of the body so it never
/// z-fights with the surface underneath.
Vec3 facePoint(
  ShapeSpec spec,
  Vec2 point, {
  ShapeOptions options = ShapeOptions.none,
}) {
  final normalizedRadius = math.min(
    point.x * point.x / (spec.radiusX * spec.radiusX) +
        point.y * point.y / (spec.radiusY * spec.radiusY),
    0.98,
  );
  final curvedDepth = math.sqrt(1 - normalizedRadius);
  final depth = spec.radiusZ * (1 - spec.faceCurvature * (1 - curvedDepth));
  return Vec3(point.x, point.y, depth + 0.8);
}

Vec3 faceNormal(
  ShapeSpec spec,
  Vec2 point, {
  ShapeOptions options = ShapeOptions.none,
}) {
  final surface = facePoint(spec, point, options: options);
  return normalize(
    Vec3(
      point.x / (spec.radiusX * spec.radiusX),
      point.y / (spec.radiusY * spec.radiusY),
      surface.z / (spec.radiusZ * spec.radiusZ),
    ),
  );
}
