import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class ProductivityHudTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ProductivityHudTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ProductivityHudTemplate> createState() =>
      _ProductivityHudTemplateState();
}

class _ProductivityHudTemplateState extends State<ProductivityHudTemplate>
    with SingleTickerProviderStateMixin {
  static const TextStyle _mono = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: ['SF Mono', 'Consolas', 'Courier New', 'monospace'],
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Head glow pulses between 40% and 60% alpha over 2s.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_pulse, context, reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(
      BreakOverlayTheme.resolveAccent(
        widget.settings.templateAccentOverrides,
        'hud',
        _kind.accent,
      ),
    );
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final pct = (progress * 100).round();
    final complete = widget.remainingSeconds <= 0 && widget.totalSeconds > 0;
    final canSkip = breakCanSkip(widget.settings, widget.onSkip);
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;
    final telemetry = _mono.copyWith(color: palette.textSecondary);

    return BreakScaffold(
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: accent,
      background: CustomPaint(painter: _ReticlePainter(color: palette.track)),
      child: Stack(
        children: [
          Positioned(
            left: 160,
            top: 260,
            child: BreakEntrance(
              scale: false,
              child: BreakCountdown(
                seconds: widget.remainingSeconds,
                style: BreakOverlayTheme.hero,
                textAlign: TextAlign.left,
                color: breakClockColor(widget.settings, palette),
              ),
            ),
          ),
          Positioned(
            left: 160,
            top: 420,
            width: 960,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(1),
              scale: false,
              child: Semantics(
                label: '${_kind.label} progress',
                value: '$pct%',
                child: BreakSmoothProgress(
                  progress: progress,
                  builder: (context, anim) => TweenAnimationBuilder<double>(
                    tween: Tween(end: complete ? 1.0 : 0.0),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, flash, _) => RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(960, 40),
                        painter: _BarPainter(
                          progress: anim,
                          pulse: _pulse,
                          accent: accent,
                          track: palette.track,
                          flash: flash,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 160,
            top: 420 + 4 + 24,
            width: 960,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(2),
              scale: false,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MODE  ${_kind.label.toUpperCase()}',
                      style: telemetry,
                    ),
                    Text('ELAPSED  $pct%', style: telemetry),
                    Text(
                      'LEFT  ${breakFormatTime(widget.remainingSeconds)}',
                      style: telemetry,
                    ),
                    Text(
                      'TOTAL  ${breakDurationLabel(widget.totalSeconds)}',
                      style: telemetry,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 160,
              top: 420 + 4 + 24 + 56,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(3),
                scale: false,
                child: BreakTip(
                  widget.breakInfo.tip,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          if (canSkip)
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Center(
                child: Text(
                  'Press Esc to dismiss',
                  style: BreakOverlayTheme.micro.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 16px L-brackets in each corner, inset 32.
class _ReticlePainter extends CustomPainter {
  final Color color;

  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;
    const inset = 32.0;
    const len = 16.0;
    final l = inset, t = inset, r = size.width - inset, b = size.height - inset;
    final path = Path()
      ..moveTo(l, t + len)
      ..lineTo(l, t)
      ..lineTo(l + len, t)
      ..moveTo(r - len, t)
      ..lineTo(r, t)
      ..lineTo(r, t + len)
      ..moveTo(l, b - len)
      ..lineTo(l, b)
      ..lineTo(l + len, b)
      ..moveTo(r - len, b)
      ..lineTo(r, b)
      ..lineTo(r, b - len);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) => old.color != color;
}

class _BarPainter extends CustomPainter {
  final Animation<double> progress;
  final Animation<double> pulse;
  final Color accent;
  final Color track;
  final double flash;

  final Paint _track = Paint();
  final Paint _fill = Paint();
  final Paint _tick = Paint()..strokeWidth = 1;
  final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  _BarPainter({
    required this.progress,
    required this.pulse,
    required this.accent,
    required this.track,
    required this.flash,
  }) : super(repaint: Listenable.merge([progress, pulse]));

  @override
  void paint(Canvas canvas, Size size) {
    const h = 4.0;
    final p = progress.value.clamp(0.0, 1.0);
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, h),
      const Radius.circular(2),
    );
    _track.color = track;
    canvas.drawRRect(bar, _track);

    final w = size.width * p;
    if (w > 0) {
      _fill.color = Color.lerp(accent, Colors.white, 0.35 * flash)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h),
          const Radius.circular(2),
        ),
        _fill,
      );
      // Head glow: 12px at 40-60% accent.
      final a = (0.4 + 0.2 * pulse.value + 0.4 * flash).clamp(0.0, 1.0);
      _glow.color = accent.withValues(alpha: a);
      canvas.drawCircle(Offset(w, h / 2), 6 + 2 * flash, _glow);
    }

    // Ticks every 10% (1px wide, 6px tall), just under the bar.
    _tick.color = track;
    for (var i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, h + 4), Offset(x, h + 10), _tick);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.accent != accent || old.track != track || old.flash != flash;
}
