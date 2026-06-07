import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/assets/pet_asset_loader.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all registered pet themes exist and have correct paths', () {
    for (final theme in PetTheme.themes) {
      if (theme.type == PetType.composite) {
        final file = File(theme.basePath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Theme "${theme.id}" references non-existent composite sheet: ${theme.basePath}',
        );
      } else {
        final dir = Directory(theme.basePath);
        expect(
          dir.existsSync(),
          isTrue,
          reason:
              'Theme "${theme.id}" references non-existent separate directory: ${theme.basePath}',
        );
      }
    }
  });

  test('all pet themes can load animations without throwing', () async {
    for (final theme in PetTheme.themes) {
      final profile = CompanionGame.getProfileFromTheme(theme);

      // We will check that we can load the animations map (which will read assets via rootBundle)
      try {
        final animations = await PetAssetLoader.loadAnimations(profile);
        expect(
          animations,
          isNotEmpty,
          reason: 'Animations map should not be empty for theme "${theme.id}"',
        );
      } catch (e) {
        fail('Failed to load animations for theme "${theme.id}": $e');
      }
    }
  });

  test('all configured pet animation frames are valid', () async {
    for (final theme in PetTheme.themes) {
      final issues = await PetAssetLoader.validateTheme(theme);
      expect(
        issues,
        isEmpty,
        reason:
            'Theme "${theme.id}" has invalid sprite frames:\n${issues.join('\n')}',
      );
    }
  });

  test(
    'loaded pet animations never reference clipped source rectangles',
    () async {
      for (final theme in PetTheme.themes) {
        final profile = CompanionGame.getProfileFromTheme(theme);
        final animations = await PetAssetLoader.loadAnimations(profile);

        for (final entry in animations.entries) {
          for (final frame in entry.value.frames) {
            final image = frame.sprite.image;
            final src = frame.sprite.src;
            expect(src.left, greaterThanOrEqualTo(0));
            expect(src.top, greaterThanOrEqualTo(0));
            expect(src.width, greaterThan(0));
            expect(src.height, greaterThan(0));
            expect(
              src.right,
              lessThanOrEqualTo(image.width),
              reason:
                  '${theme.id}.${entry.key.name} frame overflows sheet width',
            );
            expect(
              src.bottom,
              lessThanOrEqualTo(image.height),
              reason:
                  '${theme.id}.${entry.key.name} frame overflows sheet height',
            );
          }
        }
      }
    },
  );
}
