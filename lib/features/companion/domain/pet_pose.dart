/// 3D pose of the companion (yaw, pitch, roll in radians)
class PetPose {
  final double yaw;
  final double pitch;
  final double roll;

  const PetPose({
    this.yaw = 0.0,
    this.pitch = 0.0,
    this.roll = 0.0,
  });

  static const PetPose identity = PetPose();

  PetPose copyWith({
    double? yaw,
    double? pitch,
    double? roll,
  }) {
    return PetPose(
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
    );
  }

  Map<String, dynamic> toJson() => {
        'yaw': yaw,
        'pitch': pitch,
        'roll': roll,
      };

  factory PetPose.fromJson(Map<String, dynamic> json) => PetPose(
        yaw: (json['yaw'] as num?)?.toDouble() ?? 0.0,
        pitch: (json['pitch'] as num?)?.toDouble() ?? 0.0,
        roll: (json['roll'] as num?)?.toDouble() ?? 0.0,
      );
}
