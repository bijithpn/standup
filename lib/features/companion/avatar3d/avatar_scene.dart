import 'dart:ui' show Color;

import 'package:breakmate/features/companion/avatar3d/avatar_shape.dart';

/// The authored description of one companion: a handful of 3D primitives, a
/// face, a camera and a light.
///
/// This mirrors the editor's own data model so scenes exported from it drop
/// straight in. Everything here is plain data — no Flutter bindings — so it can
/// be built on a background isolate.

Color? _parseColor(Object? value) {
  if (value is! String) return null;
  var hex = value.startsWith('#') ? value.substring(1) : value;
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length == 6) {
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
  if (hex.length == 8) {
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(((parsed & 0xFF) << 24) | (parsed >> 8));
  }
  return null;
}

double _toDouble(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

/// One primitive in the scene, with its placement and its own four colours.
class AvatarPart {
  const AvatarPart({
    required this.id,
    required this.shape,
    required this.x,
    required this.y,
    required this.z,
    required this.scaleX,
    required this.scaleY,
    required this.scaleZ,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.baseColor,
    required this.foregroundColor,
    required this.highlightColor,
    required this.shadowColor,
    required this.hasFace,
    required this.occludedByFace,
    this.roundness,
    this.topScale,
    this.bottomTaper = 0,
    this.cutAngle = 0,
    this.label = '',
  });

  final String id;
  final String label;
  final AvatarBodyShape shape;

  /// Placement in authored scene units.
  final double x;
  final double y;
  final double z;

  final double scaleX;
  final double scaleY;
  final double scaleZ;

  final double rotationX;
  final double rotationY;
  final double rotationZ;

  /// The body colour, its outline/ink, its lit side and its shadowed side.
  final Color baseColor;
  final Color foregroundColor;
  final Color highlightColor;
  final Color shadowColor;

  /// Whether the face is drawn on this part.
  final bool hasFace;

  /// Whether the face's part should draw over this one.
  final bool occludedByFace;

  final double? roundness;
  final double? topScale;
  final double bottomTaper;
  final double cutAngle;

  ShapeOptions get shapeOptions => ShapeOptions(
        bottomTaper: bottomTaper,
        cutAngle: cutAngle,
        roundness: roundness,
        topScale: topScale,
      );

  static AvatarPart? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) return null;

    final base = _parseColor(json['baseColor']);
    if (base == null) return null;

    return AvatarPart(
      id: id,
      label: json['label'] as String? ?? '',
      shape: AvatarBodyShape.fromWire(json['shape'] as String?),
      x: _toDouble(json['x'], 0),
      y: _toDouble(json['y'], 0),
      z: _toDouble(json['z'], 0),
      scaleX: _toDouble(json['scaleX'], 1),
      scaleY: _toDouble(json['scaleY'], 1),
      scaleZ: _toDouble(json['scaleZ'], _toDouble(json['scaleX'], 1)),
      rotationX: _toDouble(json['rotationX'], 0),
      rotationY: _toDouble(json['rotationY'], 0),
      rotationZ: _toDouble(json['rotationZ'], 0),
      baseColor: base,
      foregroundColor:
          _parseColor(json['foregroundColor']) ?? const Color(0xFF101010),
      highlightColor: _parseColor(json['highlightColor']) ?? base,
      shadowColor: _parseColor(json['shadowColor']) ?? base,
      hasFace: json['face'] == true,
      occludedByFace: json['occludedByFace'] == true,
      roundness: json['roundness'] is num
          ? (json['roundness'] as num).toDouble()
          : null,
      topScale:
          json['topScale'] is num ? (json['topScale'] as num).toDouble() : null,
      bottomTaper: _toDouble(json['bottomTaper'], 0),
      cutAngle: _toDouble(json['cutAngle'], 0),
    );
  }
}

/// Where the camera sits. Yaw and pitch are what make the companion turn.
class AvatarViewState {
  const AvatarViewState({
    this.pitch = 0,
    this.yaw = 0,
    this.roll = 0,
    this.scale = 1,
    this.positionX = 0,
    this.positionY = 0,
  });

