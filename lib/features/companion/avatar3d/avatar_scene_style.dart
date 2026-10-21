import 'dart:math' as math;

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';

/// The scene-level styling the user is allowed to change.
///
/// The editor these companions came from exposes a great deal more than the
/// species and its colours: how the light falls, whether there is an outline
/// and how heavy it is, whether the thing casts a shadow, how big the face is
/// on the body. All of it was already in the scene data and none of it was
/// reachable from the app, so every companion wore exactly the look its
/// illustrator happened to pick.
///
/// Everything here is an *override*, and every field defaults to null meaning
/// "as authored". That matters: it keeps the stored form small, it survives
/// the scene data being revised, and a companion saved before this existed
/// still looks exactly as it did.
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

  /// Nothing overridden — the companion as its illustrator drew it.
  static const AvatarSceneStyle authored = AvatarSceneStyle();

  final bool? showOutline;

  /// Multiplier on the authored outline weight.
  final double? outlineWidth;

  final bool? showShadow;

  /// Degrees. Where the key light sits around the companion, and how high.
  final double? lightAzimuth;
  final double? lightElevation;

  /// Multiplier on the eyes and mouth together. Bigger reads younger.
  final double? faceScale;

  /// Multiplier on the distance between the eyes.
  final double? eyeSpacing;

  /// The white dot in each eye.
  final bool? eyeSparkle;

  final bool? nose;

  /// The ranges the UI offers, kept here so the sliders and the renderer
  /// cannot drift apart.
  static const double minOutlineWidth = 0.0;
  static const double maxOutlineWidth = 2.5;
  static const double minFaceScale = 0.7;
  static const double maxFaceScale = 1.45;
  static const double minEyeSpacing = 0.7;
  static const double maxEyeSpacing = 1.4;
  static const double minElevation = -20;
  static const double maxElevation = 85;

  /// Whether anything at all has been changed from the authored look.
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

  /// Applies these overrides to [scene].
  ///
  /// Called once when a scene resolves rather than per frame: none of it
  /// depends on what the pet is doing.
  AvatarScene applyTo(AvatarScene scene) {
    if (isAuthored) return scene;

    final width = outlineWidth;
    final outline = width == null
        ? scene.outlineStyle
        : AvatarOutlineStyle(
            color: scene.outlineStyle.color,
            opacity: scene.outlineStyle.opacity,
            // Scenes that shipped without an outline have nothing to scale, so
            // asking for a heavier one has to start from a real weight.
            width: (scene.outlineStyle.width == 0 ? 2.0 : scene.outlineStyle.width) *
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

    if (scale == null && spacing == null && eyeSparkle == null && nose == null) {
      return face;
    }

    return face.restyle(
      // The face scale moves the eyes apart as well as making them bigger;
      // growing the openings alone would just make them overlap.
      gap: face.gap * (scale ?? 1.0) * (spacing ?? 1.0),
      width: face.width * (scale ?? 1.0),
      height: face.height * (scale ?? 1.0),
      mouthWidth: face.mouthWidth * (scale ?? 1.0),
      mouthHeight: face.mouthHeight * (scale ?? 1.0),
      // The mouth sits at a fixed offset from the eyes, so it has to travel
      // with them or a larger face ends up with its mouth on its chin.
      mouthY: face.mouthY * (scale ?? 1.0),
      noseEnabled: nose ?? face.noseEnabled,
      highlightEnabled: eyeSparkle ?? face.highlightEnabled,
      highlightSize: face.highlightSize * (scale ?? 1.0),
    );
  }

  /// The form this is stored and transmitted in. Unchanged fields are left
  /// out entirely.
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

/// Where the style lives inside an [AvatarDefinition]'s free-form part map.
///
/// `parts` already travels intact through JSON, the IPC payload and the native
/// relay, so styling needed no new field on the definition and no migration of
/// anything already saved.
const String kAvatarStyleKey = 'sceneStyle';

/// Reads the style out of a definition's part map.
AvatarSceneStyle avatarStyleFrom(Map<String, dynamic> parts) {
  final raw = parts[kAvatarStyleKey];
  return raw is Map
      ? AvatarSceneStyle.fromJson(Map<String, dynamic>.from(raw))
      : AvatarSceneStyle.authored;
}

/// Returns [parts] with [style] written into it, or removed when it is back to
/// the authored look.
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

/// The authored light direction, for a UI that needs somewhere to start.
///
/// The editor's default, which is what the great majority of the scenes use.
const double kDefaultLightAzimuth = -35;
const double kDefaultLightElevation = 40;

/// Normalises an azimuth to -180..180 so a dial can wrap without the stored
/// value drifting.
double normaliseAzimuth(double degrees) {
  var value = degrees % 360;
  if (value > 180) value -= 360;
  if (value < -180) value += 360;
  return value;
}

/// Converts a light direction to the unit vector a preview dial draws.
({double x, double y}) lightVector(double azimuthDegrees) {
  final radians = azimuthDegrees * math.pi / 180;
  return (x: math.cos(radians), y: math.sin(radians));
}
