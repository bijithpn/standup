import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/data/pet_configuration.dart';
import 'package:breakmate/features/companion/data/pet_asset_repository.dart';
import 'package:breakmate/features/companion/domain/pet_animation.dart';
import 'package:breakmate/features/companion/domain/pet_camera_state.dart';

void main() {
  group('PetConfiguration serialization & PetAssetRepository', () {
    test('PetConfiguration serialize to and from JSON', () {
      final config = PetConfiguration(
        petId: 'cat_calico_01',
        species: 'cat',
        camera: const PetCameraState(
          azimuth: 30.0,
          elevation: 10.0,
          distance: 1.2,
        ),
        pose: {'yaw': 0.1, 'pitch': 0.05, 'roll': 0.0},
        materials: {'primary': '#e67e22', 'secondary': '#f39c12'},
        expression: PetExpression.happy.name,
        animation: PetAnimation.idle.name,
      );

      final json = config.toJson();
      expect(json['petId'], equals('cat_calico_01'));
      expect(json['species'], equals('cat'));
      expect(json['camera']['azimuth'], equals(30.0));
      expect(json['materials']['primary'], equals('#e67e22'));

      final restored = PetConfiguration.fromJson(json);
      expect(restored.petId, equals(config.petId));
      expect(restored.camera.azimuth, equals(config.camera.azimuth));
      expect(restored.materials['primary'], equals('#e67e22'));
      expect(restored.expression, equals(PetExpression.happy.name));
    });

    test('PetAssetRepository loads pet assets and configurations', () async {
      final repo = PetAssetRepository();
      final asset = await repo.loadPet('cat');

      expect(asset.id, equals('cat'));
      expect(asset.definition.species.name, equals('cat'));
      expect(asset.defaultConfiguration.species, equals('cat'));
    });
  });
}
