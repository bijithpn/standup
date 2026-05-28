import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Eye Sync game widget implementing the 20-20-20 rule:
///   Look at something ~20 feet away for 20 seconds.
///
/// A glowing orb drifts slowly across the screen to give the eyes a focal
/// target "at distance". A 20-second countdown arc wraps each session.
class EyeSyncGameWidget extends StatefulWidget {
  /// How many 20-second sessions to complete.
  final int targetSessions;

  const EyeSyncGameWidget({super.key, this.targetSessions = 3});

  @override
  State<EyeSyncGameWidget> createState() => _EyeSyncGameWidgetState();
}

class _EyeSyncGameWidgetState extends State<EyeSyncGameWidget>
    with SingleTickerProviderStateMixin {
  // Seconds elapsed in current session
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);

  // Number of sessions completed
  int _completedSessions = 0;

  // Whether all sessions are done
  bool _done = false;

  // Orb position (normalised 0–1) in the "viewport"
  double _orbX = 0.5;
  double _orbY = 0.5;

  // Current orb target
  double _targetX = 0.5;
  double _targetY = 0.5;

  // Orb animation controller
  late AnimationController _orbController;
  late Animation<Offset> _orbAnimation;

  // Session countdown timer
  Timer? _sessionTimer;

  static const _sessionSeconds = 20;

  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _moveOrbToTarget();
    _startSession();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _elapsed.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── Orb movement ──────────────────────────────────────────────────────────

  void _moveOrbToTarget() {
    // Pick a new target away from edges
    _targetX = 0.1 + _rand.nextDouble() * 0.8;
    _targetY = 0.1 + _rand.nextDouble() * 0.65;

    final fromX = _orbX;
    final fromY = _orbY;

    _orbAnimation = Tween<Offset>(
      begin: Offset(fromX, fromY),
      end: Offset(_targetX, _targetY),
    ).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOutCubic),
    );

    _orbController
      ..reset()
      ..forward().then((_) {
        _orbX = _targetX;
        _orbY = _targetY;
        // Schedule next orb move after a short pause
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_done) _moveOrbToTarget();
        });
      });
  }

  // ── Session timer ─────────────────────────────────────────────────────────

  void _startSession() {
    _elapsed.value = 0;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer _) {
    if (!mounted) return;
    _elapsed.value++;
    if (_elapsed.value >= _sessionSeconds) {
      _sessionTimer?.cancel();
      _advanceSession();
    }
  }

  void _advanceSession() {
    final next = _completedSessions + 1;
    if (next >= widget.targetSessions) {
      setState(() {
        _completedSessions = next;
        _done = true;
      });
    } else {
      setState(() => _completedSessions = next);
      _startSession();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildDoneState();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Session indicator
        _SessionIndicator(
          completed: _completedSessions,
          total: widget.targetSessions,
          color: const Color(0xFF38BDF8), // Sky-400
        ),
        const SizedBox(height: 32),

        // Orb viewport
        ValueListenableBuilder<int>(
          valueListenable: _elapsed,
          builder: (context, elapsed, child) {
            final progress = (elapsed / _sessionSeconds).clamp(0.0, 1.0);
            return _EyeSyncViewport(
              orbAnimation: _orbAnimation,
              orbController: _orbController,
              progress: progress,
            );
          },
        ),
        const SizedBox(height: 28),

        // Instruction text
        Text(
          'Focus on the glowing orb and blink naturally.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 13,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<int>(
          valueListenable: _elapsed,
          builder: (context, elapsed, child) {
            return Text(
              '${_sessionSeconds - elapsed}s remaining in this session',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.75),
                fontSize: 12,
                fontFamily: 'Inter',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
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
                const Color(0xFF38BDF8).withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.55),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(Icons.visibility_rounded,
                color: Color(0xFF38BDF8), size: 34),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Eyes Refreshed',
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
          'You completed ${widget.targetSessions} × 20-second sessions.\nYour eye strain should feel reduced.',
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

class _SessionIndicator extends StatelessWidget {
  final int completed;
  final int total;
  final Color color;

  const _SessionIndicator({
    required this.completed,
    required this.total,
    required this.color,
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
                ? color.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }
}

/// A 320×220 "viewport" representing the distant scene, with a glowing orb.
class _EyeSyncViewport extends StatelessWidget {
  final Animation<Offset> orbAnimation;
  final AnimationController orbController;
  final double progress;

  const _EyeSyncViewport({
    required this.orbAnimation,
    required this.orbController,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: orbController,
        builder: (ctx, _) {
          final pos = orbAnimation.value;
          return Stack(
            children: [
              // Viewport frame
              Container(
                width: 320,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF070A0D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      // Subtle grid for depth perception
                      CustomPaint(
                        size: const Size(320, 200),
                        painter: _ViewportGridPainter(),
                      ),

                      // Orb
                      Positioned(
                        left: pos.dx * 300 - 18,
                        top: pos.dy * 180 - 18,
                        child: _GlowingOrb(),
                      ),

                      // Progress arc overlay in bottom-right corner
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CustomPaint(
                            painter: _MiniArcPainter(progress: progress),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowingOrb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFFBAE6FD),
              const Color(0xFF38BDF8).withValues(alpha: 0.7),
              const Color(0xFF0EA5E9).withValues(alpha: 0.3),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewportGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Horizon line
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      paint..color = Colors.white.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_ViewportGridPainter old) => false;
}

class _MiniArcPainter extends CustomPainter {
  final double progress;
  const _MiniArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MiniArcPainter old) => old.progress != progress;
}
