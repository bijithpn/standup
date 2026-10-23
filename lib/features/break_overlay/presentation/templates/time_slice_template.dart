import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class TimeSliceTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const TimeSliceTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  /// One segment per 5 seconds of break, at least 1 and at most 24.
  static int segmentCountFor(int totalSeconds) =>
      (totalSeconds / 5).ceil().clamp(1, 24);

  @override
  State<TimeSliceTemplate> createState() => _TimeSliceTemplateState();
}

class _TimeSliceTemplateState extends State<TimeSliceTemplate>
    with SingleTickerProviderStateMixin {
  /// 260ms pop for the segment that just elapsed.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  int get _segments => TimeSliceTemplate.segmentCountFor(widget.totalSeconds);

  int _elapsedSegments(TimeSliceTemplate w) {
    final m = TimeSliceTemplate.segmentCountFor(w.totalSeconds);
    if (w.totalSeconds <= 0) return 0;
    final elapsed = (w.totalSeconds - w.remainingSeconds).clamp(
      0,
      w.totalSeconds,
    );
    return (elapsed * m ~/ w.totalSeconds).clamp(0, m);
  }

  @override
  void didUpdateWidget(covariant TimeSliceTemplate old) {
    super.didUpdateWidget(old);
    if (_elapsedSegments(widget) > _elapsedSegments(old) &&
        !BreakPreviewScope.isPreview(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      breakAccent(widget.settings, 'time_slice', BreakOverlayTheme.sage),
    );
    final elapsed = _elapsedSegments(widget);
    final reduced = BreakMotion.reduced(context);

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      child: Stack(
        children: [
          Positioned(
            left: 640 - 130,
            top: 400 - 130,
            child: BreakEntrance(
              child: Semantics(
                container: true,
                label:
                    '${_segments - elapsed} of $_segments segments remaining',
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _SlicePainter(
                            pop: _pop,
                            segments: _segments,
                            elapsed: elapsed,
                            accent: accent,
                            track: palette.track,
                            popScale: !reduced,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BreakCountdown(
                            seconds: widget.remainingSeconds,
                            color: breakClockColor(widget.settings, palette),
                          ),
                          const SizedBox(height: 12),
                          BreakLabel(_kind.label),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.settings.showExercisesInBreak &&
              widget.breakInfo.tip.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Center(
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(2),
                  scale: false,
                  child: BreakTip(widget.breakInfo.tip),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlicePainter extends CustomPainter {
  final Animation<double> pop;
  final int segments;
  final int elapsed;
  final Color accent;
  final Color track;
  final bool popScale;

  static const double _band = 14;
  static const double _gapDeg = 3;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  _SlicePainter({
    required this.pop,
    required this.segments,
    required this.elapsed,
    required this.accent,
    required this.track,
    required this.popScale,
  }) : super(repaint: pop);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - _band / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final span = 2 * math.pi / segments;
    // Round caps overhang by half the band on each side; keep the visual gap.
    final capRad = (_band / 2) / r;
    final gap = _gapDeg * math.pi / 180 + 2 * capRad;
    final sweep = math.max(span - gap, 0.02);

    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + span * i + gap / 2;
      final isElapsed = i < elapsed;
      final justElapsed = i == elapsed - 1;
      var color = isElapsed ? track : accent;
      var width = _band;

      if (justElapsed && pop.value < 1) {
        final t = pop.value;
        color = Color.lerp(accent, track, t)!;
        if (popScale) {
          // 1.0 -> 1.08 -> 0.85
          final s = t < 0.5
              ? 1.0 + 0.08 * (t / 0.5)
              : 1.08 - 0.23 * ((t - 0.5) / 0.5);
          width = _band * s;
        }
      }
      _paint
        ..strokeWidth = width
        ..color = color;
      canvas.drawArc(rect, start, sweep, false, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SlicePainter old) =>
      old.segments != segments ||
      old.elapsed != elapsed ||
      old.accent != accent ||
      old.track != track ||
      old.popScale != popScale;
}
