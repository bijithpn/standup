import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class BreatheLineTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const BreatheLineTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<BreatheLineTemplate> createState() => _BreatheLineTemplateState();
}

class _BreatheLineTemplateState extends State<BreatheLineTemplate>
    with SingleTickerProviderStateMixin {
  /// 4 in, 4 hold, 4 out, 4 hold: the same box pattern as Zen's default.
  static const BreathPreset _preset = BreathPreset.box;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: _preset.cycleSeconds),
  );
  late final Animation<double> _fullness = _controller.drive(
    BreathFullness(() => _preset),
  );
  String _phaseText = 'Breathe in';
  bool _started = false;
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updatePhase);
  }

  void _updatePhase() {
    final phase = switch (_preset.phaseAt(
      _controller.value * _preset.cycleSeconds,
    )) {
      BreathPhase.inhale => 'Breathe in',
      BreathPhase.exhale => 'Breathe out',
      _ => 'Hold',
    };
    if (phase != _phaseText && mounted) setState(() => _phaseText = phase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (BreakPreviewScope.isPreview(context)) {
      // Preview frame: width ~300, glow ~40%.
      _controller.stop();
      _controller.value = 0.175;
    } else if (!_started) {
      // Reduced motion still runs this loop: it only drives opacity there.
      _started = true;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePhase);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      breakAccent(widget.settings, 'breathe_line', _kind.accent),
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
            top: 400 - 28 - 26,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: BreakMotion.medium,
                  child: Text(
                    _phaseText,
                    key: ValueKey(_phaseText),
                    style: BreakOverlayTheme.title.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - 220,
            top: 400 - 50,
            width: 440,
            height: 100,
            child: BreakEntrance(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: complete ? 1.0 : 0.0),
                duration: BreakMotion.slow,
                curve: BreakMotion.enter,
                builder: (context, finish, _) => RepaintBoundary(
                  child: CustomPaint(
                    painter: _LinePainter(
                      progress: _fullness,
                      accent: accent,
                      reduced: reduced,
                      maxGlow: palette.isDark ? 0.55 : 0.18,
                      minGlow: palette.isDark ? 0.25 : 0.10,
                      finish: finish,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 400 + 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    style: BreakOverlayTheme.title,
                    color: breakClockColor(
                      widget.settings,
                      palette,
                      fallback: palette.textPrimary,
                    ),
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
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final Animation<double> progress;
  final Color accent;
  final bool reduced;
  final double maxGlow;
  final double minGlow;

  /// 0..1: extends the line to 420 and fades it out (completion).
  final double finish;

  final Paint _glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final Paint _reflection = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final Paint _fade = Paint();

  _LinePainter({
    required this.progress,
    required this.accent,
    required this.reduced,
    required this.maxGlow,
    required this.minGlow,
    required this.finish,
  }) : super(repaint: progress) {
    _fade.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [accent.withValues(alpha: 0.07), accent.withValues(alpha: 0)],
    ).createShader(const Rect.fromLTWH(0, 0, 420, 40));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Already eased by the breath preset; holds keep the line full or short.
    final eased = progress.value;
    // Width 60 -> 380; reduced motion pins it at 220 and pulses the glow.
    final base = reduced ? 220.0 : 60 + 320 * eased;
    final width = base + (420 - base) * finish;
    final glow = (minGlow + (maxGlow - minGlow) * eased) * (1 - finish);
    final body = 1 - finish;

    final cy = size.height / 2;
    final x0 = (size.width - width) / 2;
    final a = Offset(x0, cy);
    final b = Offset(x0 + width, cy);

    _glow.color = accent.withValues(alpha: glow);
    canvas.drawLine(a, b, _glow);

    _line.color = accent.withValues(alpha: body);
    canvas.drawLine(a, b, _line);

    // Mirrored reflection 10px below, fading out over 40px.
    final ry = cy + 10;
    _reflection.color = accent.withValues(alpha: 0.12 * body);
    canvas.drawLine(Offset(x0, ry), Offset(x0 + width, ry), _reflection);
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(x0, ry, width, 40))
      ..translate((size.width - 420) / 2, ry)
      ..drawRect(const Rect.fromLTWH(0, 0, 420, 40), _fade)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.accent != accent ||
      old.reduced != reduced ||
      old.maxGlow != maxGlow ||
      old.minGlow != minGlow ||
      old.finish != finish;
}