  final double pitch;
  final double yaw;
  final double roll;
  final double scale;
  final double positionX;
  final double positionY;

  AvatarViewState copyWith({
    double? pitch,
    double? yaw,
    double? roll,
    double? scale,
    double? positionX,
    double? positionY,
  }) {
    return AvatarViewState(
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      roll: roll ?? this.roll,
      scale: scale ?? this.scale,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
    );
  }

  static AvatarViewState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AvatarViewState();
    return AvatarViewState(
      pitch: _toDouble(json['pitch'], 0),
      yaw: _toDouble(json['yaw'], 0),
      roll: _toDouble(json['roll'], 0),
      scale: _toDouble(json['scale'], 1),
      positionX: _toDouble(json['positionX'], 0),
      positionY: _toDouble(json['positionY'], 0),
    );
  }
}

class AvatarOutlineStyle {
  const AvatarOutlineStyle({
    required this.color,
    required this.opacity,
    required this.width,
  });

  final Color color;

  /// 0–100, as the editor stores it.
  final double opacity;
  final double width;

  static const AvatarOutlineStyle none =
      AvatarOutlineStyle(color: Color(0xFF000000), opacity: 0, width: 0);

  static AvatarOutlineStyle fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    return AvatarOutlineStyle(
      color: _parseColor(json['color']) ?? const Color(0xFF000000),
      opacity: _toDouble(json['opacity'], 0),
      width: _toDouble(json['width'], 0),
    );
  }
}

class AvatarShadowStyle {
  const AvatarShadowStyle({
    required this.color,
    required this.direction,
    required this.distance,
    required this.opacity,
    required this.softness,
  });

  final Color color;

  /// Degrees; 0 points right, increasing anticlockwise as the editor draws it.
  final double direction;
  final double distance;
  final double opacity;
  final double softness;

  static const AvatarShadowStyle none = AvatarShadowStyle(
    color: Color(0xFF000000),
    direction: 0,
    distance: 0,
    opacity: 0,
    softness: 0,
  );

  static AvatarShadowStyle fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    return AvatarShadowStyle(
      color: _parseColor(json['color']) ?? const Color(0xFF000000),
      direction: _toDouble(json['direction'], 0),
      distance: _toDouble(json['distance'], 0),
      opacity: _toDouble(json['opacity'], 0),
      softness: _toDouble(json['softness'], 0),
    );
  }
}

/// The face chart: two eyes, an optional nose and mouth, in authored units.
class AvatarFaceStyle {
  const AvatarFaceStyle({
    this.gap = 42,
    this.width = 22,
    this.height = 64,
    this.rotation = 0,
    this.leftEyeRotation = 0,
    this.rightEyeRotation = 0,
    this.eyeShape = 'rounded',
    this.eyeRoundness = 100,
    this.noseEnabled = false,
    this.noseShape = 'ellipse',
    this.noseWidth = 16,
    this.noseHeight = 11,
    this.noseY = 30,
    this.noseRotation = 0,
    this.mouthEnabled = false,
    this.mouthShape = 'curve',
    this.mouthWidth = 52,
    this.mouthHeight = 12,
    this.mouthY = 52,
    this.mouthCurve = 45,
    this.mouthRotation = 0,
    this.highlightEnabled = false,
    this.highlightColor = const Color(0xFFFFFFFF),
    this.highlightOffsetX = -18,
    this.highlightOffsetY = -20,
    this.highlightOpacity = 92,
    this.highlightSize = 24,
  });

  final double gap;
  final double width;
  final double height;
  final double rotation;
  final double leftEyeRotation;
  final double rightEyeRotation;
  final String eyeShape;
  final double eyeRoundness;

  final bool noseEnabled;
  final String noseShape;
  final double noseWidth;
  final double noseHeight;
  final double noseY;
  final double noseRotation;

