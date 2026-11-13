import 'dart:math' as math;

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';

/// User-tunable overrides (outline, face scale, eye spacing, elevation) layered over an authored scene via applyTo.
class AvatarSceneStyle {
  const AvatarSceneStyle({
    this.showOutline,
    this.outlineWidth,
    this.showShadow,
    this.lightAzimuth,
    this.lightElevation,
    this.faceScale,
    this.eyeSpacing,
    this.eyeSparkle,
    this.nose,
  });

  static const AvatarSceneStyle authored = AvatarSceneStyle();

  final bool? showOutline;

  final double? outlineWidth;

  final bool? showShadow;

  final double? lightAzimuth;
  final double? lightElevation;

  final double? faceScale;

  final double? eyeSpacing;

  final bool? eyeSparkle;

  final bool? nose;

  static const double minOutlineWidth = 0.0;
  static const double maxOutlineWidth = 2.5;
  static const double minFaceScale = 0.7;
  static const double maxFaceScale = 1.45;
  static const double minEyeSpacing = 0.7;
  static const double maxEyeSpacing = 1.4;
  static const double minElevation = -20;
  static const double maxElevation = 85;

  bool get isAuthored =>
      showOutline == null &&
      outlineWidth == null &&
      showShadow == null &&
      lightAzimuth == null &&
      lightElevation == null &&
      faceScale == null &&
      eyeSpacing == null &&
      eyeSparkle == null &&
      nose == null;

  AvatarSceneStyle copyWith({
    bool? showOutline,
    double? outlineWidth,
    bool? showShadow,
    double? lightAzimuth,
    double? lightElevation,
    double? faceScale,
    double? eyeSpacing,
    bool? eyeSparkle,
    bool? nose,
  }) {
    return AvatarSceneStyle(
      showOutline: showOutline ?? this.showOutline,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      showShadow: showShadow ?? this.showShadow,
      lightAzimuth: lightAzimuth ?? this.lightAzimuth,
      lightElevation: lightElevation ?? this.lightElevation,
      faceScale: faceScale ?? this.faceScale,
      eyeSpacing: eyeSpacing ?? this.eyeSpacing,
      eyeSparkle: eyeSparkle ?? this.eyeSparkle,
      nose: nose ?? this.nose,
    );
  }

  AvatarScene applyTo(AvatarScene scene) {
    if (isAuthored) return scene;

    final width = outlineWidth;
    final outline = width == null
        ? scene.outlineStyle
        : AvatarOutlineStyle(
            color: scene.outlineStyle.color,
            opacity: scene.outlineStyle.opacity,

            width:
                (scene.outlineStyle.width == 0
                    ? 2.0
                    : scene.outlineStyle.width) *
                width.clamp(minOutlineWidth, maxOutlineWidth),
          );

    return scene.copyWith(
      faceStyle: _restyleFace(scene.faceStyle),
      outlineStyle: outline,
      showOutline: showOutline ?? scene.showOutline,
      showAvatarShadow: showShadow ?? scene.showAvatarShadow,
      lightAzimuth: lightAzimuth ?? scene.lightAzimuth,
      lightElevation: lightElevation == null
          ? scene.lightElevation
          : lightElevation!.clamp(minElevation, maxElevation),
    );
  }

  AvatarFaceStyle _restyleFace(AvatarFaceStyle face) {
    final scale = faceScale?.clamp(minFaceScale, maxFaceScale);
    final spacing = eyeSpacing?.clamp(minEyeSpacing, maxEyeSpacing);

    if (scale == null &&
        spacing == null &&
        eyeSparkle == null &&
        nose == null) {
      return face;
    }

    return face.restyle(
      gap: face.gap * (scale ?? 1.0) * (spacing ?? 1.0),
      width: face.width * (scale ?? 1.0),
      height: face.height * (scale ?? 1.0),
      mouthWidth: face.mouthWidth * (scale ?? 1.0),
      mouthHeight: face.mouthHeight * (scale ?? 1.0),

      mouthY: face.mouthY * (scale ?? 1.0),
      noseEnabled: nose ?? face.noseEnabled,
      highlightEnabled: eyeSparkle ?? face.highlightEnabled,
      highlightSize: face.highlightSize * (scale ?? 1.0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (showOutline != null) 'showOutline': showOutline,
    if (outlineWidth != null) 'outlineWidth': outlineWidth,
    if (showShadow != null) 'showShadow': showShadow,
    if (lightAzimuth != null) 'lightAzimuth': lightAzimuth,
    if (lightElevation != null) 'lightElevation': lightElevation,
    if (faceScale != null) 'faceScale': faceScale,
    if (eyeSpacing != null) 'eyeSpacing': eyeSpacing,
    if (eyeSparkle != null) 'eyeSparkle': eyeSparkle,
    if (nose != null) 'nose': nose,
  };

  static AvatarSceneStyle fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return authored;
    double? number(Object? value) =>
        value is num && value.isFinite ? value.toDouble() : null;

    return AvatarSceneStyle(
      showOutline: json['showOutline'] as bool?,
      outlineWidth: number(json['outlineWidth']),
      showShadow: json['showShadow'] as bool?,
      lightAzimuth: number(json['lightAzimuth']),
      lightElevation: number(json['lightElevation']),
      faceScale: number(json['faceScale']),
      eyeSpacing: number(json['eyeSpacing']),
      eyeSparkle: json['eyeSparkle'] as bool?,
      nose: json['nose'] as bool?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarSceneStyle &&
      other.showOutline == showOutline &&
      other.outlineWidth == outlineWidth &&
      other.showShadow == showShadow &&
      other.lightAzimuth == lightAzimuth &&
      other.lightElevation == lightElevation &&
      other.faceScale == faceScale &&
      other.eyeSpacing == eyeSpacing &&
      other.eyeSparkle == eyeSparkle &&
      other.nose == nose;

  @override
  int get hashCode => Object.hash(
    showOutline,
    outlineWidth,
    showShadow,
    lightAzimuth,
    lightElevation,
    faceScale,
    eyeSpacing,
    eyeSparkle,
    nose,
  );
}

const String kAvatarStyleKey = 'sceneStyle';

AvatarSceneStyle avatarStyleFrom(Map<String, dynamic> parts) {
  final raw = parts[kAvatarStyleKey];
  return raw is Map
      ? AvatarSceneStyle.fromJson(Map<String, dynamic>.from(raw))
      : AvatarSceneStyle.authored;
}

Map<String, dynamic> withAvatarStyle(
  Map<String, dynamic> parts,
  AvatarSceneStyle style,
) {
  final next = Map<String, dynamic>.from(parts);
  if (style.isAuthored) {
    next.remove(kAvatarStyleKey);
  } else {
    next[kAvatarStyleKey] = style.toJson();
  }
  return next;
}

const double kDefaultLightAzimuth = -35;
const double kDefaultLightElevation = 40;

double normaliseAzimuth(double degrees) {
  var value = degrees % 360;
  if (value > 180) value -= 360;
  if (value < -180) value += 360;
  return value;
}

({double x, double y}) lightVector(double azimuthDegrees) {
  final radians = azimuthDegrees * math.pi / 180;
  return (x: math.cos(radians), y: math.sin(radians));
}
