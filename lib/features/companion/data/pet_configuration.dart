import 'package:breakmate/features/companion/domain/pet_camera_state.dart';

/// Serializable persistent companion configuration
class PetConfiguration {
  final String petId;
  final String species;
  final PetCameraState camera;
  final Map<String, dynamic> pose;
  final Map<String, dynamic> materials;
  final String expression;
  final String animation;

  const PetConfiguration({
    required this.petId,
    required this.species,
    this.camera = const PetCameraState(),
    this.pose = const {},
    this.materials = const {},
    this.expression = 'neutral',
    this.animation = 'idle',
  });

  Map<String, dynamic> toJson() => {
    'petId': petId,
    'species': species,
    'camera': camera.toJson(),
    'pose': pose,
    'materials': materials,
    'expression': expression,
    'animation': animation,
  };

  factory PetConfiguration.fromJson(Map<String, dynamic> json) {
    return PetConfiguration(
      petId: json['petId'] as String? ?? 'default',
      species: json['species'] as String? ?? 'cat',
      camera: json['camera'] is Map<String, dynamic>
          ? PetCameraState.fromJson(json['camera'] as Map<String, dynamic>)
          : const PetCameraState(),
      pose: json['pose'] is Map
          ? Map<String, dynamic>.from(json['pose'] as Map)
          : const {},
      materials: json['materials'] is Map
          ? Map<String, dynamic>.from(json['materials'] as Map)
          : const {},
      expression: json['expression'] as String? ?? 'neutral',
      animation: json['animation'] as String? ?? 'idle',
    );
  }
}
