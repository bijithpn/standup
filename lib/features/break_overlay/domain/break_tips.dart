import 'package:clock/clock.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';

/// Short, actionable tips per break type, so templates that rotate guidance
/// (Split View, the companion's bubbles) have more than the one tip a break
/// arrives with.
abstract final class BreakTips {
  static const List<String> eyeRest = [
    'Look at something about 20 feet away.',
    'Blink slowly ten times to re-wet your eyes.',
    'Close your eyes and let them rest for a few seconds.',
    'Look out a window and let your focus soften.',
    'Roll your eyes in a slow circle, then the other way.',
    'Raise your screen so your gaze tilts slightly down.',
  ];

  static const List<String> recovery = [
    'Stand up and roll your shoulders back.',
    'Take three slow breaths, longer out than in.',
    'Walk to a window or fill a glass of water.',
    'Stretch your wrists and fingers gently.',
    'Reach overhead, then fold forward and let your neck hang.',
    'Unclench your jaw and drop your shoulders.',
  ];

  static List<String> forBreak(BreakModel info) =>
      info.type == BreakType.long ? recovery : eyeRest;

  /// Up to [count] tips other than the break's own, starting from a point that
  /// moves by day so repeated breaks do not always show the same ones.
  static List<String> extra(BreakModel info, {int count = 2}) {
    final pool = forBreak(info).where((t) => t != info.tip).toList();
    if (pool.isEmpty) return const [];
    final start = clock.now().difference(DateTime(2024)).inDays % pool.length;
    return [
      for (var i = 0; i < count.clamp(0, pool.length); i++)
        pool[(start + i) % pool.length],
    ];
  }
}
