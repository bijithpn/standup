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
  /// The user's chosen breathing pattern (box 4-4-4-4 by default).
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
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            top: 400 - 90,
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
                      fontSize: 34,
                      fontWeight: FontWeight.w400,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - 220,
            top: 400 - 10,
            width: 440,
            height: 20,
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
                      track: palette.border,
                      reduced: reduced,
                      finish: finish,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 400 + 64,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                style: BreakOverlayTheme.title,
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

class _LinePainter extends CustomPainter {
  final Animation<double> progress;
  final Color accent;
  final Color track;
  final bool reduced;

  /// 0..1: extends the line to full width and fades it out (completion).
  final double finish;

  final Paint _track = Paint()..strokeWidth = 1;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  _LinePainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.reduced,
    required this.finish,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final eased = progress.value;
    final base = reduced ? 220.0 : 60 + 320 * eased;
    final width = base + (size.width - base) * finish;
    final cy = size.height / 2;
    final x0 = (size.width - width) / 2;

    _track.color = track;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), _track);

    // Reduced motion pins the width, so the breath shows as opacity instead.
    final breath = reduced ? 0.5 + 0.5 * eased : 1.0;
    _line.color = accent.withValues(alpha: breath * (1 - finish));
    canvas.drawLine(Offset(x0, cy), Offset(x0 + width, cy), _line);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.accent != accent ||
      old.track != track ||
      old.reduced != reduced ||
      old.finish != finish;
}
