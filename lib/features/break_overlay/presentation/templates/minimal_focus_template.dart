import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class MinimalFocusTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const MinimalFocusTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<MinimalFocusTemplate> createState() => _MinimalFocusTemplateState();
}

class _MinimalFocusTemplateState extends State<MinimalFocusTemplate>
    with SingleTickerProviderStateMixin {
  /// Grid alpha breathes 2% -> 4% -> 2% over 8s.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  final _DotGridCache _grid = _DotGridCache();
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion / thumbnails: static grid at 3%.
    breakSyncLoop(_breath, context, reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  String _durationLabel() =>
      '${_kind.label} · ${breakDurationLabel(widget.totalSeconds)}';

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      breakAccent(widget.settings, 'minimal', _kind.accent),
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: CustomPaint(
        painter: _DotGridPainter(
          cache: _grid,
          breath: _breath,
          color: palette.isDark ? Colors.white : const Color(0xFF1C1F24),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 640 - 110,
            top: 250,
            child: BreakEntrance(
              child: BreakCompletionPulse(
                complete: complete,
                child: BreakProgressRing(
                  size: 220,
                  strokeWidth: 3,
                  progress: progress,
                  color: accent,
                  trackColor: palette.track,
                  tickCount: 60,
                  tickLength: 6,
                  tickWidth: 1.5,
                  tickGap: 12,
                  ticksRemainingLit: true,
                  cometDegrees: 40,
                  flash: complete ? 0.5 : 0,
                  child: ExcludeSemantics(
                    child: Icon(_kind.icon, size: 28, color: accent),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 250 + 220 + 28,
            child: Column(
              children: [
                BreakEntrance(
                  delay: BreakEntrance.stagger(1),
                  scale: false,
                  child: BreakCountdown(
                    seconds: widget.remainingSeconds,
                    color: breakClockColor(widget.settings, palette),
                  ),
                ),
                const SizedBox(height: 12),
                BreakEntrance(
                  delay: BreakEntrance.stagger(2),
                  scale: false,
                  child: BreakLabel(_durationLabel()),
                ),
              ],
            ),
          ),
          if (showTip)
            Positioned(
              left: 0,
              right: 0,
              bottom: 72,
              child: Center(
                child: BreakEntrance(
                  delay: BreakEntrance.stagger(3),
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

/// Holds the dot positions for one size so they are built once, not per frame.
class _DotGridCache {
  Size? _size;
  Float32List? _points;

  Float32List pointsFor(Size size) {
    if (_size == size && _points != null) return _points!;
    const pitch = 24.0;
    final rowStep = pitch * 0.866; // isometric
    final out = <double>[];
    var row = 0;
    for (var y = 0.0; y <= size.height; y += rowStep, row++) {
      final dx = row.isOdd ? pitch / 2 : 0.0;
      for (var x = dx; x <= size.width; x += pitch) {
        out
          ..add(x)
          ..add(y);
      }
    }
    _size = size;
    return _points = Float32List.fromList(out);
  }
}

class _DotGridPainter extends CustomPainter {
  final _DotGridCache cache;
  final Animation<double> breath;
  final Color color;

  final Paint _paint = Paint()
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;

  _DotGridPainter({
    required this.cache,
    required this.breath,
    required this.color,
  }) : super(repaint: breath);

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOutSine.transform(breath.value);
    _paint.color = color.withValues(alpha: 0.02 + 0.02 * t);
    canvas.drawRawPoints(ui.PointMode.points, cache.pointsFor(size), _paint);
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) =>
      old.color != color || old.cache != cache;
}
