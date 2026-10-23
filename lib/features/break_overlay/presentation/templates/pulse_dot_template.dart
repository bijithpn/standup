import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class PulseDotTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const PulseDotTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<PulseDotTemplate> createState() => _PulseDotTemplateState();
}

class _PulseDotTemplateState extends State<PulseDotTemplate>
    with TickerProviderStateMixin {
  static const Offset _core = Offset(640, 340);

  /// One 4s cycle; all three ripples are derived from its phase.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  /// Spring-driven hover offset of the core (unbounded so it can overshoot).
  late final AnimationController _hx = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  late final AnimationController _hy = AnimationController.unbounded(
    vsync: this,
    value: 0,
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
    _hx.dispose();
    _hy.dispose();
    super.dispose();
  }

  void _springTo(Offset target) {
    if (breakShouldFreeze(context)) return;
    _hx.animateWith(
      SpringSimulation(BreakMotion.spring, _hx.value, target.dx, _hx.velocity),
    );
    _hy.animateWith(
      SpringSimulation(BreakMotion.spring, _hy.value, target.dy, _hy.velocity),
    );
  }

  /// Offsets the core up to 6px toward the pointer when it is within 150px.
  void _onHover(PointerEvent e, Size box) {
    final scale = box.width / 440;
    final local = e.localPosition / scale - const Offset(220, 220);
    final dist = local.distance;
    if (dist > 150 || dist == 0) {
      _springTo(Offset.zero);
      return;
    }
    _springTo(local / dist * (6 * (1 - dist / 150).clamp(0.0, 1.0) + 0.0));
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = breakAccent(
      widget.settings,
      'pulse_dot',
      BreakOverlayTheme.mint,
    );
    final reduced = BreakMotion.reduced(context);
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: _core.dx - 220,
            top: _core.dy - 220,
            width: 440,
            height: 440,
            child: BreakEntrance(
              child: MouseRegion(
                opaque: false,
                onHover: reduced
                    ? null
                    : (e) => _onHover(e, const Size(440, 440)),
                onExit: (_) => _springTo(Offset.zero),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: complete ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 700),
                  curve: BreakMotion.enter,
                  builder: (context, finish, _) => RepaintBoundary(
                    child: CustomPaint(
                      painter: _PulsePainter(
                        phase: _controller,
                        hoverX: _hx,
                        hoverY: _hy,
                        accent: accent,
                        reduced: reduced,
                        rippleAlpha: palette.isDark ? 0.4 : 0.3,
                        finish: finish,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: _core.dy + 110 + 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    color: breakClockColor(widget.settings, palette),
                  ),
                ),
                const SizedBox(height: 12),
                BreakEntrance(
                  delay: BreakEntrance.stagger(2),
                  scale: false,
                  child: BreakLabel(_kind.label),
                ),
              ],
            ),
          ),
          Positioned(
            left: 40,
            bottom: 36,
            child: Semantics(
              label: 'Current time',
              excludeSemantics: true,
              child: Text(
                DateFormat('HH:mm').format(DateTime.now()),
                style: BreakOverlayTheme.micro.copyWith(
                  color: palette.textMuted,
                  fontFeatures: BreakOverlayTheme.tabular,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final Animation<double> phase;
  final Animation<double> hoverX;
  final Animation<double> hoverY;
  final Color accent;
  final bool reduced;
  final double rippleAlpha;
  final double finish;

  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _core = Paint();
  final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  _PulsePainter({
    required this.phase,
    required this.hoverX,
    required this.hoverY,
    required this.accent,
    required this.reduced,
    required this.rippleAlpha,
    required this.finish,
  }) : super(repaint: Listenable.merge([phase, hoverX, hoverY]));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = phase.value;

    if (reduced) {
      _ring.color = accent.withValues(alpha: 0.2);
      for (final d in const [60.0, 120.0, 180.0]) {
        canvas.drawCircle(c, d / 2, _ring);
      }
    } else {
      for (var k = 0; k < 3; k++) {
        // 4s cycle, ripples staggered by 1.33s.
        var t = (p * 4 - k * (4 / 3)) / 4;
        t -= t.floorToDouble();
        final e = Curves.easeOutCubic.transform(t);
        final radius = 9 + (110 - 9) * e;
        _ring.color = accent.withValues(alpha: rippleAlpha * (1 - t));
        canvas.drawCircle(c, radius, _ring);
      }
    }

    if (finish > 0) {
      // Completion: one large ripple out to 400px across.
      final e = Curves.easeOutCubic.transform(finish);
      _ring.color = accent.withValues(alpha: rippleAlpha * (1 - finish));
      canvas.drawCircle(c, 110 + (200 - 110) * e, _ring);
    }

    final scale = reduced ? 1.0 : 1.0 + 0.12 * math.sin(math.pi * p);
    final core = c + Offset(hoverX.value, hoverY.value);
    _glow.color = accent.withValues(alpha: 0.4);
    canvas.drawCircle(core, 9 * scale + 6, _glow);
    _core.color = accent;
    canvas.drawCircle(core, 9 * scale, _core);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.accent != accent ||
      old.reduced != reduced ||
      old.rippleAlpha != rippleAlpha ||
      old.finish != finish;
}
