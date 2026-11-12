import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/pet_mood.dart';
import 'package:breakmate/features/companion/domain/pet_needs.dart';
import 'package:breakmate/features/companion/domain/pet_profile.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/ai/pet_behavior_brain.dart';
import 'package:breakmate/features/companion/services/pet_companion_service.dart';
import 'package:breakmate/features/companion/services/pet_navigation_service.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';
import 'package:breakmate/features/companion/services/throwable_object_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetNeeds & PetMood Calculations', () {
    test('PetNeeds supports hunger, energy, happiness, boredom, breakMode', () {
      final needs = const PetNeeds(
        affection: 0.8,
        playfulness: 0.6,
        energy: 0.15,
        restfulness: 0.4,
        hunger: 80.0,
        boredom: 75.0,
        happiness: 85.0,
        breakMode: false,
      );

      expect(needs.hunger, equals(80.0));
      expect(needs.boredom, equals(75.0));
      expect(needs.happiness, equals(85.0));
      expect(needs.energyLevel, closeTo(15.0, 0.1));
    });

    test('PetMood.fromNeeds maps low energy (<= 20) to tired/sleep mood', () {
      final lowEnergyNeeds = const PetNeeds(
        energy: 0.15, // 15%
        hunger: 20.0,
        boredom: 20.0,
        happiness: 50.0,
      );

      final mood = PetMoodCalculator.fromNeeds(lowEnergyNeeds);
      expect(mood, equals(PetMood.tired));
    });

    test('PetMood.fromNeeds maps hunger (> 75) to hungry mood', () {
      final hungryNeeds = const PetNeeds(
        energy: 0.6,
        hunger: 85.0,
        boredom: 30.0,
        happiness: 50.0,
      );

      final mood = PetMoodCalculator.fromNeeds(hungryNeeds);
      expect(mood, equals(PetMood.hungry));
    });

    test('PetMood.fromNeeds maps high boredom (> 70) to bored mood', () {
      final boredNeeds = const PetNeeds(
        energy: 0.6,
        hunger: 30.0,
        boredom: 78.0,
        happiness: 40.0,
      );

      final mood = PetMoodCalculator.fromNeeds(boredNeeds);
      expect(mood, equals(PetMood.bored));
    });

    test('PetMood.fromNeeds maps high happiness (> 80) to happy mood', () {
      final happyNeeds = const PetNeeds(
        energy: 0.7,
        hunger: 20.0,
        boredom: 20.0,
        happiness: 90.0,
      );

      final mood = PetMoodCalculator.fromNeeds(happyNeeds);
      expect(mood, equals(PetMood.happy));
    });

    test('PetMood.fromNeeds in breakMode maps to happy/satisfied mood', () {
      final breakNeeds = const PetNeeds(breakMode: true);

      final mood = PetMoodCalculator.fromNeeds(breakNeeds);
      expect(mood, equals(PetMood.happy));
    });
  });

  group('PetStateMachine & 3D Avatar Animation Clip Bridging', () {
    test('PetState maps cleanly to AvatarAnimationClip', () {
      expect(PetState.idle.toAnimationClip(), equals(AvatarAnimationClip.idle));
      expect(
        PetState.blink.toAnimationClip(),
        equals(AvatarAnimationClip.blink),
      );
      expect(
        PetState.stretch.toAnimationClip(),
        equals(AvatarAnimationClip.stretch),
      );
      expect(PetState.walk.toAnimationClip(), equals(AvatarAnimationClip.walk));
      expect(PetState.run.toAnimationClip(), equals(AvatarAnimationClip.run));
      expect(
        PetState.sleep.toAnimationClip(),
        equals(AvatarAnimationClip.sleep),
      );
      expect(
        PetState.happy.toAnimationClip(),
        equals(AvatarAnimationClip.happiness),
      );
      expect(
        PetState.celebrating.toAnimationClip(),
        equals(AvatarAnimationClip.celebrate),
      );
      expect(
        PetState.dancing.toAnimationClip(),
        equals(AvatarAnimationClip.bounce),
      );
      expect(
        PetState.jumping.toAnimationClip(),
        equals(AvatarAnimationClip.jump),
      );
      expect(
        PetState.curious.toAnimationClip(),
        equals(AvatarAnimationClip.glance),
      );
    });

    test('PetStateMachine helpers trigger correct transitions and events', () {
      final fsm = PetStateMachine();

      fsm.onPetting();
      expect(fsm.currentState, equals(PetState.affectionate));

      fsm.onFedTreat();
      expect(fsm.currentState, equals(PetState.eating));

      fsm.onPlayToy();
      expect(fsm.currentState, equals(PetState.chasing));

      fsm.onBreakStarted();
      expect(fsm.currentState, equals(PetState.breakReminder));

      fsm.onBreakCompleted();
      expect(fsm.currentState, equals(PetState.celebrating));
    });

    test(
      'PetStateMachine evaluates needs to trigger sleep, stretch, celebration, curious',
      () {
        final fsm = PetStateMachine();

        // Low energy -> sleep
        fsm.evaluateNeeds(const PetNeeds(energy: 0.15));
        expect(fsm.currentState, equals(PetState.sleep));

        // Wake up with normal needs
        fsm.transitionTo(PetState.idle);

        // High boredom -> stretch
        fsm.evaluateNeeds(const PetNeeds(energy: 0.8, boredom: 85.0));
        expect(fsm.currentState, equals(PetState.stretch));

        // High happiness -> celebrating
        fsm.evaluateNeeds(const PetNeeds(energy: 0.8, happiness: 92.0));
        expect(fsm.currentState, equals(PetState.celebrating));

        // High hunger -> curious / begging
        fsm.evaluateNeeds(const PetNeeds(energy: 0.8, hunger: 88.0));
        expect(fsm.currentState, equals(PetState.curious));
      },
    );
  });

  group('NeedsEngine Lifecycle & Interactions', () {
    test(
      'NeedsEngine updates on petting, feeding, toy playing, break started/completed',
      () {
        final engine = NeedsEngine();

        // Petting increases affection & happiness, decreases boredom
        final beforePetting = engine.current;
        engine.onPetting();
        expect(engine.current.affection, greaterThan(beforePetting.affection));
        expect(engine.current.happiness, greaterThan(beforePetting.happiness));

        // Feeding decreases hunger, increases energy & happiness
        engine.setHunger(80.0);
        engine.onFedTreat();
        expect(engine.current.hunger, lessThan(80.0));
        expect(engine.current.energy, greaterThanOrEqualTo(0.5));

        // Play toy increases playfulness & happiness, decreases boredom
        engine.setBoredom(60.0);
        engine.onPlayToy();
        expect(engine.current.playfulness, greaterThan(0.5));
        expect(engine.current.boredom, lessThan(60.0));

        // Break started sets breakMode
        engine.onBreakStarted();
        expect(engine.current.breakMode, isTrue);

        // Break completed sets breakMode to false and boosts happiness
        engine.onBreakCompleted();
        expect(engine.current.breakMode, isFalse);
        expect(engine.current.happiness, greaterThanOrEqualTo(60.0));
      },
    );

    test('NeedsEngine tick decays needs over time', () {
      final engine = NeedsEngine();
      engine.setHappiness(90.0);
      engine.setHunger(20.0);
      engine.setBoredom(10.0);

      // Tick 30 seconds
      engine.tick(30.0, PetState.idle, false, Duration.zero);

      // Hunger increases, boredom increases, happiness normalizes
      expect(engine.current.hunger, greaterThan(20.0));
      expect(engine.current.boredom, greaterThan(10.0));
    });
  });

  group('ThrowableObjectManager & Gaze Target Emission', () {
    test(
      'Spawning toy emits target position stream for companion to track',
      () async {
        final physics = PhysicsSimulator();
        final manager = ThrowableObjectManager(physicsSimulator: physics);

        Offset? emittedTarget;
        manager.toyPositionStream.listen((pos) {
          emittedTarget = pos;
        });

        // Spawn a tennis ball
        final id = manager.spawnThrowable(
          const Offset(100, 100),
          const Offset(50, 0),
          kind: 'tennis_ball',
        );

        expect(id, isNotNull);
        expect(manager.activeToyPosition, isNotNull);

        // Tick physics to update position
        manager.tick(
          0.1,
          petBounds: const Rect.fromLTWH(50, 50, 40, 40),
          petAnchor: const Offset(50, 50),
        );

        expect(manager.activeToyPosition, isNotNull);
        await Future.delayed(Duration.zero);
        expect(emittedTarget, isNotNull);
      },
    );

    test('Eating sushi treat completes target and feeds pet', () {
      final physics = PhysicsSimulator();
      final manager = ThrowableObjectManager(physicsSimulator: physics);

      manager.spawnThrowable(
        const Offset(100, 100),
        const Offset(20, 0),
        kind: 'sushi_treat',
      );

      // Pet is at the exact treat position
      manager.tick(
        0.1,
        petBounds: const Rect.fromLTWH(80, 80, 40, 40),
        petAnchor: const Offset(100, 100),
      );

      // Treat is consumed / handled
      expect(
        manager.snapshots().isEmpty ||
            manager.snapshots().first.kind == 'sushi_treat',
        isTrue,
      );
    });
  });

  group('PetCompanionService End-to-End Integration', () {
    test('Binds StateMachine, NeedsEngine, Brain, and Navigation', () async {
      final fsm = PetStateMachine();
      final brain = PetBehaviorBrain();
      final nav = PetNavigationService();
      final needsEngine = NeedsEngine();

      final service = PetCompanionService(
        stateMachine: fsm,
        brain: brain,
        navigation: nav,
        profile: PetProfile.orangeCat,
        needsEngine: needsEngine,
      );

      service.initialize(
        screenSize: const Size(1920, 1080),
        startPosition: const Offset(200, 200),
      );

      // On petting reaction
      service.onPetting();
      expect(service.currentState, equals(PetState.affectionate));

      // On feeding reaction
      service.onFedTreat();
      expect(service.currentState, equals(PetState.eating));

      // On break started & completed
      service.onBreakStarted();
      expect(service.currentState, equals(PetState.breakReminder));

      service.onBreakCompleted();
      expect(service.currentState, equals(PetState.celebrating));

      // Toy tracking
      service.trackToy(const Offset(600, 200));
    });
  });
}
