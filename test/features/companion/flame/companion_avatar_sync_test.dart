import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/flame/companion_component.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompanionGame & 3D Avatar Synchronization', () {
    late List<String> executedScripts;
    late AvatarEngineController avatarController;
    late CompanionGame game;

    setUp(() {
      executedScripts = [];
      avatarController = AvatarEngineController(
        jsEvaluator: (script) async {
          executedScripts.add(script);
          return null;
        },
      );

      game = CompanionGame(
        initialTheme: PetTheme.avatar(species: AvatarSpecies.fox),
        avatarController: avatarController,
      );
    });

    test('CompanionGame initializes with AvatarDefinition and AvatarEngineController', () {
      expect(game.avatarDefinition, isNotNull);
      expect(game.avatarDefinition!.species, equals(AvatarSpecies.fox));
      expect(game.avatarController, isNotNull);
      expect(game.currentAnimationState, equals(PetAnimationState.idle));
    });

    test('changePetState synchronizes state and triggers 3D animation clip', () {
      game.changePetState(PetAnimationState.walkSide);
      expect(game.currentAnimationState, equals(PetAnimationState.walkSide));
      expect(avatarController.currentClip, equals(AvatarAnimationClip.walk));

      game.changePetState(PetAnimationState.run);
      expect(game.currentAnimationState, equals(PetAnimationState.run));
      expect(avatarController.currentClip, equals(AvatarAnimationClip.run));

      game.changePetState(PetAnimationState.celebrate);
      expect(game.currentAnimationState, equals(PetAnimationState.celebrate));
      expect(avatarController.currentClip, equals(AvatarAnimationClip.celebrate));
    });

    test('triggerCompanionReaction synchronizes mood and animation with 3D avatar', () {
      game.triggerCompanionReaction(PetState.celebrating);
      expect(avatarController.currentClip, equals(AvatarAnimationClip.celebrate));

      game.triggerCompanionReaction(PetState.alert);
      expect(avatarController.currentClip, equals(AvatarAnimationClip.lookAround));
    });

    test('updateTheme switches AvatarDefinition and updates 3D avatar controller', () async {
      final pandaTheme = PetTheme.avatar(species: AvatarSpecies.panda);
      await game.updateTheme(pandaTheme);

      expect(game.avatarDefinition?.species, equals(AvatarSpecies.panda));
      expect(avatarController.currentDefinition?.species, equals(AvatarSpecies.panda));
    });
  });

  group('CompanionComponent Movement Yaw & Direction Calculation', () {
    late AvatarEngineController avatarController;
    late CompanionComponent component;

    setUp(() {
      avatarController = AvatarEngineController(
        jsEvaluator: (script) async => null,
      );

      component = CompanionComponent(
        animations: const {},
        avatarController: avatarController,
      );
    });

    test('calculates yaw heading facing right when moving right', () {
      component.updateMovementHeading(const ui.Offset(100.0, 0.0), dt: 0.1);

      expect(component.currentYaw, closeTo(math.pi / 2, 0.2));
      expect(avatarController.currentYaw, closeTo(math.pi / 2, 0.2));
      expect(component.isFlipped, isFalse);
    });

    test('calculates yaw heading facing left when moving left', () {
      component.updateMovementHeading(const ui.Offset(-100.0, 0.0), dt: 0.1);

      expect(component.currentYaw, closeTo(-math.pi / 2, 0.2));
      expect(avatarController.currentYaw, closeTo(-math.pi / 2, 0.2));
      expect(component.isFlipped, isTrue);
    });

    test('calculates diagonal yaw heading smoothly', () {
      component.updateMovementHeading(const ui.Offset(50.0, 50.0), dt: 0.1);

      expect(component.currentYaw, closeTo(math.pi / 4, 0.2));
      expect(avatarController.currentYaw, closeTo(math.pi / 4, 0.2));
    });

    test('smoothly interpolates yaw without abrupt jumps', () {
      // Start facing forward (yaw = 0)
      expect(component.currentYaw, closeTo(0.0, 0.01));

      // Step towards right in smaller deltas
      component.updateMovementHeading(const ui.Offset(100.0, 0.0), dt: 0.016);
      final intermediateYaw = component.currentYaw;

      expect(intermediateYaw, greaterThan(0.0));
      expect(intermediateYaw, lessThan(math.pi / 2));

      // After several steps it converges towards pi/2
      for (int i = 0; i < 20; i++) {
        component.updateMovementHeading(const ui.Offset(100.0, 0.0), dt: 0.016);
      }
      expect(component.currentYaw, closeTo(math.pi / 2, 0.15));
    });
  });

  group('User Gestures & Physics Callbacks', () {
    late AvatarEngineController avatarController;
    late CompanionGame game;

    setUp(() {
      avatarController = AvatarEngineController(
        jsEvaluator: (script) async => null,
      );

      game = CompanionGame(
        initialTheme: PetTheme.avatar(species: AvatarSpecies.cat),
        avatarController: avatarController,
      );
    });

    test('tap interaction emits AvatarTapEvent on event channel', () async {
      final taps = <AvatarTapEvent>[];
      avatarController.eventChannel.onTap.listen(taps.add);

      game.onUserInteraction('tap');
      await pumpEventQueue();

      expect(taps.length, equals(1));
    });

    test('double tap interaction emits AvatarDoubleTapEvent on event channel', () async {
      final doubleTaps = <AvatarDoubleTapEvent>[];
      avatarController.eventChannel.onDoubleTap.listen(doubleTaps.add);

      game.onUserInteraction('doubleTap');
      await pumpEventQueue();

      expect(doubleTaps.length, equals(1));
    });

    test('hover interaction triggers userHover event and curious gaze', () async {
      final proximityEvents = <AvatarProximityEvent>[];
      avatarController.eventChannel.onProximity.listen(proximityEvents.add);

      game.onUserInteraction('hover');
      await pumpEventQueue();

      expect(proximityEvents.isNotEmpty, isTrue);
    });

    test('dragStart and dragEnd spawn throwable object and calculate trajectory', () {
      game.onUserInteraction('dragStart', position: const ui.Offset(100, 100));
      game.onUserInteraction('dragEnd', position: const ui.Offset(250, 80));

      final snapshots = game.throwableManager.snapshots();
      expect(snapshots.isNotEmpty, isTrue);
    });
  });
}
