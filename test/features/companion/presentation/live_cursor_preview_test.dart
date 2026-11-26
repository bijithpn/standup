import 'dart:ui' show PointerDeviceKind;

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';
import 'package:breakmate/features/companion/presentation/companion_live_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('live cursor turns the actual 3D head and clicking reacts', (
    tester,
  ) async {
    await tester.runAsync(() => AvatarSceneCatalog.instance.load());
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final key = GlobalKey<CompanionLivePreviewState>();
    await tester.pumpWidget(MaterialApp(home: CompanionLivePreview(key: key)));
    await tester.pump();
    final pet = find.byKey(const ValueKey('live-pet-interaction'));
    expect(tester.getSize(pet).width, 440);
    final center = tester.getCenter(pet);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: center + const Offset(240, -60));
    for (var i = 0; i < 15; i++) {
      await mouse.moveTo(center + Offset(240 + i % 2 * 6, -60));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(key.currentState!.snapshot.gaze.dx, greaterThan(.2));
    expect(key.currentState!.snapshot.headTurn.dx, greaterThan(.15));
    AvatarScenePainter painter() => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(Avatar3DView),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((w) => w.painter)
        .whereType<AvatarScenePainter>()
        .single;
    final rightYaw = painter().scene.viewState.yaw;
    for (var i = 0; i < 20; i++) {
      await mouse.moveTo(center + Offset(-240 - i % 2 * 6, -60));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(key.currentState!.snapshot.gaze.dx, lessThan(-.2));
    expect(painter().scene.viewState.yaw, lessThan(rightYaw - .1));
    await tester.tap(pet);
    await tester.pump(const Duration(milliseconds: 100));
    expect(key.currentState!.snapshot.cheekLift, greaterThan(0));
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
  });
}
