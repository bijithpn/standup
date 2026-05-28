import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Guided breathing widget using the 4-7-8 technique:
///   Inhale 4 s → Hold 7 s → Exhale 8 s → (brief pause 1 s) = 20 s per cycle.
class GuidedBreathingWidget extends StatefulWidget {
  /// Number of full cycles to complete before showing the "done" state.
  final int targetCycles;

  const GuidedBreathingWidget({super.key, this.targetCycles = 3});

  @override
  State<GuidedBreathingWidget> createState() => _GuidedBreathingWidgetState();
}

// ── Phase data ──────────────────────────────────────────────────────────────

enum _BreathPhase { inhale, holdIn, exhale, holdOut }

class _PhaseData {
  final _BreathPhase phase;
  final int durationSeconds;
  final String label;
  final String sublabel;
  final Color color;

  const _PhaseData({
    required this.phase,
    required this.durationSeconds,
    required this.label,
    required this.sublabel,
    required this.color,
  });
}

const _phases = [
  _PhaseData(
    phase: _BreathPhase.inhale,
    durationSeconds: 4,
    label: 'Breathe In',
    sublabel: 'Fill your lungs slowly',
    color: Color(0xFF7DD3FC), // Sky-400
  ),
  _PhaseData(
    phase: _BreathPhase.holdIn,
    durationSeconds: 7,
    label: 'Hold',
    sublabel: 'Keep the air inside',
    color: Color(0xFFC084FC), // Purple-400
  ),
  _PhaseData(
    phase: _BreathPhase.exhale,
    durationSeconds: 8,
    label: 'Breathe Out',
    sublabel: 'Release all tension',
    color: Color(0xFF86EFAC), // Green-300
  ),
  _PhaseData(
    phase: _BreathPhase.holdOut,
    durationSeconds: 1,
    label: 'Rest',
    sublabel: 'Prepare for the next breath',
    color: Color(0xFFFDE68A), // Amber-200
  ),
];

// ── State ────────────────────────────────────────────────────────────────────

class _GuidedBreathingWidgetState extends State<GuidedBreathingWidget>
    with SingleTickerProviderStateMixin {
  // Current phase index into _phases
  int _phaseIndex = 0;

  // Seconds elapsed in the current phase
  final ValueNotifier<int> _phaseElapsed = ValueNotifier<int>(0);

  // Total completed cycles
  int _completedCycles = 0;

  // Whether the session is fully done
  bool _done = false;

  Timer? _ticker;

  // Smooth animation for the ring scale (separate from the discrete timer)
  late AnimationController _ringController;
  late Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _phases[_phaseIndex].durationSeconds),
    );
    _applyPhaseAnimation();
    _startPhase();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _phaseElapsed.dispose();
    _ringController.dispose();
    super.dispose();
  }

  void _applyPhaseAnimation() {
    final phase = _phases[_phaseIndex];
    _ringController.duration = Duration(seconds: phase.durationSeconds);
    switch (phase.phase) {
      case _BreathPhase.inhale:
        // Expand from 0.45 → 1.0
        _ringScale = Tween<double>(begin: 0.45, end: 1.0).animate(
          CurvedAnimation(parent: _ringController, curve: Curves.easeInOutSine),
        );
        _ringController
          ..reset()
          ..forward();
        break;
      case _BreathPhase.holdIn:
        // Stay at 1.0 (pulse gently)
        _ringScale = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.06)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 1,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.06, end: 1.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 1,
          ),
        ]).animate(_ringController);
        _ringController
          ..reset()
          ..repeat();
        break;
      case _BreathPhase.exhale:
        // Shrink from 1.0 → 0.45
        _ringScale = Tween<double>(begin: 1.0, end: 0.45).animate(
          CurvedAnimation(parent: _ringController, curve: Curves.easeInOutSine),
        );
        _ringController
          ..reset()
          ..forward();
        break;
      case _BreathPhase.holdOut:
        _ringScale = const AlwaysStoppedAnimation<double>(0.45);
        _ringController.reset();
        break;
    }
  }

  void _startPhase() {
    _phaseElapsed.value = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer _) {
    if (!mounted) return;
    final phase = _phases[_phaseIndex];
    _phaseElapsed.value++;

    if (_phaseElapsed.value >= phase.durationSeconds) {
      _ticker?.cancel();
      _advancePhase();
    }
  }

  void _advancePhase() {
    final nextPhaseIndex = (_phaseIndex + 1) % _phases.length;

    // If we wrapped around to inhale again → completed one cycle
    if (nextPhaseIndex == 0) {
      final newCycles = _completedCycles + 1;
      if (newCycles >= widget.targetCycles) {
        setState(() {
          _completedCycles = newCycles;
          _done = true;
        });
        return;
      }
      setState(() {
        _completedCycles = newCycles;
        _phaseIndex = nextPhaseIndex;
      });
    } else {
      setState(() {
        _phaseIndex = nextPhaseIndex;
      });
    }

    _applyPhaseAnimation();
    _startPhase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildDoneState();

    final phase = _phases[_phaseIndex];
    const ringRadius = 140.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cycle counter
        _CycleIndicator(
          completed: _completedCycles,
          total: widget.targetCycles,
          activeColor: phase.color,
        ),
        const SizedBox(height: 36),

        // Animated ring + label
        RepaintBoundary(
          child: SizedBox(
            width: ringRadius * 2,
            height: ringRadius * 2,
            child: AnimatedBuilder(
              animation: _ringController,
              builder: (ctx, child) {
                final scale = _ringScale.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background ring (arc showing phase progress)
                    ValueListenableBuilder<int>(
                      valueListenable: _phaseElapsed,
                      builder: (context, elapsed, child) {
                        final progress = (elapsed / phase.durationSeconds).clamp(0.0, 1.0);
                        return CustomPaint(
                          size: const Size.square(ringRadius * 2),
                          painter: _PhaseArcPainter(
                            color: phase.color,
                            progress: progress,
                          ),
                        );
                      }
                    ),

                    // Breathing orb
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: ringRadius * 2 - 16,
                        height: ringRadius * 2 - 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              phase.color.withValues(alpha: 0.18),
                              phase.color.withValues(alpha: 0.04),
                            ],
                          ),
                          border: Border.all(
                            color: phase.color.withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    // Phase text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            phase.label,
                            key: ValueKey(phase.phase),
                            style: TextStyle(
                              color: phase.color,
                              fontSize: 26,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -0.3,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<int>(
                          valueListenable: _phaseElapsed,
                          builder: (context, elapsed, child) {
                            return Text(
                              '${phase.durationSeconds - elapsed}s',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Sublabel instruction
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            phase.sublabel,
            key: ValueKey(phase.phase),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 13,
              fontFamily: 'Inter',
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF86EFAC).withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: const Color(0xFF86EFAC).withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: Color(0xFF86EFAC), size: 36),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Session Complete',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w300,
            fontFamily: 'Inter',
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You completed ${widget.targetCycles} breathing cycles.\nYour nervous system thanks you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 13,
            height: 1.6,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Small dot indicator showing completed / remaining cycles.
class _CycleIndicator extends StatelessWidget {
  final int completed;
  final int total;
  final Color activeColor;

  const _CycleIndicator({
    required this.completed,
    required this.total,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i < completed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 20 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? activeColor.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }
}

/// Custom arc painter for per-phase progress.
class _PhaseArcPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _PhaseArcPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 2, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 2),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PhaseArcPainter old) =>
      old.progress != progress || old.color != color;
}
