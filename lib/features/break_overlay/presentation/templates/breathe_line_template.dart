import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _dusk = BreakPalette(
  canvas: Color(0xFF08242F),
  canvasRaised: Color(0xFF0F3441),
  surface: Color(0xFF0F3441),
  border: Color(0x33F8EBDD),
  track: Color(0x33F8EBDD),
  textPrimary: Color(0xFFFBF0E4),
  textSecondary: Color(0xFFF1DCC6),
  textMuted: Color(0xFFE6CDB5),
  isDark: true,
);
const _peach = Color(0xFFF6BE9A);

/// Break template: a line that rises and falls with the selected breathing preset over a dusk sky.
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
  late final BreathPreset _preset = BreathPreset.byId(
    widget.settings.breathPreset,
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: _preset.cycleSeconds),
  );
  late final Animation<double> _fullness = _controller.drive(
    BreathFullness(() => _preset),
  );
  String _phaseText = 'Breathe in';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updatePhase);
  }

  // Rebuilds only when the phase label changes, not on every animation tick.
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
    // Previews park the breath at a fixed mid-inhale frame instead of looping.
    if (BreakPreviewScope.isPreview(context)) {
      _controller.stop();
      _controller.value = 0.175;
    } else if (!_started) {
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
    const palette = _dusk;
    final accent = breakAccent(widget.settings, 'breathe_line', _peach);
    final reduced = BreakMotion.reduced(context);
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      palette: palette,
      background: const _SkyAndWater(),
      child: Stack(
        children: [
          Positioned(
            top: 400 - 110,
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
                      fontSize: 52,
                      height: 1.0,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - 280,
            top: 400 - 10,
            width: 560,
            height: 180,
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
                      finish: finish,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 400 + 190,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                style: BreakOverlayTheme.display,
                color: breakClockColor(
                  widget.settings,
                  palette,
                  fallback: palette.textSecondary,
                ),
              ),
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

  final double finish;

  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;

  _LinePainter({
    required this.progress,
    required this.accent,
    required this.reduced,
    required this.finish,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = progress.value;
    final base = reduced ? 300.0 : 120 + 440 * eased;
    final width = base + (size.width - base) * finish;
    final cx = size.width / 2;

    final breath = reduced ? 0.5 + 0.5 * eased : 1.0;
    final fade = breath * (1 - finish);

    for (var i = 0; i < 5; i++) {
      final w = width * (0.82 - i * 0.14);
      final y = 10 + 18.0 * (i + 1) + 3.0 * i * i;
      _line
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: fade * (0.85 - i * 0.15));
      canvas.drawLine(Offset(cx - w / 2, y), Offset(cx + w / 2, y), _line);
    }
    _line
      ..strokeWidth = 4
      ..color = const Color(0xFFFFF6EA).withValues(alpha: fade);
    canvas.drawLine(
      Offset(cx - width / 2, 10),
      Offset(cx + width / 2, 10),
      _line,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.accent != accent || old.reduced != reduced || old.finish != finish;
}

class _SkyAndWater extends StatelessWidget {
  const _SkyAndWater();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.3, 0.46, 0.5, 0.5, 1],
          colors: [
            Color(0xFF08242F),
            Color(0xFF1D4F5C),
            Color(0xFFC98F7D),
            _peach,
            Color(0xFF1B4753),
            Color(0xFF061B24),
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
