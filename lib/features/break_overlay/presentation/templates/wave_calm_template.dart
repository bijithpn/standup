import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class WaveCalmTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const WaveCalmTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<WaveCalmTemplate> createState() => _WaveCalmTemplateState();
}

class _WaveCalmTemplateState extends State<WaveCalmTemplate>
    with SingleTickerProviderStateMixin {
  /// One 8s period drives every wave phase and the particle twinkle.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_controller, context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = breakAccent(widget.settings, 'wave_calm', _kind.accent);
    // Light theme swaps the waves for a deep blue at the same alphas.
    final waveColor = palette.isDark ? accent : const Color(0xFF3B6E8F);
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, accent.withValues(alpha: 0.06)],
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            // Completion: waves flatten (amplitude -> 0).
            tween: Tween(end: complete ? 1.0 : 0.0),
            duration: BreakMotion.slow,
            curve: BreakMotion.enter,
            builder: (context, flatten, _) => CustomPaint(
              painter: _WavePainter(
                phase: _controller,
                color: waveColor,
                particleColor: palette.isDark
                    ? Colors.white
                    : const Color(0xFF1C1F24),
                flatten: flatten,
              ),
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 300 - 32,
            left: 0,
            right: 0,
            child: BreakEntrance(
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                style: BreakOverlayTheme.hero,
                color: breakClockColor(widget.settings, palette),
              ),
            ),
          ),
          Positioned(
            top: 300 + 32 + 16,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Text(
                'Relax',
                textAlign: TextAlign.center,
                style: BreakOverlayTheme.body.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Animation<double> phase;
  final Color color;
  final Color particleColor;
  final double flatten;

  static const _freq = [1.0, 1.6, 2.3];
  static const _amp = [18.0, 12.0, 8.0];
  static const _speed = [1.0, 0.7, 0.45];
  static const _alpha = [0.10, 0.20, 0.35];
  static const _base = [0.65, 0.72, 0.80]; // top edge as a share of height
  static const int _samples = 64;
  static const int _particles = 12;

  final List<Path> _paths = List.generate(3, (_) => Path());
  final Paint _fill = Paint();
  final Paint _dot = Paint();

  _WavePainter({
    required this.phase,
    required this.color,
    required this.particleColor,
    required this.flatten,
  }) : super(repaint: phase);

  double _y(int wave, double x, Size size, double ph) {
    final k = size.height / 800;
    final t = ph * 2 * math.pi * _speed[wave];
    final a = _amp[wave] * k * (1 - flatten);
    return size.height * _base[wave] +
        a *
            math.sin(
              (x / size.width) * 2 * math.pi * _freq[wave] * 2 + t + wave * 1.7,
            );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ph = phase.value;

    for (var w = 0; w < 3; w++) {
      final path = _paths[w]..reset();
      path.moveTo(0, size.height);
      for (var i = 0; i <= _samples; i++) {
        final x = size.width * i / _samples;
        path.lineTo(x, _y(w, x, size, ph));
      }
      path.lineTo(size.width, size.height);
      path.close();
      _fill.color = color.withValues(alpha: _alpha[w]);
      canvas.drawPath(path, _fill);
    }

    // Particles ride the crests of the highest wave and twinkle.
    final k = size.height / 800;
    for (var j = 0; j < _particles; j++) {
      final x = size.width * (j + 0.5) / _particles;
      final tw = 0.5 + 0.5 * math.sin(ph * 2 * math.pi * 2 + j * 1.3);
      _dot.color = particleColor.withValues(alpha: 0.6 * (0.3 + 0.7 * tw));
      canvas.drawCircle(Offset(x, _y(0, x, size, ph) - 8 * k), 1.0, _dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.color != color ||
      old.particleColor != particleColor ||
      old.flatten != flatten;
}
