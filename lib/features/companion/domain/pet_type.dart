/// Defines the species and variant types for pet companions.
enum MovementType { walk, hop, fly }

/// Species-specific behavior parameters.
class PetBehaviorProfile {
  final double mouseAttraction; // Curiosity multiplier
  final double sleepLikelihood; // Fatigue rate multiplier
  final double edgePreference; // Likelihood to stay near boundaries
  final List<String> customActions;

  // Decoupled physics & render traits
  final double movementSpeed; // max follow/wander speed
  final double acceleration; // stiffness rate (springStiffness)
  final double damping; // damping factor for spring system
  final double lookDelay; // seconds of "looking" before moving
  final double wanderRadius; // local prowl radius limit
  final double specialAbilityProbability; // chance to trigger custom actions
  final double strideFrequency; // foot step frequency multiplier
  final double maxTilt; // max lean angle in radians for flying/climbing
  final double bobIntensity; // breathing/movement vertical scaling factor
  final double stopRadius; // stop this many px away from cursor

  const PetBehaviorProfile({
    this.mouseAttraction = 1.0,
    this.sleepLikelihood = 1.0,
    this.edgePreference = 0.0,
    this.customActions = const [],
    this.movementSpeed = 90.0,
    this.acceleration = 6.0,
    this.damping = 0.85,
    this.lookDelay = 0.0,
    this.wanderRadius = 250.0,
    this.specialAbilityProbability = 0.0,
    this.strideFrequency = 1.15,
    this.maxTilt = 0.22,
    this.bobIntensity = 0.04,
    this.stopRadius = 40.0,
  });

  static const cat = PetBehaviorProfile(
    mouseAttraction: 0.8,
    sleepLikelihood: 1.2,
    edgePreference: 0.2,
    movementSpeed: 90.0,
    acceleration: 6.0,
    damping: 0.85,
    lookDelay: 0.4,
    wanderRadius: 250.0,
    specialAbilityProbability: 0.15,
    strideFrequency: 1.15,
    maxTilt: 0.22,
    bobIntensity: 0.04,
    stopRadius: 40.0,
  );

  static const dog = PetBehaviorProfile(
    mouseAttraction: 1.4,
    sleepLikelihood: 1.0,
    edgePreference: 0.1,
    movementSpeed: 200.0,
    acceleration: 14.0,
    damping: 0.65,
    lookDelay: 0.0,
    wanderRadius: 350.0,
    specialAbilityProbability: 0.2,
    strideFrequency: 1.25,
    maxTilt: 0.22,
    bobIntensity: 0.02,
    stopRadius: 8.0,
  );

  static const flamingo = PetBehaviorProfile(
    mouseAttraction: 1.0,
    sleepLikelihood: 1.0,
    edgePreference: 0.3,
    movementSpeed: 110.0,
    acceleration: 8.0,
    damping: 0.8,
    lookDelay: 0.2,
    wanderRadius: 280.0,
    specialAbilityProbability: 0.15,
    strideFrequency: 1.15,
    maxTilt: 0.15,
    bobIntensity: 0.03,
    stopRadius: 32.0,
  );
}

enum PetSpecies {
  cat(MovementType.walk, PetBehaviorProfile.cat),
  dog(MovementType.walk, PetBehaviorProfile.dog),
  flamingo(MovementType.walk, PetBehaviorProfile.flamingo);

  final MovementType movementType;
  final PetBehaviorProfile defaultProfile;

  const PetSpecies(this.movementType, this.defaultProfile);
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
