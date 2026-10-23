import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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
  late BreathPreset _preset = BreathPreset.byId(widget.settings.breathPreset);

  /// A preset picked mid-cycle starts at the next cycle, so a breath is never
  /// cut short.
  late BreathPreset _pending = _preset;
  double _lastValue = 0;

  /// One controller drives both the breath and the blob morph; one value
  /// spans one cycle of the current preset.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: Duration(seconds: _preset.cycleSeconds),
  );
  late final Animation<double> _fullness = _breath.drive(
    BreathFullness(() => _preset),
  );
  String _phaseText = 'Breathe in';
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  Color get _accent => BreakPalette.of(context).accentOn(
    breakTimeTinted(
      BreakOverlayTheme.resolveAccent(
        widget.settings.templateAccentOverrides,
        'zen',
        _kind.accent,
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    _breath.addListener(_updatePhase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preview frame: peak inhale (scale 1.0).
    breakSyncLoop(_breath, context, park: 0.249);
    _updatePhase();
  }

  void _selectPreset(BreathPreset p) {
    setState(() => _pending = p);
    // Frozen (reduced motion / preview): there is no cycle boundary to wait
    // for, so switch now.
    if (!_breath.isAnimating) _applyPending();
  }

  void _applyPending() {
    _preset = _pending;
    _lastValue = 0;
    _breath.duration = Duration(seconds: _preset.cycleSeconds);
    if (_breath.isAnimating) {
      _breath.repeat();
    } else {
      setState(() {});
    }
  }

  void _updatePhase() {
    final v = _breath.value;
    if (v < _lastValue - 0.5 && _pending != _preset) {
      _applyPending();
      return;
    }
    _lastValue = v;
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
    final palette = BreakPalette.of(context);
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
      background: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.75,
            colors: [_accent.withValues(alpha: 0.05), Colors.transparent],
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 190,
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
                    textAlign: TextAlign.center,
                    style: BreakOverlayTheme.title.copyWith(
                      color: palette.textPrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - 120,
            top: 400 - 120,
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
                    width: 240,
                    height: 240,
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
            top: 120,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(3),
              scale: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final p in BreathPreset.all)
                    _PresetChip(
                      preset: p,
                      selected: p == _pending,
                      accent: _accent,
                      onTap: () => _selectPreset(p),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 400 + 120 + 40,
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
                      fallback: palette.textSecondary,
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

class _PresetChip extends StatelessWidget {
  final BreathPreset preset;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Breathing pattern ${preset.label}',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: BreakMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.16) : null,
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.6)
                    : palette.border,
              ),
            ),
            child: Text(
              preset.label,
              style: BreakOverlayTheme.micro.copyWith(
                color: selected ? palette.textPrimary : palette.textSecondary,
                fontFeatures: BreakOverlayTheme.tabular,
              ),
            ),
          ),
        ),
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
  static const double _baseRadius = 110;

  final Path _path = Path();
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final List<Offset> _ctrl = List.filled(_points, Offset.zero);

  _BlobPainter({
    required this.breath,
    required this.fullness,
    required this.cycleSeconds,
    required this.accent,
    required this.reduced,
  }) : super(repaint: breath) {
    _fill.shader = RadialGradient(
      colors: [accent.withValues(alpha: 0.22), accent.withValues(alpha: 0.0)],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 120));
  }

  /// 0.75 empty, 1.0 full.
  double _scale() => 0.75 + 0.25 * fullness.value;

  @override
  void paint(Canvas canvas, Size size) {
    final v = breath.value;
    final scale = reduced ? 1.0 : _scale();
    // Morph in whole periods per cycle (about 8 s each), so the loop is
    // seamless whatever the preset.
    final cycle = cycleSeconds();
    final periods = (cycle / 8).round().clamp(1, 4);
    final t = v * periods;

    for (var i = 0; i < _points; i++) {
      final a = (math.pi * 2 / _points) * i - math.pi / 2;
      final noise = reduced ? 0.0 : 0.06 * math.sin(2 * math.pi * t + i * 1.3);
      final r = _baseRadius * (1 + noise);
      _ctrl[i] = Offset(math.cos(a) * r, math.sin(a) * r);
    }

    // Closed Catmull-Rom spline as cubic Beziers.
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

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    // Reduced motion trades the scale change for a 60% -> 100% opacity swell.
    final fade = reduced ? 0.6 + 0.4 * fullness.value : 1.0;
    _fill.color = Color.fromRGBO(255, 255, 255, fade);
    _stroke.color = accent.withValues(alpha: 0.5 * fade);
    canvas.drawPath(_path, _fill);
    canvas.drawPath(_path, _stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.accent != accent || old.reduced != reduced;
}
