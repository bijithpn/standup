// Record the real widget: includes its finite expression easing, jaw rig,
// secondary ear motion and whole-character transform composition.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'record actual cute companion motion',
    (tester) async {
      if (Platform.environment['PET_COMPLETE_EXPORT'] != '1') return;
      await tester.runAsync(() => AvatarSceneCatalog.instance.load());
      await tester.binding.setSurfaceSize(const Size(128, 128));
      for (final name in [
        'alpaca',
        'sheep',
        'parrot',
        'cat',
        'dog',
        'capybara',
        'seal',
      ]) {
        final species = AvatarSpecies.values.byName(name);
        final engine = PetBehaviorEngine(
          species: species,
          random: math.Random(42),
        )..startLocal();
        final key = GlobalKey();
        try {
          for (var frame = 0; frame < 120; frame++) {
            if (frame == 10) engine.pet();
            if (frame == 65) engine.play();
            for (var sub = 0; sub < 3; sub++) {
              engine.tick(
                Duration(
                  microseconds: ((frame * 3 + sub + 1) * 1e6 / 60).round(),
                ),
              );
            }
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: MediaQuery(
                  data: const MediaQueryData(),
                  child: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: Avatar3DView(
                        preset: name,
                        size: 128,
                        densityScale: avatarDensityFor(128),
                        background: const Color(0xffece9e2),
                        snapshot: engine.snapshot,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 50));
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/pet_reconstruction/motion/$name/${frame.toString().padLeft(3, '0')}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        } finally {
          engine.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
