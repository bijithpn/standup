import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class NightSkyTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const NightSkyTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<NightSkyTemplate> createState() => _NightSkyTemplateState();
}

class _Star {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
  });
}

class _NightSkyTemplateState extends State<NightSkyTemplate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkleController;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _twinkleController.repeatUnlessReducedMotion();
    final rand = math.Random(7);
    _stars = List.generate(
      100,
      (_) => _Star(
        dx: rand.nextDouble(),
        dy: rand.nextDouble(),
        size: 1.0 + rand.nextDouble() * 1.6,
        phase: rand.nextDouble() * 2 * math.pi,
      ),
    );
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  double get _progress => widget.totalSeconds > 0
      ? (1 - widget.remainingSeconds / widget.totalSeconds).clamp(0.0, 1.0)
      : 0.0;

  bool get _isEnding => widget.remainingSeconds <= 0 || _progress >= 0.95;

  @override
  Widget build(BuildContext context) {
    final topColor = Color.lerp(
      const Color(0xFF0A0E27),
      const Color(0xFF6D3B8C),
      _progress,
    )!;
    final bottomColor = Color.lerp(
      const Color(0xFF05060F),
      const Color(0xFFE8873A),
      _progress,
    )!;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, bottomColor],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _twinkleController,
            builder: (context, _) => CustomPaint(
              painter: _StarfieldPainter(
                stars: _stars,
                time: _twinkleController.value,
                opacity: (1 - _progress * 0.7).clamp(0.2, 1.0),
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  child: Column(
                    key: ValueKey(_isEnding),
                    children: [
                      Text(
                        _isEnding ? 'Recharged & Ready' : 'Time to Switch Off',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          fontFamily: BreakOverlayTheme.fontFamily,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 480,
                        child: Text(
                          _isEnding
                              ? "That time away was well-invested. Now "
                                    "you're ready to tackle whatever comes "
                                    "next with fresh perspective."
                              : "It's time to turn off the screen. Treat "
                                    "yourself to a break from the digital "
                                    "world now.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 15,
                            fontFamily: BreakOverlayTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  _formatTime(widget.remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    fontFamily: BreakOverlayTheme.fontFamily,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isEnding
                  ? _NightSkyPill(
                      key: const ValueKey('complete'),
                      label: 'Complete Session',
                      filled: true,
                      onTap: widget.onSkip,
                    )
                  : Row(
                      key: const ValueKey('controls'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.settings.strictMode &&
                            widget.onSkip != null)
                          _NightSkyPill(label: 'Skip', onTap: widget.onSkip),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NightSkyPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _NightSkyPill({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? Colors.black87 : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: BreakOverlayTheme.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;
  final double opacity;

  _StarfieldPainter({
    required this.stars,
    required this.time,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final twinkle =
          0.4 + 0.6 * (0.5 + 0.5 * math.sin(time * 2 * math.pi + star.phase));
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: twinkle * opacity);
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.opacity != opacity;
}
