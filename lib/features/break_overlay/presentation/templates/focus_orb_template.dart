import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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
  static const Color _cyan = Color(0xFF8BC9D4);

  /// Scale 0.97 -> 1.03 over 6s.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  late final DateTime _now = clock.now();

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
    final palette = BreakPalette.of(context);
    final base = breakAccent(widget.settings, 'focus_orb', _cyan);
    final hue = palette.accentOn(breakTimeTinted(base, now: _now));
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: hue,
      child: Stack(
        children: [
          Positioned(
            left: 640 - 160,
            top: 380 - 160,
            width: 320,
            height: 320,
            child: BreakEntrance(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: complete ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 400),
                builder: (context, finish, child) => Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(320, 320),
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
                  style: BreakOverlayTheme.hero.copyWith(fontSize: 72),
                  color: breakClockColor(widget.settings, palette),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Animation<double> breath;
  final Color color;
  final double finish;

  final Paint _fill = Paint();
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  _OrbPainter({required this.breath, required this.color, required this.finish})
    : super(repaint: breath);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeInOutSine.transform(breath.value);
    final radius = size.width / 2 * (0.94 + 0.06 * eased);
    final center = size.center(Offset.zero);
    _fill.color = color.withValues(alpha: 0.10 + 0.12 * finish);
    _ring.color = color.withValues(alpha: 0.6);
    canvas.drawCircle(center, radius, _fill);
    canvas.drawCircle(center, radius, _ring);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.color != color || old.finish != finish;
}
