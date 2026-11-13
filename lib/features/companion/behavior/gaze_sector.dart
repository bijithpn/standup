import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Eight compass sectors plus center; the pet looks toward the sector the cursor is in.
enum GazeDirection {
  upLeft(-1, -1),
  up(0, -1),
  upRight(1, -1),
  left(-1, 0),
  center(0, 0),
  right(1, 0),
  downLeft(-1, 1),
  down(0, 1),
  downRight(1, 1);

  const GazeDirection(this.column, this.row);

  final int column;

  final int row;

  Offset get unit {
    if (this == GazeDirection.center) return Offset.zero;
    final length = math.sqrt((column * column + row * row).toDouble());
    return Offset(column / length, row / length);
  }

  String get label => switch (this) {
    GazeDirection.upLeft => 'up and to the left',
    GazeDirection.up => 'up',
    GazeDirection.upRight => 'up and to the right',
    GazeDirection.left => 'to the left',
    GazeDirection.center => 'straight ahead',
    GazeDirection.right => 'to the right',
    GazeDirection.downLeft => 'down and to the left',
    GazeDirection.down => 'down',
    GazeDirection.downRight => 'down and to the right',
  };

  static const List<GazeDirection> _ring = <GazeDirection>[
    GazeDirection.right,
    GazeDirection.downRight,
    GazeDirection.down,
    GazeDirection.downLeft,
    GazeDirection.left,
    GazeDirection.upLeft,
    GazeDirection.up,
    GazeDirection.upRight,
  ];
}

/// Converts a cursor offset to a GazeDirection with a dead zone and hysteresis so the gaze does not flicker on sector borders.
class GazeSectorTracker {
  GazeSectorTracker({
    double deadZone = 60.0,
    this.deadZoneExit = 1.3,
    this.sectorHysteresis = 0.18,
  }) : _deadZone = deadZone;

  final double deadZoneExit;

  final double sectorHysteresis;

  double _deadZone;
  GazeDirection _direction = GazeDirection.center;

  double get deadZone => _deadZone;
  set deadZone(double value) => _deadZone = math.max(0.0, value);

  GazeDirection get direction => _direction;

  void reset() => _direction = GazeDirection.center;

  GazeDirection update(Offset toPointer) {
    final distance = toPointer.distance;

    final threshold = _direction == GazeDirection.center
        ? _deadZone * deadZoneExit
        : _deadZone;
    if (distance <= threshold) {
      _direction = GazeDirection.center;
      return _direction;
    }

    final position = math.atan2(toPointer.dy, toPointer.dx) / (math.pi / 4);

    final current = GazeDirection._ring.indexOf(_direction);
    if (current >= 0) {
      var offset = (position - current) % 8.0;
      if (offset > 4.0) offset -= 8.0;
      if (offset.abs() <= 0.5 + sectorHysteresis) return _direction;
    }

    _direction = GazeDirection._ring[position.round() % 8];
    return _direction;
  }
}

/// User gaze options; sensitivity shrinks the dead zone and widens the radius within which the pet takes interest.
class GazeSettings {
  const GazeSettings({this.enabled = true, this.sensitivity = 0.5});

  final bool enabled;

  final double sensitivity;

  double get deadZone => _lerp(110.0, 24.0, sensitivity.clamp(0.0, 1.0));

  double get interestRadius => _lerp(360.0, 900.0, sensitivity.clamp(0.0, 1.0));

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) =>
      other is GazeSettings &&
      other.enabled == enabled &&
      other.sensitivity == sensitivity;

  @override
  int get hashCode => Object.hash(enabled, sensitivity);
}
