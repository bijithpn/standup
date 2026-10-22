import 'dart:math' as math;
import 'dart:ui' show Offset;

/// The nine places a companion can look, matching the 3×3 direction model used
/// by cursor-tracking mascots: eight compass sectors around a relaxed centre.
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

  /// -1 left, 0 centre, 1 right.
  final int column;

  /// -1 up, 0 centre, 1 down (screen space, y grows downward).
  final int row;

  /// Unit vector for this sector in screen space; zero for [center].
  Offset get unit {
    if (this == GazeDirection.center) return Offset.zero;
    final length = math.sqrt((column * column + row * row).toDouble());
    return Offset(column / length, row / length);
  }

  /// A phrase for assistive technology.
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

  // Compass sectors in the order atan2 walks them, starting at +x (right) and
  // turning clockwise on screen.
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

/// Turns a vector from the companion's eyes to the pointer into a
/// [GazeDirection], without flicking between sectors near a boundary.
///
/// Two kinds of hysteresis keep the answer stable:
///
///  * Radial: the dead zone is entered at [deadZone] but only left at
///    `deadZone * deadZoneExit`, so a pointer resting on the rim does not make
///    the pet look back and forth between "straight ahead" and a side.
///  * Angular: a sector is kept until the pointer is more than
///    `0.5 + sectorHysteresis` sectors from its centre, so the head only turns
///    once the pointer has clearly crossed over.
class GazeSectorTracker {
  GazeSectorTracker({
    double deadZone = 60.0,
    this.deadZoneExit = 1.3,
    this.sectorHysteresis = 0.18,
  }) : _deadZone = deadZone;

  /// Leaving the dead zone needs the pointer past this multiple of its radius.
  final double deadZoneExit;

  /// Extra fraction of a sector the pointer must travel past a boundary before
  /// the sector changes. 0 disables angular hysteresis.
  final double sectorHysteresis;

  double _deadZone;
  GazeDirection _direction = GazeDirection.center;

  /// Radius in logical pixels inside which the pet looks relaxed.
  double get deadZone => _deadZone;
  set deadZone(double value) => _deadZone = math.max(0.0, value);

  GazeDirection get direction => _direction;

  /// Forgets the current sector, e.g. when the pet moves to another display.
  void reset() => _direction = GazeDirection.center;

  /// Updates the sector for the pointer offset [toPointer] (pointer minus eye
  /// position, screen space) and returns it.
  GazeDirection update(Offset toPointer) {
    final distance = toPointer.distance;

    // Settled in the centre, the pointer has to get clearly outside to pull
    // the gaze away; looking off-centre, it only has to get back inside.
    final threshold = _direction == GazeDirection.center
        ? _deadZone * deadZoneExit
        : _deadZone;
    if (distance <= threshold) {
      _direction = GazeDirection.center;
      return _direction;
    }

    // Position on the ring, in sectors: 0 is right, 2 is down, 4 is left.
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

/// Everything that decides how closely the pet follows the pointer.
class GazeSettings {
  const GazeSettings({this.enabled = true, this.sensitivity = 0.5});

  /// Master switch. When false the pet never looks at the pointer.
  final bool enabled;

  /// 0..1. Higher means a smaller dead zone and a wider area of interest.
  final double sensitivity;

  /// Dead zone radius in logical pixels.
  double get deadZone => _lerp(110.0, 24.0, sensitivity.clamp(0.0, 1.0));

  /// Distance beyond which the pointer is no longer interesting.
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
