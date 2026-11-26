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
    this.lookRange = 0.3,
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
  static const double _faceEaseSeconds = 0.11;
  static const double _lagSeconds = 0.18;

  AvatarScene? _scene;
  AvatarGeometry? _geometry;
  double _builtYaw = double.nan;
  double _builtPitch = double.nan;
  AvatarFaceStyle? _builtFace;
  FaceRig _poseRig = FaceRig.neutral;
  FaceRig? _builtRig;
  Rect? _fitBounds;
  Widget? _lastBuilt;
  bool _reduceMotion = false;

  AvatarFaceStyle? _shownFace;
  AvatarFaceStyle? _targetFace;
  FaceRig _shownRig = FaceRig.neutral;
  FaceRig _targetRig = FaceRig.neutral;
  double _lag = 0;
  double _lagTarget = 0;
  late final Ticker _ticker;
  final Stopwatch _clock = Stopwatch()..start();
  Duration _lastTick = Duration.zero;

  bool get _animating =>
      !_reduceMotion && (_targetRig.nose > 0.01 || _targetRig.nod > 0.01);

  void _step(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = elapsed;
    final k = 1 - math.exp(-dt / _faceEaseSeconds);

    final target = _targetFace;
    final shown = _shownFace;
    if (target != null && shown != null) {
      final next = shown.lerpTo(target, k);
      _shownFace = next.isCloseTo(target) ? target : next;
    }
    _shownRig = _shownRig.isCloseTo(_targetRig)
        ? _targetRig
        : _shownRig.lerpTo(_targetRig, k);
    _lag += (_lagTarget - _lag) * (1 - math.exp(-dt / _lagSeconds));

    final settled =
        (_lag - _lagTarget).abs() < 0.002 &&
        _shownRig.isCloseTo(_targetRig) &&
        (target == null || (_shownFace?.isCloseTo(target) ?? true));
    if (settled && !_animating) _ticker.stop();
    if (mounted) setState(() {});
  }

  void _wake() {
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_step);
    _resolveScene();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
      _lastBuilt = null;
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

  /// Applies head turn/tilt/emotion to the authored view; face and rig are eased in _step rather than snapped.
  AvatarScene? _posedScene() {
    final scene = _scene;
    if (scene == null) return null;

    final snapshot = widget.snapshot;
    final base = _restView(scene.viewState);
    final rig = _poseRig = _currentRig(snapshot);

    final yaw = base.yaw + snapshot.headTurn.dx * widget.lookRange;
    final pitch =
        base.pitch +
        snapshot.headTurn.dy * widget.lookRange * 0.7 +
        rig.pitch +
        (_reduceMotion
            ? 0
            : _shownRig.nod * 0.12 * (0.5 + 0.5 * math.sin(_t * 1.1)));
    final roll = base.roll + snapshot.tilt;

    return scene
        .copyWithParts(poseParts(scene.parts, rig))
        .copyWith(
          viewState: base.copyWith(yaw: yaw, pitch: pitch, roll: roll),
          faceStyle: _expressedFace(scene, snapshot),
        );
  }

  double get _t => _clock.elapsedMilliseconds / 1000;

  FaceRig _currentRig(PetBehaviorSnapshot snapshot) {
    _targetRig = rigFor(snapshot.emotion);
    _lagTarget = _reduceMotion ? 0 : snapshot.headTurn.dx + snapshot.tilt * 3;
    if (!_shownRig.isCloseTo(_targetRig) ||
        (_lag - _lagTarget).abs() > 0.002 ||
        _animating) {
      _wake();
    }
    final twitch = _reduceMotion
        ? 0.0
        : math.pow(math.max(0, math.sin(_t * 2.3)), 3) *
              (0.5 + 0.5 * math.sin(_t * 28));
    return _shownRig.copyWith(
      earRot: (_lag - _lagTarget) * 14,
      nose: _shownRig.nose * twitch,
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
    } else if (!shown.isCloseTo(target)) {
      _wake();
    }

    return (_shownFace ?? target).withEyeOpenness(1 - snapshot.blink);
  }

  // Authored yaw/pitch/roll are damped so the idle pose stays mostly front-facing.
  static AvatarViewState _restView(AvatarViewState authored) =>
      authored.copyWith(
        yaw: authored.yaw * 0.2,
        pitch: authored.pitch * 0.2,
        roll: authored.roll * 0.2,
      );

  /// Geometry is expensive; rebuild only when yaw/pitch/face moved past a small epsilon.
  AvatarGeometry? _geometryFor(AvatarScene posed, FaceRig rig) {
    final yaw = posed.viewState.yaw;
    final pitch = posed.viewState.pitch;
    final face = posed.faceStyle;

    final cached = _geometry;
    if (cached != null &&
        (yaw - _builtYaw).abs() < _poseEpsilon &&
        (pitch - _builtPitch).abs() < _poseEpsilon &&
        _builtFace != null &&
        face.isCloseTo(_builtFace!, epsilon: 0.08) &&
        _builtRig != null &&
        (rig.earDroop - _builtRig!.earDroop).abs() < 0.03 &&
        (rig.earRot - _builtRig!.earRot).abs() < 0.5) {
      return cached;
    }

    final built = buildAvatarGeometry(posed, densityScale: widget.densityScale);
    _geometry = built;
    _builtYaw = yaw;
    _builtPitch = pitch;
    _builtFace = face;
    _builtRig = rig;
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
    final hidden = _lastBuilt != null && !TickerMode.valuesOf(context).enabled;
    if (hidden) return _lastBuilt!;

    final posed = _posedScene();
    if (posed == null) {
      return widget.placeholder ?? PetLoader(size: widget.size);
    }

    final geometry = _geometryFor(posed, _poseRig)!;
    final snapshot = widget.snapshot;
    final background = widget.background == kSceneAuthoredBackground
        ? posed.cameraBackground
        : widget.background;

    final still = _reduceMotion;
    final breath = still ? 0.0 : snapshot.breath * widget.size * 0.004;
    final squash = still ? 1.0 : snapshot.squash.clamp(0.6, 1.6);

    Widget painted = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: AvatarScenePainter(
        geometry: geometry,
        fitBounds: _fitBoundsFor(posed),
        blush: blushFor(snapshot.emotion),
        rig: _poseRig,
        scene: posed,
        background: background,
        showOutline: widget.showOutline,
        showShadow: widget.showShadow,
      ),
    );

    painted = Transform(
      transform: Matrix4.identity()
        ..translateByDouble(
          still ? 0.0 : snapshot.bodyLean.dx * widget.size * 0.03,
          still ? 0.0 : snapshot.bounce + breath,
          0.0,
          1.0,
        )
        ..scaleByDouble(math.sqrt(squash), 1 / squash, 1.0, 1.0),
      alignment: Alignment.center,
      child: painted,
    );

    painted = RepaintBoundary(
      child: SizedBox(width: widget.size, height: widget.size, child: painted),
    );

    if (widget.onTap == null && widget.onDoubleTap == null) {
      return _lastBuilt = painted;
    }

    return _lastBuilt = MouseRegion(
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
    'redPanda': 'red-panda',
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
  'panda',
  'parrot',
  'penguin',
  'pig',
  'rabbit',
  'raccoon',
  'red-panda',
  'seal',
  'sheep',
  'squirrel',
  'sun',
  'tiger',
};

bool hasAvatarScene(String species) =>
    kAvatarScenePresets.contains(avatarPresetFor(species));

double avatarDensityFor(double size) =>
    size <= 160 ? 1.1 : math.min(1.6, size / 140);

/// Cute stand-in while the scene catalog loads: a soft blob that bobs and blinks.
class PetLoader extends StatefulWidget {
  const PetLoader({super.key, required this.size});

  final double size;

  @override
  State<PetLoader> createState() => _PetLoaderState();
}

class _PetLoaderState extends State<PetLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final hop = math.sin(_c.value * math.pi * 2).abs();
          final blink = _c.value > 0.86 && _c.value < 0.94;
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: s * 0.14,
                child: Container(
                  width: s * 0.34 * (1 - hop * 0.3),
                  height: s * 0.05,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(s),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -hop * s * 0.08),
                child: Container(
                  width: s * 0.5,
                  height: s * (0.42 + hop * 0.03),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(s * 0.22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 2; i++)
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: s * 0.05),
                          width: s * 0.05,
                          height: blink ? s * 0.012 : s * 0.06,
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(s),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
