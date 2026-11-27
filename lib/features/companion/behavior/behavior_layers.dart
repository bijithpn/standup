/// Priority order, lowest first: a higher layer suppresses every layer below it.
enum BehaviorLayer { idle, emotion, activity, interaction }

/// Time-smoothed layer weights so switching layers cross-fades instead of snapping.
/// weight() is exclusive: the weights of all layers sum to at most 1, so layers never fight over a transform.
class BehaviorLayers {
  BehaviorLayers({bool awake = true}) : _w = [awake ? 1.0 : 0.0, 0, 0, 0];

  final List<double> _w;

  // Idle rises slowest: that ramp is the explicit wake transition.
  static const _rise = [0.7, 2.0, 3.0, 10.0];
  static const _fall = [4.0, 1.5, 2.5, 2.5];

  void update(
    double dt, {
    required bool asleep,
    required bool emotion,
    required bool activity,
    required bool interaction,
  }) {
    final wanted = [!asleep, emotion, activity, interaction];
    for (var i = 0; i < 4; i++) {
      final target = wanted[i] ? 1.0 : 0.0;
      final rate = target > _w[i] ? _rise[i] : _fall[i];
      final step = rate * dt;
      _w[i] = target > _w[i]
          ? (_w[i] + step).clamp(0.0, target)
          : (_w[i] - step).clamp(target, 1.0);
    }
  }

  double weight(BehaviorLayer layer) {
    var free = 1.0;
    for (var i = BehaviorLayer.values.length - 1; i > layer.index; i--) {
      free *= 1.0 - _w[i];
    }
    return _w[layer.index] * free;
  }
}
