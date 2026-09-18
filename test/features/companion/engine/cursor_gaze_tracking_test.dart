import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/core/native/native_bridge.dart';

class FakeNativeBridge implements NativeBridgePlatform {
  ui.Offset cursorPos = ui.Offset.zero;

  @override
  Future<ui.Offset> getCursorPosition() async => cursorPos;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AvatarEngineController JS Bridge Formatting', () {
    late List<String> executedScripts;
    late AvatarEngineController controller;

    setUp(() {
      executedScripts = [];
      controller = AvatarEngineController(
        jsEvaluator: (script) async {
          executedScripts.add(script);
          return null;
        },
      );
    });

    test('setLookAt formats correct JS script and clamps within [-1.0, 1.0]', () async {
      await controller.setLookAt(0.5, -0.3);
      expect(executedScripts.last, equals('window.AvatarBridge.setLookAt(0.5, -0.3);'));
      expect(controller.currentLookAt, equals(const ui.Offset(0.5, -0.3)));

      // Clamping test
      await controller.setLookAt(2.5, -1.8);
      expect(executedScripts.last, equals('window.AvatarBridge.setLookAt(1.0, -1.0);'));
      expect(controller.currentLookAt, equals(const ui.Offset(1.0, -1.0)));
    });

    test('setYaw formats correct JS script', () async {
      await controller.setYaw(0.785);
      expect(executedScripts.last, equals('window.AvatarBridge.setYaw(0.785);'));
      expect(controller.currentYaw, closeTo(0.785, 0.001));
    });

    test('playAnimation formats correct JS script with options and records state', () async {
      await controller.playAnimation(
        AvatarAnimationClip.nod,
        loop: false,
        speed: 1.5,
      );
      expect(
        executedScripts.last,
        equals("window.AvatarBridge.playAnimation('nod', { loop: false, speed: 1.5 });"),
      );
      expect(controller.currentClip, equals(AvatarAnimationClip.nod));
    });

    test('setDefinition formats correct JS script containing definition JSON', () async {
      final definition = AvatarDefinition.fromSpecies(
        AvatarSpecies.fox,
        palette: AvatarPalette.warmOrange,
        seed: 'test-seed-123',
      );
      await controller.setDefinition(definition);
      expect(executedScripts.last, startsWith('window.AvatarBridge.setDefinition('));
      expect(executedScripts.last, contains('"species":"fox"'));
      expect(executedScripts.last, contains('"warmOrange"'));
      expect(controller.currentDefinition, equals(definition));
    });

