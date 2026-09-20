import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_palette_mapper.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';

/// Asks [Avatar3DView] to use the card colour the scene was authored with.
const Color kSceneAuthoredBackground = Color(0x00FFFFFE);

/// Draws a companion as the 3D scene the editor authored.
///
/// The behaviour snapshot drives the camera directly: where the pet looks
/// becomes yaw and pitch, so the head genuinely turns in space rather than a
/// flat picture being skewed. Everything the editor treats as scene styling —
/// the card behind it, the outline, the drop shadow — is exposed here so the
/// app can decide, per surface, how much of that look to keep.
class Avatar3DView extends StatefulWidget {
  const Avatar3DView({
    super.key,
    required this.preset,
    required this.size,
    this.snapshot = const PetBehaviorSnapshot(),
    this.background,
    this.showOutline = true,
    this.showShadow = true,
    this.densityScale = 1.0,
    this.lookRange = 0.55,
    this.palette,
    this.paletteStrength = 0.85,
    this.style = AvatarSceneStyle.authored,
    this.onTap,
    this.onDoubleTap,
    this.placeholder,
  });

  /// The editor preset name, e.g. `cat` or `red-panda`.
  final String preset;

  /// Edge length of the square the companion is drawn into.
  final double size;

  /// What the pet is doing. Drives the camera and the eyes.
  final PetBehaviorSnapshot snapshot;

  /// The card behind the companion. Null leaves it transparent.
  final Color? background;

  final bool showOutline;
  final bool showShadow;

  /// Trims the mesh for surfaces that run all day. 1.0 matches the editor.
  final double densityScale;

  /// How far, in radians, a full-deflection gaze turns the head.
  final double lookRange;

  /// Recolours the authored scene. Null keeps the colours it shipped with.
  final AvatarPalette? palette;

  /// How far the recolour pulls toward [palette], 0..1.
  final double paletteStrength;

  /// The user's scene-level styling: outline, shadow, lighting, face size.
  /// Defaults to the look the scene was authored with.
  final AvatarSceneStyle style;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  /// Shown until the scene catalog has loaded.
  final Widget? placeholder;

  @override
  State<Avatar3DView> createState() => _Avatar3DViewState();
}

class _Avatar3DViewState extends State<Avatar3DView> {
  /// Below this, a pose change is not worth a rebuild — it would not move the
  /// silhouette by a visible amount.
  static const double _poseEpsilon = 0.004;

  AvatarScene? _scene;
  AvatarGeometry? _geometry;
  double _builtYaw = double.nan;
  double _builtPitch = double.nan;
  double _builtBlink = double.nan;

  @override
  void initState() {
    super.initState();
    _resolveScene();
  }

