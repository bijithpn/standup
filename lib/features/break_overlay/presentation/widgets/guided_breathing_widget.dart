import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Guided breathing widget using the 4-7-8 technique.
class GuidedBreathingWidget extends StatefulWidget {
  final int targetCycles;

  const GuidedBreathingWidget({super.key, this.targetCycles = 3});

  @override
  State<GuidedBreathingWidget> createState() => _GuidedBreathingWidgetState();
}

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
    label: 'Breathe in',
    sublabel: 'Fill your lungs slowly',
    color: Color(0xFF93C5FD), // Muted sky blue
  ),
  _PhaseData(
    phase: _BreathPhase.holdIn,
    durationSeconds: 7,
    label: 'Hold',
    sublabel: 'Keep the air inside',
    color: Color(0xFFD8B4FE), // Muted purple
  ),
  _PhaseData(
    phase: _BreathPhase.exhale,
    durationSeconds: 8,
    label: 'Breathe out',
    sublabel: 'Release all tension',
    color: Color(0xFFA7F3D0), // Muted sage green
  ),
  _PhaseData(
    phase: _BreathPhase.holdOut,
    durationSeconds: 1,
    label: 'Rest',
    sublabel: 'Prepare for the next breath',
    color: Color(0xFFFDE047), // Muted warm amber
  ),
];

class _GuidedBreathingWidgetState extends State<GuidedBreathingWidget>
    with SingleTickerProviderStateMixin {
  int _phaseIndex = 0;
  final ValueNotifier<int> _phaseElapsed = ValueNotifier<int>(0);
  int _completedCycles = 0;
  bool _done = false;
  Timer? _ticker;

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
        _ringScale = Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: _ringController, curve: Curves.easeInOutSine),
        );
        _ringController
          ..reset()
          ..forward();
        break;
      case _BreathPhase.holdIn:
        _ringScale = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.04).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 1,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 1,
          ),
        ]).animate(_ringController);
        _ringController
          ..reset()
          ..repeat();
        break;
      case _BreathPhase.exhale:
        _ringScale = Tween<double>(begin: 1.0, end: 0.7).animate(
          CurvedAnimation(parent: _ringController, curve: Curves.easeInOutSine),
        );
        _ringController
          ..reset()
          ..forward();
        break;
      case _BreathPhase.holdOut:
        _ringScale = const AlwaysStoppedAnimation<double>(0.7);
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

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildDoneState();

    final phase = _phases[_phaseIndex];
    const ringRadius = 110.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CycleIndicator(
          completed: _completedCycles,
          total: widget.targetCycles,
          activeColor: phase.color,
        ),
        const SizedBox(height: 32),
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
                      },
                    ),
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: ringRadius * 2 - 16,
                        height: ringRadius * 2 - 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: phase.color.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          phase.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Inter',
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
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          phase.sublabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontFamily: 'Inter',
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFA7F3D0).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              color: Color(0xFFA7F3D0),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Session complete',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w300,
            fontFamily: 'Inter',
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You completed ${widget.targetCycles} breathing cycles.\nYour nervous system thanks you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            height: 1.5,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

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
          width: isActive ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? activeColor.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.1),
          ),
        );
      }),
    );
  }
}

class _PhaseArcPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _PhaseArcPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius - 2, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
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
