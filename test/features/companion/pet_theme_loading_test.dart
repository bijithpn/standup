import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/flame/companion_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all registered 3D pet themes have valid avatar definitions and runtime paths', () {
    expect(PetTheme.themes, isNotEmpty);
    expect(PetTheme.themes.length, greaterThanOrEqualTo(30));

    for (final theme in PetTheme.themes) {
      expect(theme.isAvatar, isTrue);
      expect(theme.avatarDefinition, isNotNull);
      expect(theme.avatarDefinition!.schemaVersion, equals(1));
      
      final runtimeFile = File(theme.basePath);
      expect(
        runtimeFile.existsSync(),
        isTrue,
        reason: 'Theme "${theme.id}" references runtime asset: ${theme.basePath}',
      );
    }
  });

  test('all 3D OneWorks species are represented in PetTheme.themes', () {
    final themeSpecies = PetTheme.themes
        .map((t) => t.avatarDefinition?.species)
        .whereType<AvatarSpecies>()
        .toSet();

    for (final species in AvatarSpecies.values) {
      expect(
        themeSpecies.contains(species),
        isTrue,
        reason: 'Species ${species.name} missing from PetTheme.themes',
      );
    }
  });

  test('PetTheme.getProfileFromTheme generates valid 3D profile for all themes', () {
    for (final theme in PetTheme.themes) {
      final profile = CompanionGame.getProfileFromTheme(theme);
      expect(profile.id, equals(theme.id));
      expect(profile.name, equals(theme.name));
      expect(profile.avatarDefinition, isNotNull);
    }
  });
}
