import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/behavior/behavior_layers.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/species_personality.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';

void _run(PetBehaviorEngine e, double seconds, [void Function()? each]) {
  var now = Duration.zero;
  for (var i = 0; i < seconds * 10; i++) {
    now += const Duration(milliseconds: 100);
    e.tick(now);
    each?.call();
  }
}

void main() {
  group('personalities', () {
    test('every species has an entry and no two are identical', () {
      expect(speciesPersonalities.keys.toSet(), AvatarSpecies.values.toSet());
      final seen = <String>{};
      for (final p in speciesPersonalities.values) {
        expect(seen.add(p.values.join(',')), isTrue);
      }
    });

    test('headline traits point the right way', () {
      final dog = personalityFor(AvatarSpecies.dog);
      final capy = personalityFor(AvatarSpecies.capybara);
      final cat = personalityFor(AvatarSpecies.cat);
      expect(dog.energy, greaterThan(capy.energy));
      expect(dog.speed, greaterThan(capy.speed));
      expect(cat.blinkMin, greaterThan(SpeciesPersonality.neutral.blinkMin));
      expect(personalityFor(AvatarSpecies.rabbit).noseTwitch, greaterThan(0.1));
      expect(personalityFor(AvatarSpecies.parrot).bob, greaterThan(0.5));
    });
  });

  group('layers', () {
    test('higher layers suppress lower ones and weights never exceed 1', () {
      final l = BehaviorLayers();
      for (var i = 0; i < 120; i++) {
        l.update(
          1 / 60,
          asleep: false,
          emotion: true,
          activity: true,
          interaction: true,
        );
      }
      expect(l.weight(BehaviorLayer.interaction), closeTo(1, 1e-9));
      expect(l.weight(BehaviorLayer.idle), 0);
      final sum = BehaviorLayer.values.fold<double>(
        0,
        (a, b) => a + l.weight(b),
      );
      expect(sum, lessThanOrEqualTo(1.0 + 1e-9));
    });

    test('asleep kills idle and waking ramps it back gradually', () {
      final l = BehaviorLayers();
      void step(bool asleep, int n) {
        for (var i = 0; i < n; i++) {
          l.update(
            1 / 60,
            asleep: asleep,
            emotion: false,
            activity: false,
            interaction: false,
          );
        }
      }

      step(true, 60);
      expect(l.weight(BehaviorLayer.idle), 0);
      step(false, 6);
      final early = l.weight(BehaviorLayer.idle);
      expect(early, inExclusiveRange(0.0, 0.5));
      step(false, 120);
      expect(l.weight(BehaviorLayer.idle), 1);
    });
  });

  group('engine', () {
    test('a sleeping pet has no twitches, tilt or idle bounce', () {
      final e = PetBehaviorEngine(
        random: math.Random(3),
        species: AvatarSpecies.rabbit,
      )..startLocal();
      addTearDown(e.dispose);
      _run(e, 150);
      expect(e.snapshot.activity, PetActivity.sleeping);
      expect(e.idleWeight, 0);
      var maxMotion = 0.0;
      _run(e, 60, () {
        final s = e.snapshot;
        maxMotion = math.max(
          maxMotion,
          math.max(s.noseTwitch.abs(), s.bounce.abs()),
        );
        expect(s.tilt.abs(), lessThan(0.05));
        expect(s.earPose, lessThanOrEqualTo(-0.0));
      });
      expect(maxMotion, lessThan(0.01));
    });

    test('waking does not restore idle at once', () {
      final e = PetBehaviorEngine(random: math.Random(3))..startLocal();
      addTearDown(e.dispose);
      _run(e, 150);
      e.nudge();
      e.tick(const Duration(seconds: 151));
      expect(e.idleWeight, lessThan(0.5));
    });

    test('an awake rabbit eventually twitches nose and ears', () {
      final e = PetBehaviorEngine(
        random: math.Random(5),
        species: AvatarSpecies.rabbit,
      )..startLocal();
      addTearDown(e.dispose);
      var nose = 0.0;
      var ear = 0.0;
      _run(e, 60, () {
        nose = math.max(nose, e.snapshot.noseTwitch);
        ear = math.max(ear, e.snapshot.earPose);
      });
      expect(nose, greaterThan(0.1));
      expect(ear, greaterThan(0.3));
    });

    test('reduced motion suppresses autonomous twitches', () {
      final e = PetBehaviorEngine(
        random: math.Random(5),
        species: AvatarSpecies.rabbit,
        reducedMotion: true,
      )..startLocal();
      addTearDown(e.dispose);
      var nose = 0.0;
      _run(e, 60, () => nose = math.max(nose, e.snapshot.noseTwitch));
      expect(nose, 0);
      expect(e.isSettled, isTrue);
    });

    test('dizzy wobble is bounded and settles', () {
      final e = PetBehaviorEngine(random: math.Random(1))..startLocal();
      addTearDown(e.dispose);
      e.grab();
      _run(e, 2);
      e.release();
      var peak = 0.0;
      _run(e, 4, () => peak = math.max(peak, e.snapshot.tilt.abs()));
      expect(peak, lessThan(0.6));
      _run(e, 6);
      expect(e.snapshot.activity, isNot(PetActivity.dizzy));
    });
  });
}
