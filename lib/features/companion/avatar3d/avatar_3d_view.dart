import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';
import 'package:breakmate/features/companion/avatar3d/species_face.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_palette_mapper.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';

const Color kSceneAuthoredBackground = Color(0x00FFFFFE);

/// Software-rendered 3D avatar: poses a preset scene from the behavior snapshot (head turn, tilt, blink, emotion) and paints it each frame.
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

  final String preset;

  final double size;

  final PetBehaviorSnapshot snapshot;

  final Color? background;

  final bool showOutline;
  final bool showShadow;

  final double densityScale;

  final double lookRange;

  final AvatarPalette? palette;

  final double paletteStrength;

  final AvatarSceneStyle style;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  final Widget? placeholder;

  @override
  State<Avatar3DView> createState() => _Avatar3DViewState();
}

class _Avatar3DViewState extends State<Avatar3DView>
    with SingleTickerProviderStateMixin {
  static const double _poseEpsilon = 0.004;

  AvatarScene? _scene;
  AvatarGeometry? _geometry;
  double _builtYaw = double.nan;
  double _builtPitch = double.nan;
  AvatarFaceStyle? _builtFace;
  Rect? _fitBounds;

  AvatarFaceStyle? _shownFace;
  late final Ticker _faceTicker;
  Duration _lastFaceTick = Duration.zero;

  static const double _faceEaseSeconds = 0.11;

  void _easeFace(Duration elapsed) {
    final target = _targetFace;
    final shown = _shownFace;
    if (target == null || shown == null) {
      _faceTicker.stop();
      return;
    }
    final dt = (elapsed - _lastFaceTick).inMicroseconds / 1e6;
    _lastFaceTick = elapsed;
    final k = 1 - math.exp(-dt.clamp(0.0, 0.1) / _faceEaseSeconds);
    final next = shown.lerpTo(target, k);
    if (next.isCloseTo(target)) {
      _shownFace = target;
      _faceTicker.stop();
    } else {
      _shownFace = next;
    }
    if (mounted) setState(() {});
  }

  AvatarFaceStyle? _targetFace;

  @override
  void initState() {
    super.initState();
    _faceTicker = createTicker(_easeFace);
    _resolveScene();
  }

  @override
  void dispose() {
    _faceTicker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Avatar3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset != widget.preset ||
        oldWidget.palette != widget.palette ||
        oldWidget.paletteStrength != widget.paletteStrength ||
        oldWidget.style != widget.style) {
      _geometry = null;
      _fitBounds = null;
      _builtYaw = double.nan;
      _shownFace = null;
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

  /// Scene pipeline: species face tuning, then palette recolor, then user style overrides.
  AvatarScene? _tinted(AvatarScene? scene) {
    if (scene == null) return null;
    final suited = scene.copyWith(
      faceStyle: tuneFaceForSpecies(widget.preset, scene.faceStyle),
    );
    return widget.style.applyTo(
      applyPalette(suited, widget.palette, strength: widget.paletteStrength),
    );
  }

  /// Applies head turn/tilt/emotion to the authored view; the face is eased in _easeFace rather than snapped.
  AvatarScene? _posedScene() {
    final scene = _scene;
    if (scene == null) return null;

    final snapshot = widget.snapshot;
    final base = _restView(scene.viewState);

    final yaw = base.yaw + snapshot.headTurn.dx * widget.lookRange;

    final pitch = base.pitch + snapshot.headTurn.dy * widget.lookRange * 0.7;
    final roll = base.roll + snapshot.tilt;

    return scene.copyWith(
      viewState: base.copyWith(yaw: yaw, pitch: pitch, roll: roll),

      faceStyle: _expressedFace(scene, snapshot),
    );
  }

  AvatarFaceStyle _expressedFace(
    AvatarScene scene,
    PetBehaviorSnapshot snapshot,
  ) {
    final target = expressFace(scene.faceStyle, snapshot.emotion);
    _targetFace = target;

    final shown = _shownFace;
    if (shown == null) {
      _shownFace = target;
    } else if (!shown.isCloseTo(target) && !_faceTicker.isActive) {
      _lastFaceTick = Duration.zero;
      _faceTicker.start();
    }

    return (_shownFace ?? target).withEyeOpenness(1 - snapshot.blink);
  }

  // Authored angles are damped to 20% so the idle pose stays mostly front-facing.
  static AvatarViewState _restView(AvatarViewState authored) =>
      authored.copyWith(
        yaw: authored.yaw * 0.2,
        pitch: authored.pitch * 0.2,
        roll: authored.roll * 0.2,
      );

  /// Geometry is expensive; rebuild only when yaw/pitch/face moved past a small epsilon.
  AvatarGeometry? _geometryFor(AvatarScene posed) {
    final yaw = posed.viewState.yaw;
    final pitch = posed.viewState.pitch;
    final face = posed.faceStyle;

    final cached = _geometry;
    if (cached != null &&
        (yaw - _builtYaw).abs() < _poseEpsilon &&
        (pitch - _builtPitch).abs() < _poseEpsilon &&
        _builtFace != null &&
        face.isCloseTo(_builtFace!, epsilon: 0.08)) {
      return cached;
    }

    final built = buildAvatarGeometry(posed, densityScale: widget.densityScale);
    _geometry = built;
    _builtYaw = yaw;
    _builtPitch = pitch;
    _builtFace = face;
    return built;
  }

  /// Fit bounds come from the rest pose and are cached so the avatar does not rescale as it turns.
  Rect _fitBoundsFor(AvatarScene posed) {
    final cached = _fitBounds;
    if (cached != null) return cached;
    final rest = posed.copyWith(
      viewState: _restView(_scene!.viewState),
      faceStyle: _scene!.faceStyle,
    );
    final bounds = buildAvatarGeometry(
      rest,
      densityScale: widget.densityScale,
    ).bounds;
    return _fitBounds = bounds;
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

    final breath = snapshot.breath * widget.size * 0.004;

    Widget painted = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: AvatarScenePainter(
        geometry: geometry,
        fitBounds: _fitBoundsFor(posed),
        blush: blushFor(snapshot.emotion),
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
        ..scaleByDouble(snapshot.squash, 2.0 - snapshot.squash, 1.0, 1.0),
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

bool hasAvatarScene(String species) =>
    kAvatarScenePresets.contains(avatarPresetFor(species));

double avatarDensityFor(double size) {
  if (size <= 120) return 0.55;
  if (size <= 220) return 0.75;
  return math.min(1.0, size / 320);
}
