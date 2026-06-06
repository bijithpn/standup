import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Eye Sync widget implementing the 20-20-20 rule.
class EyeSyncGameWidget extends StatefulWidget {
  final int targetSessions;

  const EyeSyncGameWidget({super.key, this.targetSessions = 3});

  @override
  State<EyeSyncGameWidget> createState() => _EyeSyncGameWidgetState();
}

class _EyeSyncGameWidgetState extends State<EyeSyncGameWidget>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);
  int _completedSessions = 0;
  bool _done = false;

  double _orbX = 0.5;
  double _orbY = 0.5;
  double _targetX = 0.5;
  double _targetY = 0.5;

  late AnimationController _orbController;
  late Animation<Offset> _orbAnimation;
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

  void _moveOrbToTarget() {
    _targetX = 0.15 + _rand.nextDouble() * 0.7;
    _targetY = 0.15 + _rand.nextDouble() * 0.7;

    final fromX = _orbX;
    final fromY = _orbY;

    _orbAnimation =
        Tween<Offset>(
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
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && !_done) _moveOrbToTarget();
        });
      });
  }

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

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildDoneState();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SessionIndicator(
          completed: _completedSessions,
          total: widget.targetSessions,
          color: const Color(0xFF93C5FD),
        ),
        const SizedBox(height: 32),
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
        const SizedBox(height: 24),
        Text(
          'Focus on the drifting orb and blink naturally.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
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
                color: const Color(0xFF93C5FD).withValues(alpha: 0.6),
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF93C5FD).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.visibility_rounded,
              color: Color(0xFF93C5FD),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Eyes refreshed',
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
          'You completed ${widget.targetSessions} sessions.\nYour eye strain should feel reduced.',
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
          width: isActive ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? color.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.1),
          ),
        );
      }),
    );
  }
}

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
          return Container(
            width: 320,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF07080A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  Positioned(
                    left: pos.dx * 280 + 10,
                    top: pos.dy * 160 + 10,
                    child: _GlowingOrb(),
                  ),
                ],
              ),
            ),
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
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF93C5FD),
      ),
    );
  }
}
