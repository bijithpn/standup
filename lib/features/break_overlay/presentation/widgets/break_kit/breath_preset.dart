import 'package:flutter/animation.dart';

enum BreathPhase { inhale, holdFull, exhale, holdEmpty }

/// A breathing pattern in whole seconds: in, hold, out, hold.
class BreathPreset {
  final String id;
  final String label;
  final int inhale;
  final int holdFull;
  final int exhale;
  final int holdEmpty;

  const BreathPreset(
    this.id,
    this.label, {
    required this.inhale,
    required this.holdFull,
    required this.exhale,
    required this.holdEmpty,
  });

  static const box = BreathPreset(
    'box',
    '4-4-4-4',
    inhale: 4,
    holdFull: 4,
    exhale: 4,
    holdEmpty: 4,
  );
  static const relax = BreathPreset(
    'relax',
    '4-7-8',
    inhale: 4,
    holdFull: 7,
    exhale: 8,
    holdEmpty: 0,
  );
  static const even = BreathPreset(
    'even',
    '5-5',
    inhale: 5,
    holdFull: 0,
    exhale: 5,
    holdEmpty: 0,
  );

  static const all = [box, relax, even];

  static BreathPreset byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => box);

  int get cycleSeconds => inhale + holdFull + exhale + holdEmpty;

  /// The phase [seconds] into a cycle. Zero-length phases are skipped.
  BreathPhase phaseAt(double seconds) {
    final t = seconds % cycleSeconds;
    if (t < inhale) return BreathPhase.inhale;
    if (t < inhale + holdFull) return BreathPhase.holdFull;
    if (t < inhale + holdFull + exhale) return BreathPhase.exhale;
    return BreathPhase.holdEmpty;
  }

  /// 0 (empty) to 1 (full) [seconds] into a cycle, eased on inhale and exhale.
  double fullnessAt(double seconds) {
    final t = seconds % cycleSeconds;
    const ease = Curves.easeInOutSine;
    if (t < inhale) return ease.transform(t / inhale);
    if (t < inhale + holdFull) return 1;
    final out = t - inhale - holdFull;
    if (out < exhale) return 1 - ease.transform(out / exhale);
    return 0;
  }
}

/// Maps a controller value (0..1 over one cycle of the current preset) to
/// breath fullness, so painters can listen to the controller directly.
class BreathFullness extends Animatable<double> {
  final BreathPreset Function() preset;

  BreathFullness(this.preset);

  @override
  double transform(double t) {
    final p = preset();
    return p.fullnessAt(t * p.cycleSeconds);
  }
}
