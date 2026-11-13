import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _charcoal = BreakPalette(
  canvas: Color(0xFF1C1E22),
  canvasRaised: Color(0xFF26292E),
  surface: Color(0xFF26292E),
  border: Color(0x24FFFFFF),
  track: Color(0x33FFFFFF),
  textPrimary: Color(0xFFF3EDDD),
  textSecondary: Color(0xFFC5BFB0),
  textMuted: Color(0xFF8C8F94),
  isDark: true,
);

const _ivory = Color(0xFFF4EEDC);
const _navy = Color(0xFF1B2A4A);
const _lacquer = Color(0xFFC8452D);

/// Break template: analog dial whose second hand tracks break progress, next to the current wall-clock time.
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
    const palette = _charcoal;
    final accent = breakAccent(widget.settings, 'clock_face', _lacquer);
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final elapsed = (widget.totalSeconds - widget.remainingSeconds).clamp(
      0,
      widget.totalSeconds,
    );
    final preview = BreakPreviewScope.isPreview(context);

    final turn = preview ? 10 / 60 : (elapsed % 60) / 60;
    final now = clock.now();
    final complete = breakIsComplete(
      context,
      widget.remainingSeconds,
      widget.totalSeconds,
    );

    return BreakScaffold(
      palette: palette,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.9,
            colors: [Color(0xFF2B2E34), Color(0xFF141619)],
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 64,
            top: 120,
            child: Semantics(
              label: 'Current time',
              excludeSemantics: true,
              child: Text(
                DateFormat('HH:mm').format(now),
                style: BreakOverlayTheme.title.copyWith(
                  fontFamily: BreakOverlayTheme.monoFamily,
                  fontWeight: FontWeight.w400,
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - _size / 2,
            top: 410 - _size / 2,
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
                              painter: _DialPainter(
                                arc: arc,
                                seconds: marker,
                                accent: accent,
                                time: now,
                              ),
                            ),
                          ),
                          Positioned(
                            top: _size / 2 + 78,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _navy,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 6,
                                ),
                                child: BreakCountdown(
                                  seconds: widget.remainingSeconds,
                                  style: BreakOverlayTheme.display.copyWith(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 0,
                                  ),
                                  color: breakClockColor(
                                    widget.settings,
                                    palette,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: _size / 2 - 142,
                            child: Text(
                              _kind.label.toUpperCase(),
                              style: BreakOverlayTheme.micro.copyWith(
                                color: _navy,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _size = 640;
}

class _DialPainter extends CustomPainter {
  final Animation<double> arc;
  final Animation<double> seconds;
  final Color accent;
  final DateTime time;

  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _fill = Paint();

  _DialPainter({
    required this.arc,
    required this.seconds,
    required this.accent,
    required this.time,
  }) : super(repaint: Listenable.merge([arc, seconds]));

  static const _numerals = TextStyle(
    fontFamily: BreakOverlayTheme.serifFamily,
    fontSize: 38,
    fontWeight: FontWeight.w500,
    color: _navy,
  );

  static Offset _at(Offset c, double r, double a) =>
      c + Offset(math.cos(a), math.sin(a)) * r;

  void _hand(Canvas canvas, Offset c, double a, double len, double w) {
    _stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt
      ..color = _navy;
    canvas.drawLine(_at(c, -22, a), _at(c, len, a), _stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 300.0;

    _fill.color = const Color(0xFF8E8F91);
    canvas.drawCircle(c, r + 14, _fill);
    _fill.color = const Color(0xFF3A3D43);
    canvas.drawCircle(c, r + 8, _fill);
    _fill.color = _ivory;
    canvas.drawCircle(c, r, _fill);

    _stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt
      ..color = _navy.withValues(alpha: 0.35);
    canvas.drawCircle(c, r - 24, _stroke);

    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      final hour = i % 5 == 0;
      _stroke
        ..strokeWidth = hour ? 3 : 1.2
        ..color = _navy;
      canvas.drawLine(
        _at(c, r - (hour ? 22 : 14), a),
        _at(c, r - 4, a),
        _stroke,
      );
    }

    for (var h = 1; h <= 12; h++) {
      final a = h * math.pi / 6 - math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(text: '$h', style: _numerals),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, _at(c, r - 62, a) - Offset(tp.width / 2, tp.height / 2));
    }

    final p = arc.value.clamp(0.0, 1.0);
    if (p > 0) {
      _stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = accent;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 33),
        -math.pi / 2,
        math.pi * 2 * p,
        false,
        _stroke,
      );
    }

    final minutes = time.minute + time.second / 60;
    _hand(
      canvas,
      c,
      ((time.hour % 12) + minutes / 60) * math.pi / 6 - math.pi / 2,
      r * 0.42,
      9,
    );
    _hand(canvas, c, minutes * math.pi / 30 - math.pi / 2, r * 0.66, 6);

    final s = seconds.value * 2 * math.pi - math.pi / 2;
    _stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.butt
      ..color = accent;
    canvas.drawLine(_at(c, -40, s), _at(c, r - 10, s), _stroke);
    _fill.color = accent;
    canvas.drawCircle(c, 9, _fill);
    _fill.color = _ivory;
    canvas.drawCircle(c, 3, _fill);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.accent != accent || old.time != time;
}
