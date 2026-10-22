/// Spherical orbit camera state
class PetCameraState {
  final double azimuth; // in degrees (0 to 360)
  final double elevation; // in degrees (-45 to +45)
  final double distance; // zoom factor (0.5 to 3.0)

  const PetCameraState({
    this.azimuth = 0.0,
    this.elevation = 0.0,
    this.distance = 1.0,
  });

  PetCameraState copyWith({
    double? azimuth,
    double? elevation,
    double? distance,
  }) {
    return PetCameraState(
      azimuth: azimuth ?? this.azimuth,
      elevation: elevation ?? this.elevation,
      distance: distance ?? this.distance,
    );
  }

  Map<String, dynamic> toJson() => {
    'azimuth': azimuth,
    'elevation': elevation,
    'distance': distance,
  };

  factory PetCameraState.fromJson(Map<String, dynamic> json) => PetCameraState(
    azimuth: (json['azimuth'] as num?)?.toDouble() ?? 0.0,
    elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
    distance: (json['distance'] as num?)?.toDouble() ?? 1.0,
  );
}
