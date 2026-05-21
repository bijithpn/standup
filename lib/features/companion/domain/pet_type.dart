/// Defines the species and variant types for pet companions.
enum PetSpecies {
  cat,
  dog,
  bird,
  rabbit,
  hamster,
  reptile,
}

/// Represents a visual variant of a specific pet species.
class PetVariant {
  final String id;
  final String name;
  final String assetPath;
  final bool isSpriteSheet;
  final int? rowCount;
  final int? frameCount;
  final double? frameWidth;
  final double? frameHeight;

  const PetVariant({
    required this.id,
    required this.name,
    required this.assetPath,
    this.isSpriteSheet = true,
    this.rowCount,
    this.frameCount,
    this.frameWidth,
    this.frameHeight,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'assetPath': assetPath,
      'isSpriteSheet': isSpriteSheet,
      'rowCount': rowCount,
      'frameCount': frameCount,
      'frameWidth': frameWidth,
      'frameHeight': frameHeight,
    };
  }

  factory PetVariant.fromMap(Map<String, dynamic> map) {
    return PetVariant(
      id: map['id'] as String,
      name: map['name'] as String,
      assetPath: map['assetPath'] as String,
      isSpriteSheet: map['isSpriteSheet'] as bool? ?? true,
      rowCount: map['rowCount'] as int?,
      frameCount: map['frameCount'] as int?,
      frameWidth: (map['frameWidth'] as num?)?.toDouble(),
      frameHeight: (map['frameHeight'] as num?)?.toDouble(),
    );
  }
}
