import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';

void main() {
  group('AvatarSpecies', () {
    test('contains all 33 OneWorks species', () {
      const expectedSpeciesNames = [
        'alpaca',
        'beaver',
        'capybara',
        'cat',
        'chinchilla',
        'chick',
        'cow',
        'dog',
        'duck',
        'deer',
        'fox',
        'ferret',
        'guineaPig',
        'goose',
        'hamster',
        'hedgehog',
        'lion',
        'monkey',
        'otter',
        'owl',
        'parrot',
        'pig',
        'panda',
        'penguin',
        'rabbit',
        'redPanda',
        'raccoon',
        'sheep',
        'seal',
        'squirrel',
        'tiger',
        'wolf',
        'bear',
      ];

      expect(AvatarSpecies.values.length, 33);
      for (final name in expectedSpeciesNames) {
        final species = AvatarSpecies.fromName(name);
        expect(species, isNotNull);
        expect(species.name, equals(name));
        expect(species.displayName.isNotEmpty, isTrue);
        expect(species.category, isNotNull);
        expect(species.defaultPartConfigurations, isNotNull);
      }
    });

    test('tryParse handles valid and invalid inputs gracefully', () {
      expect(AvatarSpecies.tryParse('cat'), equals(AvatarSpecies.cat));
      expect(
        AvatarSpecies.tryParse('redPanda'),
        equals(AvatarSpecies.redPanda),
      );
      expect(AvatarSpecies.tryParse('invalid_name'), isNull);
      expect(AvatarSpecies.tryParse(null), isNull);
    });

    test('species categorization covers major taxonomy groups', () {
      expect(AvatarSpecies.cat.category, equals(AvatarSpeciesCategory.feline));
      expect(AvatarSpecies.dog.category, equals(AvatarSpeciesCategory.canine));
      expect(AvatarSpecies.duck.category, equals(AvatarSpeciesCategory.avian));
      expect(
        AvatarSpecies.hamster.category,
        equals(AvatarSpeciesCategory.rodent),
      );
      expect(AvatarSpecies.sheep.category, equals(AvatarSpeciesCategory.farm));
    });
  });

  group('AvatarPalette', () {
    test('provides built-in presets with valid hex colors', () {
      expect(AvatarPalette.presets.isNotEmpty, isTrue);
      expect(AvatarPalette.presets.containsKey('default'), isTrue);
      expect(AvatarPalette.presets.containsKey('warmOrange'), isTrue);
      expect(AvatarPalette.presets.containsKey('coolBlue'), isTrue);
      expect(AvatarPalette.presets.containsKey('pastelPink'), isTrue);
      expect(AvatarPalette.presets.containsKey('monochrome'), isTrue);

      final warm = AvatarPalette.warmOrange;
      expect(warm.primary.startsWith('#'), isTrue);
      expect(warm.secondary.startsWith('#'), isTrue);
      expect(warm.accent.startsWith('#'), isTrue);
      expect(warm.snout.startsWith('#'), isTrue);
      expect(warm.ears.startsWith('#'), isTrue);
      expect(warm.eyes.startsWith('#'), isTrue);
    });

    test('JSON serialization round-trip works correctly', () {
      const original = AvatarPalette(
        name: 'customCyber',
        primary: '#00ffcc',
        secondary: '#ff007f',
        accent: '#7928ca',
        snout: '#ffffff',
        ears: '#ff007f',
        eyes: '#000000',
        belly: '#f0f0f0',
      );

      final json = original.toJson();
      final reconstructed = AvatarPalette.fromJson(json);

      expect(reconstructed, equals(original));
      expect(reconstructed.name, equals('customCyber'));
      expect(reconstructed.primary, equals('#00ffcc'));
    });
  });

  group('AvatarAnimationClip', () {
    test(
      'contains all 15 core OneWorks animation clips with proper metadata',
      () {
        const expectedClips = [
          'idle',
          'nod',
          'glance',
          'lookAround',
          'walk',
          'run',
          'sleep',
          'blink',
          'stretch',
          'celebrate',
          'bounce',
          'wiggle',
          'jump',
          'anger',
          'happiness',
        ];

        expect(AvatarAnimationClip.values.length, 15);
        for (final clipName in expectedClips) {
          final clip = AvatarAnimationClip.fromName(clipName);
          expect(clip.name, equals(clipName));
          expect(clip.duration.inMilliseconds, greaterThan(0));
          expect(clip.displayName.isNotEmpty, isTrue);
        }
      },
    );

    test('looping behavior aligns with engine spec', () {
      expect(AvatarAnimationClip.idle.isLooping, isTrue);
      expect(AvatarAnimationClip.walk.isLooping, isTrue);
      expect(AvatarAnimationClip.sleep.isLooping, isTrue);
      expect(AvatarAnimationClip.nod.isLooping, isFalse);
      expect(AvatarAnimationClip.celebrate.isLooping, isFalse);
      expect(AvatarAnimationClip.jump.isLooping, isFalse);
    });
  });

  group('AvatarDefinition', () {
    test('creates default definition from species', () {
      final def = AvatarDefinition.fromSpecies(AvatarSpecies.cat);
      expect(def.schemaVersion, equals(1));
      expect(def.species, equals(AvatarSpecies.cat));
      expect(def.palette, isNotNull);
      expect(def.pattern, equals('solid'));
      expect(def.seed.isNotEmpty, isTrue);
    });

    test(
      'deterministic generation from seed produces consistent attributes',
      () {
        final def1 = AvatarDefinition.fromSeed('standup-companion-seed-42');
        final def2 = AvatarDefinition.fromSeed('standup-companion-seed-42');
        final defDiff = AvatarDefinition.fromSeed('different-seed-99');

        expect(def1.species, equals(def2.species));
        expect(def1.palette, equals(def2.palette));
        expect(def1.pattern, equals(def2.pattern));
        expect(def1, equals(def2));

        expect(def1.seed, isNot(equals(defDiff.seed)));
      },
    );

    test('JSON serialization round-trip preserves all fields', () {
      final def = AvatarDefinition(
        schemaVersion: 1,
        species: AvatarSpecies.redPanda,
        palette: AvatarPalette.warmOrange,
        pattern: 'stripes',
        seed: 'test-seed-123',
        scale: 1.25,
        yaw: 0.5,
        parts: const {'tailLength': 1.2, 'earFluff': true},
      );

      final json = def.toJson();
      final restored = AvatarDefinition.fromJson(json);

      expect(restored.schemaVersion, equals(1));
      expect(restored.species, equals(AvatarSpecies.redPanda));
      expect(
        restored.palette.primary,
        equals(AvatarPalette.warmOrange.primary),
      );
      expect(restored.pattern, equals('stripes'));
      expect(restored.seed, equals('test-seed-123'));
      expect(restored.scale, equals(1.25));
      expect(restored.yaw, equals(0.5));
      expect(restored.parts['earFluff'], equals(true));
      expect(restored, equals(def));
    });

    test('copyWith properly modifies fields', () {
      final base = AvatarDefinition.fromSpecies(AvatarSpecies.dog);
      final modified = base.copyWith(
        species: AvatarSpecies.wolf,
        pattern: 'spots',
        scale: 1.5,
      );

      expect(modified.species, equals(AvatarSpecies.wolf));
      expect(modified.pattern, equals('spots'));
      expect(modified.scale, equals(1.5));
      expect(modified.seed, equals(base.seed));
    });
  });

  group('PetAnimationState toAvatarClip extension', () {
    test(
      'maps all PetAnimationState values to appropriate AvatarAnimationClip',
      () {
        for (final state in PetAnimationState.values) {
          final clip = state.toAvatarClip();
          expect(clip, isNotNull);
          expect(clip, isA<AvatarAnimationClip>());
        }

        expect(
          PetAnimationState.idle.toAvatarClip(),
          equals(AvatarAnimationClip.idle),
        );
        expect(
          PetAnimationState.walkSide.toAvatarClip(),
          equals(AvatarAnimationClip.walk),
        );
        expect(
          PetAnimationState.run.toAvatarClip(),
          equals(AvatarAnimationClip.run),
        );
        expect(
          PetAnimationState.sleep.toAvatarClip(),
          equals(AvatarAnimationClip.sleep),
        );
        expect(
          PetAnimationState.angry.toAvatarClip(),
          equals(AvatarAnimationClip.anger),
        );
        expect(
          PetAnimationState.excited.toAvatarClip(),
          equals(AvatarAnimationClip.celebrate),
        );
        expect(
          PetAnimationState.stretch.toAvatarClip(),
          equals(AvatarAnimationClip.stretch),
        );
        expect(
          PetAnimationState.blink.toAvatarClip(),
          equals(AvatarAnimationClip.blink),
        );
      },
    );
  });

  group('PetTheme avatar integration', () {
    test('PetTheme.avatar factory creates valid 3D avatar theme', () {
      final def = AvatarDefinition.fromSpecies(AvatarSpecies.fox);
      final theme = PetTheme.avatar(
        id: 'avatar_fox',
        name: 'Fox 3D Companion',
        definition: def,
      );

      expect(theme.id, equals('avatar_fox'));
      expect(theme.name, equals('Fox 3D Companion'));
      expect(theme.type, equals(PetType.avatar));
      expect(theme.avatarDefinition, equals(def));
      expect(theme.isAvatar, isTrue);
    });

    test('legacy sprite theme IDs map seamlessly to 3D avatar themes', () {
      final classicTheme = PetTheme.getTheme(PetTheme.keyGreyCat);
      expect(classicTheme.isAvatar, isTrue);
      expect(classicTheme.avatarDefinition, isNotNull);
      expect(classicTheme.avatarDefinition!.species, equals(AvatarSpecies.cat));
    });
  });
}
