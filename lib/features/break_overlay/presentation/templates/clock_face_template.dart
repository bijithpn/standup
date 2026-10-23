import 'dart:math' as math;
import 'dart:ui' as ui;
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
  final _DialCache _dial = _DialCache();
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = breakAccent(widget.settings, 'clock_face', _kind.accent);
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final elapsed = (widget.totalSeconds - widget.remainingSeconds).clamp(
      0,
      widget.totalSeconds,
    );
    final preview = BreakPreviewScope.isPreview(context);
    // The hand makes one turn per minute; thumbnails freeze it at 10s.
    final hand = preview ? 10 / 60 : (elapsed % 60) / 60;
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;

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
                DateFormat('HH:mm').format(DateTime.now()),
                style: BreakOverlayTheme.title.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 - 130,
            top: 400 - 130,
            child: BreakEntrance(
              child: BreakCompletionPulse(
                complete: complete,
                child: BreakSmoothProgress(
                  progress: progress,
                  builder: (context, sector) => BreakSmoothProgress(
                    progress: hand,
                    builder: (context, handAnim) => SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RepaintBoundary(
                            child: CustomPaint(
                              size: const Size(260, 260),
                              painter: _ClockPainter(
                                cache: _dial,
                                sector: sector,
                                hand: handAnim,
                                accent: accent,
                                bezelA: palette.surface,
                                bezelB: palette.canvasRaised,
                                face: palette.canvas,
                                tick: palette.textMuted,
                                minorTick: palette.track,
                                highlight: palette.border,
                              ),
                            ),
                          ),
                          // Sits below the hand's pivot so the two never collide.
                          Transform.translate(
                            offset: const Offset(0, 38),
                            child: BreakCountdown(
                              seconds: widget.remainingSeconds,
                              style: BreakOverlayTheme.title,
                              color: breakClockColor(widget.settings, palette),
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
          Positioned(
            top: 400 + 130 + 20,
            left: 0,
            right: 0,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: BreakLabel(_kind.label),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bezel, face and ticks never change; they are recorded once per size and
/// palette.
class _DialCache {
  ui.Picture? picture;
  Object? key;
}

class _ClockPainter extends CustomPainter {
  final _DialCache cache;
  final Animation<double> sector;
  final Animation<double> hand;
  final Color accent;
  final Color bezelA;
  final Color bezelB;
  final Color face;
  final Color tick;
  final Color minorTick;
  final Color highlight;

  final Paint _sector = Paint();
  final Paint _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final Paint _hand = Paint()
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;
  final Paint _cap = Paint();

  _ClockPainter({
    required this.cache,
    required this.sector,
    required this.hand,
    required this.accent,
    required this.bezelA,
    required this.bezelB,
    required this.face,
    required this.tick,
    required this.minorTick,
    required this.highlight,
  }) : super(repaint: Listenable.merge([sector, hand]));

  ui.Picture _record(Size size) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final c = size.center(Offset.zero);

    // Double bezel: outer r130, inner r124, metallic gradient.
    final outer = Rect.fromCircle(center: c, radius: 130);
    canvas.drawCircle(
      c,
      130,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bezelA, bezelB],
        ).createShader(outer),
    );
    canvas.drawCircle(
      c,
      130,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = highlight,
    );
    canvas.drawCircle(c, 124, Paint()..color = face);
    // Inner shadow: darken toward the inside edge of the bezel.
    canvas.drawCircle(
      c,
      124,
      Paint()
        ..shader = RadialGradient(
          stops: const [0.8, 1.0],
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
        ).createShader(Rect.fromCircle(center: c, radius: 124)),
    );

    // 60 minute ticks (4px, 1px) and 12 hour ticks (10px, 2px).
    final t = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final hour = i % 5 == 0;
      final a = i * math.pi / 30 - math.pi / 2;
      final len = hour ? 10.0 : 4.0;
      t
        ..strokeWidth = hour ? 2 : 1
        ..color = hour ? tick : minorTick;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * 116, c.dy + math.sin(a) * 116),
        Offset(
          c.dx + math.cos(a) * (116 - len),
          c.dy + math.sin(a) * (116 - len),
        ),
        t,
      );
    }
    return rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final key = Object.hash(
      size,
      accent,
      bezelA,
      bezelB,
      face,
      tick,
      minorTick,
    );
    if (cache.picture == null || cache.key != key) {
      cache.picture = _record(size);
      cache.key = key;
    }
    canvas.drawPicture(cache.picture!);

    final c = size.center(Offset.zero);
    final p = sector.value.clamp(0.0, 1.0);
    if (p > 0) {
      const r = 106.0;
      final rect = Rect.fromCircle(center: c, radius: r);
      _sector.color = accent.withValues(alpha: 0.25);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * p, true, _sector);
      _edge.color = accent;
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * p, false, _edge);
    }

    // Seconds hand: 1px, 110px long, with a counterweight tail.
    final a = hand.value * 2 * math.pi - math.pi / 2;
    final dir = Offset(math.cos(a), math.sin(a));
    _hand.color = accent;
    canvas.drawLine(c - dir * 18, c + dir * 110, _hand);
    _cap.color = accent;
    canvas.drawCircle(c - dir * 18, 3, _cap);
    canvas.drawCircle(c, 2.5, _cap);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.accent != accent ||
      old.bezelA != bezelA ||
      old.bezelB != bezelB ||
      old.face != face ||
      old.tick != tick ||
      old.minorTick != minorTick;
}
