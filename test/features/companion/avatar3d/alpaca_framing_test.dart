import 'dart:io';
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alpaca fits the actual widget at every size and pose', (
    tester,
  ) async {
    await tester.runAsync(() => AvatarSceneCatalog.instance.load());
    const poses = {
      'left': PetBehaviorSnapshot(headTurn: Offset(-1, 0), tilt: -.16),
      'right': PetBehaviorSnapshot(headTurn: Offset(1, 0), tilt: .16),
      'up': PetBehaviorSnapshot(headTurn: Offset(0, -1)),
      'down': PetBehaviorSnapshot(headTurn: Offset(0, 1)),
      'corner': PetBehaviorSnapshot(headTurn: Offset(1, 1), tilt: .2),
      'squash': PetBehaviorSnapshot(squash: 1.14, bounce: 12),
      'stretch': PetBehaviorSnapshot(squash: .9, bounce: -14),
      'lean': PetBehaviorSnapshot(bodyLean: Offset(1, .5)),
    };
    for (final size in [32, 48, 64, 96, 128, 256]) {
      final extent = size.toDouble();
      await tester.binding.setSurfaceSize(Size.square(extent + 32));
      for (final pose in poses.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Avatar3DView(
                    preset: 'alpaca',
                    size: extent,
                    densityScale: avatarDensityFor(extent),
                    snapshot: pose.value,
                    showShadow: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final pixels = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          var painted = 0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (pixels!.getUint8((y * image.width + x) * 4 + 3) < 100) {
                continue;
              }
              painted++;
              expect(
                x >= 16 && x < 16 + size && y >= 16 && y < 16 + size,
                isTrue,
                reason:
                    '$size px ${pose.key}: painting outside the pet frame at $x,$y',
              );
            }
          }
          expect(
            painted,
            greaterThan(size * size * .2),
            reason: '$size px ${pose.key}',
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/pet_reconstruction/alpaca_framing/${size}_${pose.key}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
  });
}