  @override
  void didUpdateWidget(Avatar3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset != widget.preset ||
        oldWidget.palette != widget.palette ||
        oldWidget.paletteStrength != widget.paletteStrength ||
        oldWidget.style != widget.style) {
      _geometry = null;
      _builtYaw = double.nan;
      _resolveScene();
    }
  }

  Future<void> _resolveScene() async {
    final catalog = AvatarSceneCatalog.instance;
    final ready = catalog.sceneFor(widget.preset);
    if (ready != null) {
      _scene = _tinted(ready);
      return;
    }

    await catalog.load();
    if (!mounted) return;
    setState(() => _scene = _tinted(catalog.sceneFor(widget.preset)));
  }

  /// Recolouring and restyling are done once when the scene resolves, not per
  /// frame: both walk the whole scene and neither depends on what the pet is
  /// doing. Only the pose and the expression change frame to frame.
  AvatarScene? _tinted(AvatarScene? scene) {
    if (scene == null) return null;
    return widget.style.applyTo(
      applyPalette(
        scene,
        widget.palette,
        strength: widget.paletteStrength,
      ),
    );
  }

  /// The camera for this frame, from the scene's authored pose plus the pet's.
  AvatarScene? _posedScene() {
    final scene = _scene;
    if (scene == null) return null;

    final snapshot = widget.snapshot;
    final base = scene.viewState;

    // The head leads with the eyes, so gaze turns the camera further than the
    // head alone would; the body lean adds a little roll on top.
    final yaw = base.yaw + snapshot.headTurn.dx * widget.lookRange;
    final pitch = base.pitch - snapshot.headTurn.dy * widget.lookRange * 0.7;
    final roll = base.roll + snapshot.tilt;

    return scene.copyWith(
      viewState: base.copyWith(yaw: yaw, pitch: pitch, roll: roll),
      // The face is where the companion says what it feels. Nothing else has
      // to: no caption, no badge, no colour code.
      faceStyle: expressFace(
        scene.faceStyle,
        snapshot.emotion,
        blink: snapshot.blink,
      ),
    );
  }

  AvatarGeometry? _geometryFor(AvatarScene posed) {
    final yaw = posed.viewState.yaw;
    final pitch = posed.viewState.pitch;
    final blink = widget.snapshot.blink;

    final cached = _geometry;
    if (cached != null &&
        (yaw - _builtYaw).abs() < _poseEpsilon &&
        (pitch - _builtPitch).abs() < _poseEpsilon &&
        (blink - _builtBlink).abs() < 0.02) {
      return cached;
    }

    final built = buildAvatarGeometry(posed, densityScale: widget.densityScale);
    _geometry = built;
    _builtYaw = yaw;
    _builtPitch = pitch;
    _builtBlink = blink;
    return built;
  }

  @override
  Widget build(BuildContext context) {
    final posed = _posedScene();
    if (posed == null) {
      return widget.placeholder ??
          SizedBox(width: widget.size, height: widget.size);
    }

    final geometry = _geometryFor(posed)!;
    final snapshot = widget.snapshot;
    final background = widget.background == kSceneAuthoredBackground
        ? posed.cameraBackground
        : widget.background;

    // Breath, bounce and squash ride on top of the 3D scene as whole-body
    // motion — they move the creature, they do not reshape it.
    final breath = snapshot.breath * widget.size * 0.004;

    Widget painted = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: AvatarScenePainter(
        geometry: geometry,
        scene: posed,
        background: background,
        showOutline: widget.showOutline,
        showShadow: widget.showShadow,
      ),
    );

    painted = Transform(
      transform: Matrix4.identity()
        ..translateByDouble(
          snapshot.bodyLean.dx * widget.size * 0.03,
          snapshot.bounce + breath,
          0.0,
          1.0,
        )
        ..scaleByDouble(
          snapshot.squash,
          2.0 - snapshot.squash,
          1.0,
          1.0,
        ),
      alignment: Alignment.center,
      child: painted,
    );

    painted = RepaintBoundary(
      child: SizedBox(width: widget.size, height: widget.size, child: painted),
    );

    if (widget.onTap == null && widget.onDoubleTap == null) return painted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: painted,
      ),
    );
  }
}

/// Maps the app's species naming onto an editor preset name.
///
/// Most line up already; these are the ones the app names differently or that
/// the editor has no scene for, where a near relative reads better than a
/// missing companion.
String avatarPresetFor(String species) {
  const aliases = <String, String>{
    'guineaPig': 'guinea-pig',
    'redPanda': 'bear',
    'panda': 'bear',
    'raccoon': 'bear',
    'wolf': 'dog',
    'lynx': 'cat',
    'badger': 'ferret',
    'marmot': 'hamster',
    'chimpanzee': 'monkey',
    'chipmunk': 'squirrel',
    'flamingo': 'parrot',
    'beaver': 'beaver',
  };

  final alias = aliases[species];
  if (alias != null) return alias;

  return species
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (match) => '${match[1]}-${match[2]}',
      )
      .toLowerCase();
}

/// Every preset the bundled catalog ships with.
///
/// Listed rather than read from the catalog so callers can decide how to draw a
/// companion before the JSON has finished loading; the catalog itself is the
/// authority once it is in.
const Set<String> kAvatarScenePresets = <String>{
  'alpaca',
  'bear',
  'beaver',
  'bun',
  'capybara',
  'cat',
  'chick',
  'chinchilla',
  'cloud',
  'cow',
  'deer',
  'dog',
  'duck',
  'ferret',
  'fox',
  'goose',
  'guinea-pig',
  'hamster',
  'hedgehog',
  'lion',
  'monkey',
  'otter',
  'owl',
  'parrot',
  'penguin',
  'pig',
  'rabbit',
  'seal',
  'sheep',
  'squirrel',
  'sun',
  'tiger',
};

/// Whether this species can be drawn as a 3D scene.
bool hasAvatarScene(String species) =>
    kAvatarScenePresets.contains(avatarPresetFor(species));

/// A sensible mesh density for a companion of this size.
///
/// A 96px pet on a desktop does not need the same tessellation as a 400px
/// studio preview, and the saving is the difference between the pet costing
/// nothing and costing a frame.
double avatarDensityFor(double size) {
  if (size <= 120) return 0.55;
  if (size <= 220) return 0.75;
  return math.min(1.0, size / 320);
}
