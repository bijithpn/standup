class CustomEnvironmentLayer {
  final String id;
  final String assetPath;
  final double xRatio;
  final double
  yRatio; // 0.0 is sitting on the ground, 1.0 is floating at the top of the sky
  final double scale;
  final double opacity;
  final bool flipX;

  const CustomEnvironmentLayer({
    required this.id,
    required this.assetPath,
    this.xRatio = 0.5,
    this.yRatio = 0.0,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.flipX = false,
  });

  factory CustomEnvironmentLayer.fromJson(Map<String, dynamic> json) {
    return CustomEnvironmentLayer(
      id: json['id'] as String,
      assetPath: json['assetPath'] as String,
      xRatio: (json['xRatio'] as num?)?.toDouble() ?? 0.5,
      yRatio: (json['yRatio'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      flipX: json['flipX'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetPath': assetPath,
    'xRatio': xRatio,
    'yRatio': yRatio,
    'scale': scale,
    'opacity': opacity,
    'flipX': flipX,
  };

  CustomEnvironmentLayer copyWith({
    String? id,
    String? assetPath,
    double? xRatio,
    double? yRatio,
    double? scale,
    double? opacity,
    bool? flipX,
  }) {
    return CustomEnvironmentLayer(
      id: id ?? this.id,
      assetPath: assetPath ?? this.assetPath,
      xRatio: xRatio ?? this.xRatio,
      yRatio: yRatio ?? this.yRatio,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      flipX: flipX ?? this.flipX,
    );
  }
}
