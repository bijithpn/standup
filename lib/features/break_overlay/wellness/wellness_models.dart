import 'dart:math' as math;

/// How a break is shown. [automatic] resolves through [AutoModeRules].
enum BreakDisplayMode { compact, immersive, automatic }

/// Performance/accessibility tier. [still] paints a single composed frame.
enum MotionTier { full, reduced, still }

enum Soundscape { silence, rain, ocean, forest }

enum CompactCorner { topLeft, topRight, bottomLeft, bottomRight }

enum ReminderKind { hydration, stretch, eyes, posture, standup, mindful }

enum BreakFocus { eyes, stretch, hydration, mindful }

/// Explicit user rules for [BreakDisplayMode.automatic]; no heuristics.
class AutoModeRules {
  final bool longBreaksImmersive;
  const AutoModeRules({this.longBreaksImmersive = true});

  BreakDisplayMode resolve({required bool isLongBreak}) =>
      longBreaksImmersive && isLongBreak
      ? BreakDisplayMode.immersive
      : BreakDisplayMode.compact;
}

/// Immutable view of the authoritative timer for one frame of a break.
/// Artwork never owns a timer: it derives everything from this.
class BreakSession {
  final int totalSeconds;
  final int remainingSeconds;
  final int? targetEndMs;
  final int startedAtMs;
  final bool paused;
  final bool complete;
  final BreakFocus focus;
  final MotionTier tier;

  /// 0..1 user preference for motion amplitude.
  final double intensity;
  final Soundscape soundscape;
  final bool timeOfDay;
  final bool strictMode;
  final String title;
  final String instruction;

  const BreakSession({
    required this.totalSeconds,
    required this.remainingSeconds,
    this.targetEndMs,
    required this.startedAtMs,
    this.paused = false,
    this.complete = false,
    this.focus = BreakFocus.eyes,
    this.tier = MotionTier.full,
    this.intensity = 0.6,
    this.soundscape = Soundscape.silence,
    this.timeOfDay = false,
    this.strictMode = false,
    this.title = 'Take a moment',
    this.instruction = 'Relax your shoulders and rest your eyes.',
  });

  /// elapsed / total, clamped. Sub-second precise while running, frozen while
  /// paused (falls back to the 1 Hz remainingSeconds without a target time).
  double progressAt(int nowMs) {
    if (totalSeconds <= 0) return 0;
    if (complete) return 1;
    final end = targetEndMs;
    final remainingMs = (paused || end == null)
        ? remainingSeconds * 1000
        : end - nowMs;
    return (1 - remainingMs / (totalSeconds * 1000)).clamp(0.0, 1.0);
  }

  double get progress => progressAt(DateTime.now().millisecondsSinceEpoch);

  /// Seconds of ambient phase, identical in any window showing the same
  /// break, so compact <-> immersive never restarts the motion.
  double phaseAt(int nowMs) => (nowMs - startedAtMs) / 1000.0;

  BreakSession copyWith({
    int? remainingSeconds,
    bool? paused,
    bool? complete,
    MotionTier? tier,
  }) => BreakSession(
    totalSeconds: totalSeconds,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    targetEndMs: targetEndMs,
    startedAtMs: startedAtMs,
    paused: paused ?? this.paused,
    complete: complete ?? this.complete,
    focus: focus,
    tier: tier ?? this.tier,
    intensity: intensity,
    soundscape: soundscape,
    timeOfDay: timeOfDay,
    strictMode: strictMode,
    title: title,
    instruction: instruction,
  );
}

/// Stable per-template seed so compositions never differ between breaks.
int stableSeed(String id) =>
    id.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

double lerpD(double a, double b, double t) => a + (b - a) * t;
double clamp01(double v) => v.clamp(0.0, 1.0);
double easeInOut(double t) => 0.5 - 0.5 * math.cos(math.pi * clamp01(t));
