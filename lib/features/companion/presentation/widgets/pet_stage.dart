import 'dart:math' as math;

import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:flutter/material.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';

/// Stateless renderer that picks Blobatar or the 3D avatar artwork for a behavior snapshot and applies bounce/squash/tilt.
class PetStage extends StatelessWidget {
  const PetStage({
    super.key,
    required this.snapshot,
    required this.size,
    this.definition,
    this.blobName,
    this.showShadow = true,
    this.onTap,
    this.onDoubleTap,
    this.background,
    this.showOutline = true,
    this.showSceneShadow = true,
  });

  final PetBehaviorSnapshot snapshot;

  final double size;

  final AvatarDefinition? definition;

  final String? blobName;

  final bool showShadow;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  final Color? background;

  final bool showOutline;
  final bool showSceneShadow;

  bool get _isBlob => blobName != null && blobName!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final pet = _isBlob ? _buildBlob() : _buildArtwork();

    Widget stage = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (showShadow)
            Positioned(
              bottom: size * 0.06,
              child: _GroundShadow(
                width: size * 0.52,
                lift: snapshot.bounce,
                lean: snapshot.bodyLean.dx,
              ),
            ),
          pet,
        ],
      ),
    );

    stage = RepaintBoundary(child: stage);

    if (onTap == null && onDoubleTap == null) return stage;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: stage,
      ),
    );
  }

  Widget _buildArtwork() {
    final def = definition;
    if (def == null) return SizedBox(width: size, height: size);

    if (hasAvatarScene(def.species.name)) {
      return Avatar3DView(
        preset: avatarPresetFor(def.species.name),
        size: size,
        snapshot: snapshot,
        background: background,
        showOutline: showOutline,
        showShadow: showSceneShadow,
        densityScale: avatarDensityFor(size),

        palette: def.palette == AvatarPalette.defaultPalette
            ? null
            : def.palette,
        style: avatarStyleFrom(def.parts),
      );
    }

    return _buildFlatArtwork(def);
  }

  Widget _buildFlatArtwork(AvatarDefinition def) {
    final head = snapshot.headTurn;
    final body = snapshot.bodyLean;
    final breath = snapshot.breath;

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..translateByDouble(
        body.dx * size * 0.05,
        snapshot.bounce + body.dy * size * 0.025 + breath * size * 0.004,
        0.0,
        1.0,
      )
      ..rotateY(head.dx * 0.5)
      ..rotateX(-head.dy * 0.38)
      ..rotateZ(snapshot.tilt)
      ..scaleByDouble(snapshot.squash, 2.0 - snapshot.squash, 1.0, 1.0);

    return Transform(
      transform: transform,
      alignment: Alignment.center,
      child: AvatarArtwork.definition(
        def,
        width: size * 0.92,
        height: size * 0.92,
      ),
    );
  }

  Widget _buildBlob() {
    final gaze = snapshot.gaze;
    final blinkSquash = 1.0 - snapshot.blink * 0.94;

    final pose = Pose(
      esy: (_basePose().esy * blinkSquash).clamp(0.04, 2.0),
      esx: _basePose().esx,
      tilt: _basePose().tilt + snapshot.tilt * 12.0,

      edy: _basePose().edy + gaze.dy * 2.6,
      edx: _basePose().edx + snapshot.attention * 0.8,
      esx2: _basePose().esx2,
      esy2: _basePose().esy2,
      tilt2: _basePose().tilt2,
      lock: _basePose().lock,
      heat: _basePose().heat,
      shake: _basePose().shake,
      bdy: _basePose().bdy + snapshot.bounce * 0.12,
    );

    final expression = Expression(pose, _baseExpression().tint);

    return Transform(
      transform: Matrix4.identity()
        ..translateByDouble(
          gaze.dx * size * 0.055,
          snapshot.bounce * 0.6 + snapshot.breath * size * 0.006,
          0.0,
          1.0,
        )
        ..rotateZ(snapshot.tilt * 0.6)
        ..scaleByDouble(snapshot.squash, 2.0 - snapshot.squash, 1.0, 1.0),
      alignment: Alignment.center,
      child: Blobatar(
        key: ValueKey<String>(blobName!),
        name: blobName!,
        size: size * 0.86,

        animate: BlobatarAnimate.none,
        expression: expression,
      ),
    );
  }

  Expression _baseExpression() {
    switch (snapshot.activity) {
      case PetActivity.sleeping:
        return sleepyExpression;
      case PetActivity.drowsy:
        return sleepyExpression;
      case PetActivity.delighted:
        return loveExpression;
      case PetActivity.startled:
        return surprisedExpression;
      case PetActivity.playful:
        return happyExpression;
      case PetActivity.watching:
        return happyExpression;
      case PetActivity.curious:
        return thinkingExpression;
      case PetActivity.idle:
        return idleExpression;
    }
  }

  Pose _basePose() => _baseExpression().pose;
}

class _GroundShadow extends StatelessWidget {
  const _GroundShadow({
    required this.width,
    required this.lift,
    required this.lean,
  });

  final double width;

  final double lift;

  final double lean;

  @override
  Widget build(BuildContext context) {
    final height = (-lift / 28.0).clamp(0.0, 1.0);
    final scale = 1.0 - height * 0.45;

    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(lean * width * 0.14, 0),
        child: Container(
          width: width * scale,
          height: width * 0.16 * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.elliptical(width * scale, width * 0.08 * scale),
            ),
            gradient: RadialGradient(
              colors: [
                Colors.black.withValues(alpha: 0.26 * scale),
                Colors.black.withValues(alpha: 0.0),
              ],
              stops: const [0.15, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

double petStageInset(double size) => math.max(6.0, size * 0.04);
