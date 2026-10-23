import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class SoftArcTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SoftArcTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<SoftArcTemplate> createState() => _SoftArcTemplateState();
}

class _SoftArcTemplateState extends State<SoftArcTemplate>
    with SingleTickerProviderStateMixin {
  static const double _gaugeWidth = 560;

  /// 0 -> 1 over 300ms each second: the current tick brightens briefly.
  late final AnimationController _tickFlash;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazy initializer first touched in dispose() would try
    // to look up the (already deactivated) ticker mode.
    _tickFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
  }

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void didUpdateWidget(covariant SoftArcTemplate old) {
    super.didUpdateWidget(old);
    if (old.remainingSeconds != widget.remainingSeconds &&
        !breakShouldFreeze(context)) {
      _tickFlash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tickFlash.dispose();
    super.dispose();
  }

  String get _readout =>
      '${_kind.label} · ${breakDurationLabel(widget.totalSeconds)}';

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      breakAccent(widget.settings, 'soft_arc', _kind.accent),
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final reduced = BreakMotion.reduced(context);

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      child: Center(
        child: BreakEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(_kind.icon, size: 20, color: accent),
              ),
              const SizedBox(height: 16),
              BreakCountdown(
                seconds: widget.remainingSeconds,
                color: breakClockColor(
                  widget.settings,
                  palette,
                  fallback: accent,
                ),
              ),
              const SizedBox(height: 28),
              BreakSmoothProgress(
                progress: progress,
                builder: (context, anim) => TweenAnimationBuilder<double>(
                  tween: Tween(end: complete ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, glow, _) => RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(_gaugeWidth, 64),
                      painter: _GaugePainter(
                        progress: anim,
                        tickFlash: reduced ? null : _tickFlash,
                        accent: accent,
                        minorTick: palette.track,
                        majorTick: palette.textMuted,
                        glow: glow,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BreakLabel(_readout),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final Animation<double> progress;
  final Animation<double>? tickFlash;
  final Color accent;
  final Color minorTick;
  final Color majorTick;
  final double glow;

  static const int _ticks = 48;
  static const double _inset = 12;
  static const double _trackY = 44;

  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final Paint _dot = Paint();
  final Paint _halo = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Paint _flash = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2;

  ui.Picture? _static;
  Size? _staticSize;

  _GaugePainter({
    required this.progress,
    required this.tickFlash,
    required this.accent,
    required this.minorTick,
    required this.majorTick,
    required this.glow,
  }) : super(repaint: Listenable.merge([progress, ?tickFlash]));

  double _x(Size size, double t) => _inset + (size.width - 2 * _inset) * t;

  /// Ruler: ticks above a track. They never change, so record them once.
  ui.Picture _record(Size size) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);

    _line.color = minorTick;
    canvas.drawLine(
      Offset(_x(size, 0), _trackY),
      Offset(_x(size, 1), _trackY),
      _line,
    );

    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i <= _ticks; i++) {
      final major = i % 6 == 0;
      tick
        ..strokeWidth = major ? 1.6 : 1.0
        ..color = major ? majorTick : minorTick;
      final x = _x(size, i / _ticks);
      canvas.drawLine(
        Offset(x, _trackY - 10 - (major ? 12 : 6)),
        Offset(x, _trackY - 10),
        tick,
      );
    }
    return rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_static == null || _staticSize != size) {
      _static = _record(size);
      _staticSize = size;
    }
    canvas.drawPicture(_static!);

    final p = progress.value.clamp(0.0, 1.0);

    if (p > 0) {
      _line.color = accent;
      canvas.drawLine(
        Offset(_x(size, 0), _trackY),
        Offset(_x(size, p), _trackY),
        _line,
      );
    }

    // Brighten the tick for the second that just completed.
    final f = tickFlash;
    if (f != null && f.value < 1) {
      final i = (p * _ticks).floor().clamp(0, _ticks);
      final major = i % 6 == 0;
      final x = _x(size, i / _ticks);
      _flash.color = accent.withValues(alpha: 1 - f.value);
      canvas.drawLine(
        Offset(x, _trackY - 10 - (major ? 12 : 6)),
        Offset(x, _trackY - 10),
        _flash,
      );
    }

    // Needle dot at the head, with a halo that peaks on completion.
    final head = Offset(_x(size, p), _trackY);
    _halo.color = accent.withValues(alpha: 0.35 + 0.45 * glow);
    canvas.drawCircle(head, 8 + 4 * glow, _halo);
    _dot.color = accent;
    canvas.drawCircle(head, 4, _dot);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.accent != accent ||
      old.minorTick != minorTick ||
      old.majorTick != majorTick ||
      old.glow != glow;
}
