import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _forest = BreakPalette(
  canvas: Color(0xFF0F1A16),
  canvasRaised: Color(0xFF16251F),
  surface: Color(0xFF16251F),
  border: Color(0x339DB8A0),
  track: Color(0x339DB8A0),
  textPrimary: Color(0xFFE6EEDF),
  textSecondary: Color(0xFFB9CBB7),
  textMuted: Color(0xFF8DA591),
  isDark: true,
);
const _sage = Color(0xFF9DB8A0);
const _moss = Color(0xFF2F4A3A);

/// Break template: a morphing blob that grows and shrinks with the selected breathing preset, labeled Breathe in/out/Hold.
class ZenModeTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ZenModeTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ZenModeTemplate> createState() => _ZenModeTemplateState();
}

class _ZenModeTemplateState extends State<ZenModeTemplate>
    with SingleTickerProviderStateMixin {
  late final BreathPreset _preset = BreathPreset.byId(
    widget.settings.breathPreset,
  );

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: Duration(seconds: _preset.cycleSeconds),
  );
  late final Animation<double> _fullness = _breath.drive(
    BreathFullness(() => _preset),
  );
  String _phaseText = 'Breathe in';

  Color get _accent => breakAccent(widget.settings, 'zen', _sage);

  @override
  void initState() {
    super.initState();
    _breath.addListener(_updatePhase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    breakSyncLoop(_breath, context, park: 0.249);
    _updatePhase();
  }

  void _updatePhase() {
    final v = _breath.value;
    final phase = switch (_preset.phaseAt(v * _preset.cycleSeconds)) {
      BreathPhase.inhale => 'Breathe in',
      BreathPhase.exhale => 'Breathe out',
      _ => 'Hold',
    };
    if (phase != _phaseText) setState(() => _phaseText = phase);
  }

  @override
  void dispose() {
    _breath.removeListener(_updatePhase);
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const palette = _forest;
    final reduced = BreakMotion.reduced(context);
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      palette: _forest,
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF16261F), Color(0xFF0B130F)],
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 640 - 210,
            top: 340 - 210,
            child: BreakEntrance(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: complete ? 0.9 : 1.0),
                duration: BreakMotion.slow,
                curve: BreakMotion.enter,
                builder: (context, settle, child) => Opacity(
                  opacity: complete ? 0.0 : 1.0,
                  child: Transform.scale(scale: settle, child: child),
                ),
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 420,
                    height: 420,
                    child: CustomPaint(
                      painter: _BlobPainter(
                        breath: _breath,
                        fullness: _fullness,
                        cycleSeconds: () => _preset.cycleSeconds,
                        accent: _accent,
                        reduced: reduced,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 340 - 34,
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
                    style: BreakOverlayTheme.serif.copyWith(
                      fontSize: 56,
                      height: 1.0,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 340 + 210 + 36,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                style: BreakOverlayTheme.display.copyWith(letterSpacing: 6),
                color: breakClockColor(
                  widget.settings,
                  palette,
                  fallback: palette.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Animation<double> breath;
  final Animation<double> fullness;
  final int Function() cycleSeconds;
  final Color accent;
  final bool reduced;

  static const int _points = 6;
  static const double _baseRadius = 190;

  final Path _path = Path();
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final List<Offset> _ctrl = List.filled(_points, Offset.zero);

  static const _layers = [
    (1.0, 0.0, _moss, 0.55),
    (0.8, 0.35, _sage, 0.22),
    (0.58, 0.7, _sage, 0.3),
  ];

  _BlobPainter({
    required this.breath,
    required this.fullness,
    required this.cycleSeconds,
    required this.accent,
    required this.reduced,
  }) : super(repaint: breath);

  double _scale() => 0.75 + 0.25 * fullness.value;

  @override
  void paint(Canvas canvas, Size size) {
    final v = breath.value;
    final scale = reduced ? 1.0 : _scale();

    final cycle = cycleSeconds();
    final periods = (cycle / 8).round().clamp(1, 4);
    final t = v * periods;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    final fade = reduced ? 0.6 + 0.4 * fullness.value : 1.0;
    for (final (span, phase, color, alpha) in _layers) {
      _shape(t + phase, span);
      _fill.color = color.withValues(alpha: alpha * fade);
      canvas.drawPath(_path, _fill);
    }
    _shape(t, 1.0);
    _stroke.color = accent.withValues(alpha: 0.6 * fade);
    canvas.drawPath(_path, _stroke);
    canvas.restore();
  }

  void _shape(double t, double size) {
    for (var i = 0; i < _points; i++) {
      final a = (math.pi * 2 / _points) * i - math.pi / 2;
      final noise = reduced ? 0.0 : 0.07 * math.sin(2 * math.pi * t + i * 1.3);
      final r = _baseRadius * size * (1 + noise);
      _ctrl[i] = Offset(math.cos(a) * r, math.sin(a) * r);
    }

    _path.reset();
    _path.moveTo(_ctrl[0].dx, _ctrl[0].dy);
    for (var i = 0; i < _points; i++) {
      final p0 = _ctrl[(i - 1 + _points) % _points];
      final p1 = _ctrl[i];
      final p2 = _ctrl[(i + 1) % _points];
      final p3 = _ctrl[(i + 2) % _points];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      _path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    _path.close();
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.accent != accent || old.reduced != reduced;
}
