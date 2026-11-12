import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class ClockFaceTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ClockFaceTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ClockFaceTemplate> createState() => _ClockFaceTemplateState();
}

class _ClockFaceTemplateState extends State<ClockFaceTemplate> {
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      breakAccent(widget.settings, 'clock_face', _kind.accent),
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final elapsed = (widget.totalSeconds - widget.remainingSeconds).clamp(
      0,
      widget.totalSeconds,
    );
    final preview = BreakPreviewScope.isPreview(context);
    // The marker makes one turn per minute; thumbnails freeze it at 10s.
    final turn = preview ? 10 / 60 : (elapsed % 60) / 60;
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
          // Below the overlay chrome (context pill / dismiss) at the top.
          Positioned(
            left: 64,
            top: 120,
            child: Semantics(
              label: 'Current time',
              excludeSemantics: true,
              child: Text(
                DateFormat('HH:mm').format(clock.now()),
                style: BreakOverlayTheme.title.copyWith(
                  fontWeight: FontWeight.w300,
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - _size / 2,
            top: 390 - _size / 2,
            child: BreakEntrance(
              child: BreakCompletionPulse(
                complete: complete,
                child: BreakSmoothProgress(
                  progress: progress,
                  builder: (context, arc) => BreakSmoothProgress(
                    progress: turn,
                    builder: (context, marker) => SizedBox(
                      width: _size,
                      height: _size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(_size, _size),
                              painter: _ClockPainter(
                                arc: arc,
                                marker: marker,
                                accent: accent,
                                tick: palette.textMuted,
                                dial: palette.border,
                              ),
                            ),
                          ),
                          BreakCountdown(
                            seconds: widget.remainingSeconds,
                            style: BreakOverlayTheme.display.copyWith(
                              fontSize: 56,
                              fontWeight: FontWeight.w200,
                            ),
                            color: breakClockColor(widget.settings, palette),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 390 + _size / 2 + 28,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Text(
                _kind.label,
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

  static const double _size = 320;
}

class _ClockPainter extends CustomPainter {
  final Animation<double> arc;
  final Animation<double> marker;
  final Color accent;
  final Color tick;
  final Color dial;

  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _fill = Paint();

  _ClockPainter({
    required this.arc,
    required this.marker,
    required this.accent,
    required this.tick,
    required this.dial,
  }) : super(repaint: Listenable.merge([arc, marker]));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 150.0;

    _stroke
      ..strokeWidth = 1
      ..color = dial;
    canvas.drawCircle(c, r, _stroke);

    _stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = tick;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r - 14), c + dir * (r - 6), _stroke);
    }

    final p = arc.value.clamp(0.0, 1.0);
    if (p > 0) {
      _stroke
        ..strokeWidth = 2
        ..color = accent;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 28),
        -math.pi / 2,
        math.pi * 2 * p,
        false,
        _stroke,
      );
    }

    final a = marker.value * 2 * math.pi - math.pi / 2;
    _fill.color = accent;
    canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, 4, _fill);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.accent != accent || old.tick != tick || old.dial != dial;
}