    test('setPalette formats correct JS script containing palette JSON', () async {
      final palette = AvatarPalette.cyberpunk;
      await controller.setPalette(palette);
      expect(executedScripts.last, startsWith('window.AvatarBridge.setPalette('));
      expect(executedScripts.last, contains('"name":"cyberpunk"'));
      expect(controller.currentPalette, equals(palette));
    });
  });

  group('AvatarEngineController Gaze Calculation & LookAt Math', () {
    late AvatarEngineController controller;

    setUp(() {
      controller = AvatarEngineController();
    });

    test('calculateGaze returns (0, 0) when cursor is centered on pet', () {
      final gaze = controller.calculateGaze(
        petScreenPosition: const ui.Offset(300, 300),
        cursorScreenPosition: const ui.Offset(300, 300),
        maxDistance: 600.0,
        enableSmoothing: false,
        enableSaccades: false,
      );

      expect(gaze.dx, closeTo(0.0, 0.001));
      expect(gaze.dy, closeTo(0.0, 0.001));
    });

    test('calculateGaze scales coordinates linearly up to maxDistance', () {
      final gaze = controller.calculateGaze(
        petScreenPosition: const ui.Offset(200, 200),
        cursorScreenPosition: const ui.Offset(500, 200), // +300 px X
        maxDistance: 600.0,
        enableSmoothing: false,
        enableSaccades: false,
      );

      expect(gaze.dx, closeTo(0.5, 0.001));
      expect(gaze.dy, closeTo(0.0, 0.001));
    });

    test('calculateGaze clamps values exceeding maxDistance to [-1.0, 1.0]', () {
      final gaze = controller.calculateGaze(
        petScreenPosition: const ui.Offset(100, 100),
        cursorScreenPosition: const ui.Offset(1000, -500),
        maxDistance: 400.0,
        enableSmoothing: false,
        enableSaccades: false,
      );

      expect(gaze.dx, equals(1.0));
      expect(gaze.dy, equals(-1.0));
    });

    test('calculateGaze applies smooth exponential moving average damping', () {
      final petPos = const ui.Offset(200, 200);
      final cursorTarget = const ui.Offset(800, 200); // target raw X = 1.0

      // Step 1
      final gaze1 = controller.calculateGaze(
        petScreenPosition: petPos,
        cursorScreenPosition: cursorTarget,
        maxDistance: 600.0,
        damping: 0.3,
        dt: 0.016,
        enableSmoothing: true,
        enableSaccades: false,
      );
      expect(gaze1.dx, greaterThan(0.0));
      expect(gaze1.dx, lessThan(1.0));

      // Step 2
      final gaze2 = controller.calculateGaze(
        petScreenPosition: petPos,
        cursorScreenPosition: cursorTarget,
        maxDistance: 600.0,
        damping: 0.3,
        dt: 0.016,
        enableSmoothing: true,
        enableSaccades: false,
      );
      expect(gaze2.dx, greaterThan(gaze1.dx));
      expect(gaze2.dx, lessThanOrEqualTo(1.0));
    });

    test('calculateGaze introduces micro eye saccades when cursor is idle', () {
      final petPos = const ui.Offset(200, 200);
      final cursorIdle = const ui.Offset(200, 200);

      // Multiple idle updates should generate small subtle variations within bounded range
      final samples = <ui.Offset>[];
      for (int i = 0; i < 20; i++) {
        final gaze = controller.calculateGaze(
          petScreenPosition: petPos,
          cursorScreenPosition: cursorIdle,
          maxDistance: 600.0,
          dt: 0.05,
          enableSmoothing: false,
          enableSaccades: true,
        );
        samples.add(gaze);
      }

      // Verify bounds: saccades should stay small (e.g. <= 0.1) and vary
      for (final s in samples) {
        expect(s.dx.abs(), lessThanOrEqualTo(0.1));
        expect(s.dy.abs(), lessThanOrEqualTo(0.1));
      }
      final hasVariation = samples.any((s) => s.dx != 0.0 || s.dy != 0.0);
      expect(hasVariation, isTrue);
    });
  });

  group('AvatarEventChannel Typed Events', () {
    late AvatarEventChannel eventChannel;

    setUp(() {
      eventChannel = AvatarEventChannel();
    });

    tearDown(() {
      eventChannel.dispose();
    });

    test('emits and filters animation started and finished events', () async {
      final startedClips = <AvatarAnimationClip>[];
      final finishedClips = <AvatarAnimationClip>[];

      eventChannel.onAnimationStarted.listen((event) {
        startedClips.add(event.clip);
      });
      eventChannel.onAnimationFinished.listen((event) {
        finishedClips.add(event.clip);
      });

      eventChannel.emit(AvatarAnimationStartedEvent(AvatarAnimationClip.celebrate));
      eventChannel.emit(AvatarAnimationFinishedEvent(AvatarAnimationClip.celebrate));
      await pumpEventQueue();

      expect(startedClips, equals([AvatarAnimationClip.celebrate]));
      expect(finishedClips, equals([AvatarAnimationClip.celebrate]));
    });

    test('emits tap and double tap interaction events', () async {
      final taps = <AvatarTapEvent>[];
      final doubleTaps = <AvatarDoubleTapEvent>[];

      eventChannel.onTap.listen(taps.add);
      eventChannel.onDoubleTap.listen(doubleTaps.add);

      eventChannel.emit(AvatarTapEvent(position: ui.Offset(50, 60)));
      eventChannel.emit(AvatarDoubleTapEvent(position: ui.Offset(50, 60)));
      await pumpEventQueue();

      expect(taps.length, equals(1));
      expect(taps.first.position, equals(const ui.Offset(50, 60)));
      expect(doubleTaps.length, equals(1));
    });

    test('emits proximity events when within interaction distance', () async {
      final proximityEvents = <AvatarProximityEvent>[];
      eventChannel.onProximity.listen(proximityEvents.add);

      eventChannel.emit(AvatarProximityEvent(distance: 45.0, isInside: true));
      eventChannel.emit(AvatarProximityEvent(distance: 120.0, isInside: false));
      await pumpEventQueue();

      expect(proximityEvents.length, equals(2));
      expect(proximityEvents.first.isInside, isTrue);
      expect(proximityEvents.last.isInside, isFalse);
    });

    test('handles raw JSON / string bridge events from WebGL runtime', () async {
      final startedClips = <AvatarAnimationClip>[];
      eventChannel.onAnimationStarted.listen((event) {
        startedClips.add(event.clip);
      });

      eventChannel.handleRawEvent('animation_started', {'clip': 'bounce'});
      await pumpEventQueue();

      expect(startedClips, equals([AvatarAnimationClip.bounce]));
    });
  });

  group('CursorTracker to AvatarEngineController Integration', () {
    late FakeNativeBridge fakeBridge;
    late CursorTracker cursorTracker;
    late AvatarEngineController controller;
    late List<String> scripts;

    setUp(() {
      fakeBridge = FakeNativeBridge();
      cursorTracker = CursorTracker(bridge: fakeBridge);
      scripts = [];
      controller = AvatarEngineController(
        jsEvaluator: (script) async {
          scripts.add(script);
          return null;
        },
      );
    });

    test('cursorTracker provides stream and feeds updateGaze to controller', () async {
      final petCenter = const ui.Offset(200, 200);
      fakeBridge.cursorPos = const ui.Offset(500, 200);

      final positions = <ui.Offset>[];
      cursorTracker.positionStream.listen(positions.add);

      await cursorTracker.sample(0.016, petCenter);
      await pumpEventQueue();

      expect(cursorTracker.lastPosition, equals(const ui.Offset(500, 200)));
      expect(positions, contains(const ui.Offset(500, 200)));

      // Feed into controller updateGaze
      await controller.updateGaze(
        petScreenPosition: petCenter,
        cursorScreenPosition: cursorTracker.lastPosition,
        enableSmoothing: false,
        enableSaccades: false,
      );

      expect(scripts.isNotEmpty, isTrue);
      expect(scripts.last, startsWith('window.AvatarBridge.setLookAt('));
      expect(controller.currentLookAt.dx, closeTo(0.5, 0.05));
    });

    test('attachCursorTracker automatically updates gaze on cursorTracker samples', () async {
      final petCenter = const ui.Offset(200, 200);
      fakeBridge.cursorPos = const ui.Offset(500, 200);

      controller.attachCursorTracker(
        cursorTracker,
        getPetPosition: () => petCenter,
      );

      await cursorTracker.sample(0.016, petCenter);
      await pumpEventQueue();

      expect(scripts.isNotEmpty, isTrue);
      expect(scripts.last, startsWith('window.AvatarBridge.setLookAt('));
    });
  });
}