  final bool mouthEnabled;
  final String mouthShape;
  final double mouthWidth;
  final double mouthHeight;
  final double mouthY;
  final double mouthCurve;
  final double mouthRotation;

  final bool highlightEnabled;
  final Color highlightColor;
  final double highlightOffsetX;
  final double highlightOffsetY;
  final double highlightOpacity;
  final double highlightSize;

  /// Scales the eye openings, for blinking. 0 is shut, 1 is the authored size.
  AvatarFaceStyle withEyeOpenness(double openness) {
    if (openness >= 0.999) return this;
    return copyWith(height: height * openness.clamp(0.02, 1.0));
  }

  AvatarFaceStyle copyWith({double? height, double? gap}) {
    return AvatarFaceStyle(
      gap: gap ?? this.gap,
      width: width,
      height: height ?? this.height,
      rotation: rotation,
      leftEyeRotation: leftEyeRotation,
      rightEyeRotation: rightEyeRotation,
      eyeShape: eyeShape,
      eyeRoundness: eyeRoundness,
      noseEnabled: noseEnabled,
      noseShape: noseShape,
      noseWidth: noseWidth,
      noseHeight: noseHeight,
      noseY: noseY,
      noseRotation: noseRotation,
      mouthEnabled: mouthEnabled,
      mouthShape: mouthShape,
      mouthWidth: mouthWidth,
      mouthHeight: mouthHeight,
      mouthY: mouthY,
      mouthCurve: mouthCurve,
      mouthRotation: mouthRotation,
      highlightEnabled: highlightEnabled,
      highlightColor: highlightColor,
      highlightOffsetX: highlightOffsetX,
      highlightOffsetY: highlightOffsetY,
      highlightOpacity: highlightOpacity,
      highlightSize: highlightSize,
    );
  }

  static AvatarFaceStyle fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AvatarFaceStyle();
    final highlight = json['eyeHighlight'];
    final highlightMap =
        highlight is Map ? Map<String, dynamic>.from(highlight) : null;

    return AvatarFaceStyle(
      gap: _toDouble(json['gap'], 42),
      width: _toDouble(json['width'], 22),
      height: _toDouble(json['height'], 64),
      rotation: _toDouble(json['rotation'], 0),
      leftEyeRotation: _toDouble(json['leftEyeRotation'], 0),
      rightEyeRotation: _toDouble(json['rightEyeRotation'], 0),
      eyeShape: json['eyeShape'] as String? ?? 'rounded',
      eyeRoundness: _toDouble(json['eyeRoundness'], 100),
      noseEnabled: json['noseEnabled'] == true,
      noseShape: json['noseShape'] as String? ?? 'ellipse',
      noseWidth: _toDouble(json['noseWidth'], 16),
      noseHeight: _toDouble(json['noseHeight'], 11),
      noseY: _toDouble(json['noseY'], 30),
      noseRotation: _toDouble(json['noseRotation'], 0),
      mouthEnabled: json['mouthEnabled'] == true,
      mouthShape: json['mouthShape'] as String? ?? 'curve',
      mouthWidth: _toDouble(json['mouthWidth'], 52),
      mouthHeight: _toDouble(json['mouthHeight'], 12),
      mouthY: _toDouble(json['mouthY'], 52),
      mouthCurve: _toDouble(json['mouthCurve'], 45),
      mouthRotation: _toDouble(json['mouthRotation'], 0),
      highlightEnabled: highlightMap?['enabled'] == true,
      highlightColor:
          _parseColor(highlightMap?['color']) ?? const Color(0xFFFFFFFF),
      highlightOffsetX: _toDouble(highlightMap?['offsetX'], -18),
      highlightOffsetY: _toDouble(highlightMap?['offsetY'], -20),
      highlightOpacity: _toDouble(highlightMap?['opacity'], 92),
      highlightSize: _toDouble(highlightMap?['size'], 24),
    );
  }
}

