import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/custom_environment_theme.dart';

void main() {
  group('CustomEnvironmentTheme Layers', () {
    test(
      'fromDefaults initializes with default layers matching mountains and rocks',
      () {
        final theme = CustomEnvironmentTheme.fromDefaults();
        expect(theme.layers.length, equals(4));
        expect(theme.layers[0].assetPath, contains('mountain'));
        expect(theme.layers[2].assetPath, contains('rock'));
      },
    );

    test('toJson and fromJson preserves custom layers list properties', () {
      final original = CustomEnvironmentTheme.fromDefaults();
      final updatedLayer = original.layers.first.copyWith(
        xRatio: 0.75,
        flipX: true,
      );
      original.layers[0] = updatedLayer;

      final json = original.toJson();
      final restored = CustomEnvironmentTheme.fromJson(json);

      expect(restored.layers.length, equals(original.layers.length));
      expect(restored.layers[0].xRatio, equals(0.75));
      expect(restored.layers[0].flipX, isTrue);
    });

    test(
      'backward compatibility maps legacy paths to layers automatically',
      () {
        final jsonMap = {
          'id': 'legacy_test',
          'name': 'Legacy Theme',
          'skyPath': 'assets/sky.png',
          'groundPath': 'assets/ground.png',
          'cloudPath': 'assets/cloud.png',
          'mountainLeftPath': 'assets/mountain_l.png',
          'mountainRightPath': 'assets/mountain_r.png',
          'rockLeftPath': 'assets/rock_l.png',
          'rockRightPath': '', // empty or none should be ignored
        };

        final theme = CustomEnvironmentTheme.fromJson(jsonMap);
        expect(theme.layers.length, equals(3));
        expect(
          theme.layers.any((l) => l.assetPath == 'assets/mountain_l.png'),
          isTrue,
        );
        expect(
          theme.layers.any((l) => l.assetPath == 'assets/mountain_r.png'),
          isTrue,
        );
        expect(
          theme.layers.any((l) => l.assetPath == 'assets/rock_l.png'),
          isTrue,
        );
      },
    );
  });
}
