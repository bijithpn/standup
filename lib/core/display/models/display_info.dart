import 'dart:ui';

class DisplayInfo {
  final String id;
  final bool isPrimary;
  final double width;
  final double height;
  final double pixelRatio;
  final Rect bounds;
  final Rect workArea;
  final Offset position;
  final double refreshRate;

  const DisplayInfo({
    required this.id,
    required this.isPrimary,
    required this.width,
    required this.height,
    required this.pixelRatio,
    required this.bounds,
    required this.workArea,
    required this.position,
    required this.refreshRate,
  });

  factory DisplayInfo.fromMap(Map<String, dynamic> map) {
    return DisplayInfo(
      id: map['id'] as String,
      isPrimary: map['isPrimary'] as bool? ?? false,
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      pixelRatio: (map['pixelRatio'] as num).toDouble(),
      bounds: Rect.fromLTWH(
        (map['boundsX'] as num).toDouble(),
        (map['boundsY'] as num).toDouble(),
        (map['boundsWidth'] as num).toDouble(),
        (map['boundsHeight'] as num).toDouble(),
      ),
      workArea: Rect.fromLTWH(
        (map['workAreaX'] as num).toDouble(),
        (map['workAreaY'] as num).toDouble(),
        (map['workAreaWidth'] as num).toDouble(),
        (map['workAreaHeight'] as num).toDouble(),
      ),
      position: Offset(
        (map['boundsX'] as num).toDouble(),
        (map['boundsY'] as num).toDouble(),
      ),
      refreshRate: (map['refreshRate'] as num?)?.toDouble() ?? 60.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isPrimary': isPrimary,
      'width': width,
      'height': height,
      'pixelRatio': pixelRatio,
      'boundsX': bounds.left,
      'boundsY': bounds.top,
      'boundsWidth': bounds.width,
      'boundsHeight': bounds.height,
      'workAreaX': workArea.left,
      'workAreaY': workArea.top,
      'workAreaWidth': workArea.width,
      'workAreaHeight': workArea.height,
      'refreshRate': refreshRate,
    };
  }

  @override
  String toString() {
    return 'DisplayInfo(id: $id, isPrimary: $isPrimary, bounds: $bounds, scale: $pixelRatio)';
  }
}
