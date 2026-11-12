import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _night = BreakPalette(
  canvas: Color(0xFF0C1030),
  canvasRaised: Color(0xFF161A4A),
  surface: Color(0xFF161A4A),
  border: Color(0x33C9CCF5),
  track: Color(0x33C9CCF5),
  textPrimary: Color(0xFFF1F0FF),
  textSecondary: Color(0xFFC9CCF5),
  textMuted: Color(0xFFA9ADDD),
  isDark: true,
);
const _ink = Color(0xFF1A1440);
const _sun = Color(0xFFFF9E6B);

class FocusOrbTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const FocusOrbTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<FocusOrbTemplate> createState() => _FocusOrbTemplateState();
}

class _FocusOrbTemplateState extends State<FocusOrbTemplate>
    with SingleTickerProviderStateMixin {
  /// Scale 0.97 -> 1.03 over 6s.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_breath, context, reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hue = breakAccent(widget.settings, 'focus_orb', _sun);
    final kind = BreakKind.of(widget.breakInfo);
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: hue,
      palette: _night,
      background: const _Sky(),
      child: Stack(
        children: [
          Positioned(
            left: 640 - 210,
            top: 370 - 210,
            width: 420,
            height: 420,
            child: BreakEntrance(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: complete ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 400),
                builder: (context, finish, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(420, 420),
                        painter: _OrbPainter(
                          breath: _breath,
                          color: hue,
                          finish: finish,
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
                child: BreakCountdown(
                  seconds: widget.remainingSeconds,
                  style: BreakOverlayTheme.hero.copyWith(
                    fontSize: 96,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -3,
                  ),
                  color: breakClockColor(
                    widget.settings,
                    _night,
                    fallback: _ink,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 370 + 210 + 44,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Text(
                kind.label,
                textAlign: TextAlign.center,
                style: BreakOverlayTheme.serif.copyWith(
                  fontSize: 26,
                  color: _night.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sky extends StatelessWidget {
  const _Sky();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _SkyPainter(), size: Size.infinite);
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF080A24), Color(0xFF191B5C), Color(0xFF3A2670)],
        ).createShader(rect),
    );
    final rng = math.Random(11);
    final star = Paint();
    for (var i = 0; i < 70; i++) {
      final r = rng.nextDouble();
      star.color = const Color(0xFFE8E6FF).withValues(alpha: 0.25 + 0.5 * r);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.6 + 1.2 * r,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}

class _OrbPainter extends CustomPainter {
  final Animation<double> breath;
  final Color color;
  final double finish;

  final Paint _fill = Paint();

  _OrbPainter({required this.breath, required this.color, required this.finish})
    : super(repaint: breath);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeInOutSine.transform(breath.value);
    final radius = size.width / 2 * (0.94 + 0.06 * eased);
    final center = size.center(Offset.zero);
    final rim = Color.lerp(color, const Color(0xFFD23F8B), 0.7)!;
    _fill.shader = RadialGradient(
      center: const Alignment(-0.3, -0.35),
      radius: 1.05,
      colors: [
        Color.lerp(color, const Color(0xFFFFF3D6), 0.75 + 0.25 * finish)!,
        color,
        rim,
      ],
      stops: const [0, 0.55, 1],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, _fill);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.color != color || old.finish != finish;
}