/// A complete companion: its parts, its face, its camera and its light.
class AvatarScene {
  const AvatarScene({
    required this.preset,
    required this.parts,
    required this.faceStyle,
    required this.viewState,
    required this.outlineStyle,
    required this.shadowStyle,
    required this.cameraBackground,
    this.gridDensity = 100,
    this.lightAzimuth = -35,
    this.lightElevation = 40,
    this.lightDistance = 0,
    this.showOutline = true,
    this.showAvatarShadow = true,
  });

  final String preset;
  final List<AvatarPart> parts;
  final AvatarFaceStyle faceStyle;
  final AvatarViewState viewState;
  final AvatarOutlineStyle outlineStyle;
  final AvatarShadowStyle shadowStyle;

  /// The card colour the editor renders behind the avatar. Surfaced so the app
  /// can show it, change it, or leave it off entirely.
  final Color? cameraBackground;

  final double gridDensity;
  final double lightAzimuth;
  final double lightElevation;
  final double lightDistance;
  final bool showOutline;
  final bool showAvatarShadow;

  /// The part the face is drawn on, or the first part if none claims it.
  AvatarPart? get facePart {
    for (final part in parts) {
      if (part.hasFace) return part;
    }
    return parts.isEmpty ? null : parts.first;
  }

  AvatarScene copyWith({
    AvatarViewState? viewState,
    AvatarFaceStyle? faceStyle,
    double? gridDensity,
  }) {
    return AvatarScene(
      preset: preset,
      parts: parts,
      faceStyle: faceStyle ?? this.faceStyle,
      viewState: viewState ?? this.viewState,
      outlineStyle: outlineStyle,
      shadowStyle: shadowStyle,
      cameraBackground: cameraBackground,
      gridDensity: gridDensity ?? this.gridDensity,
      lightAzimuth: lightAzimuth,
      lightElevation: lightElevation,
      lightDistance: lightDistance,
      showOutline: showOutline,
      showAvatarShadow: showAvatarShadow,
    );
  }

  static AvatarScene? fromJson(String preset, Map<String, dynamic> json) {
    final rawParts = json['parts'];
    if (rawParts is! List) return null;

    final parts = <AvatarPart>[];
    for (final raw in rawParts) {
      if (raw is! Map) continue;
      final part = AvatarPart.fromJson(Map<String, dynamic>.from(raw));
      if (part != null) parts.add(part);
    }
    if (parts.isEmpty) return null;

    final scene = json['scene'];
    final sceneMap = scene is Map ? Map<String, dynamic>.from(scene) : null;
    final face = json['faceStyle'];

    return AvatarScene(
      preset: preset,
      parts: parts,
      faceStyle: AvatarFaceStyle.fromJson(
        face is Map ? Map<String, dynamic>.from(face) : null,
      ),
      viewState: AvatarViewState.fromJson(
        sceneMap?['viewState'] is Map
            ? Map<String, dynamic>.from(sceneMap!['viewState'] as Map)
            : null,
      ),
      outlineStyle: AvatarOutlineStyle.fromJson(
        sceneMap?['avatarOutlineStyle'] is Map
            ? Map<String, dynamic>.from(sceneMap!['avatarOutlineStyle'] as Map)
            : null,
      ),
      shadowStyle: AvatarShadowStyle.fromJson(
        sceneMap?['avatarShadowStyle'] is Map
            ? Map<String, dynamic>.from(sceneMap!['avatarShadowStyle'] as Map)
            : null,
      ),
      cameraBackground: _parseColor(sceneMap?['cameraBackground']),
      gridDensity: _toDouble(sceneMap?['gridDensity'], 100),
      lightAzimuth: _toDouble(sceneMap?['lightAzimuth'], -35),
      lightElevation: _toDouble(sceneMap?['lightElevation'], 40),
      lightDistance: _toDouble(sceneMap?['lightDistance'], 0),
      showOutline: sceneMap?['showOutline'] != false,
      showAvatarShadow: sceneMap?['showAvatarShadow'] != false,
    );
  }
}
