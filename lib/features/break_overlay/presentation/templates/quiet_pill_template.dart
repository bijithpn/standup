import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class QuietPillTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const QuietPillTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<QuietPillTemplate> createState() => _QuietPillTemplateState();
}

class _QuietPillTemplateState extends State<QuietPillTemplate>
    with TickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;
  bool _pinned = false; // Enter toggles this for keyboard users

  bool get _expanded => _hover || _focus || _pinned;

  /// 0 = collapsed (200x36), 1 = expanded (320x56). Unbounded so the spring
  /// can overshoot a touch.
  late final AnimationController _size = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  /// Liquid ripple phase, continuous.
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  Color get _accent => BreakPalette.of(context).accentOn(
    BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'quiet_pill',
      _kind.accent,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_ripple, context, park: 0.0);
  }

  @override
  void dispose() {
    _size.dispose();
    _ripple.dispose();
    super.dispose();
  }

  void _syncSize() {
    final target = _expanded ? 1.0 : 0.0;
    if (breakShouldFreeze(context)) {
      _size.value = target;
      return;
    }
    _size.animateWith(
      SpringSimulation(BreakMotion.spring, _size.value, target, _size.velocity),
    );
  }

  void _setHover(bool v) {
    setState(() => _hover = v);
    _syncSize();
  }

  void _setFocus(bool v) {
    setState(() => _focus = v);
    _syncSize();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final progress = breakProgress(
      widget.remainingSeconds,
      widget.totalSeconds,
    );
    final canSkip = breakCanSkip(widget.settings, widget.onSkip);
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;
    final reduced = BreakMotion.reduced(context);

    final pill = AnimatedBuilder(
      animation: _size,
      builder: (context, _) {
        final t = _size.value;
        final w = 200 + 120 * t;
        final h = 36 + 20 * t;
        final actionsOpacity = _expanded ? 1.0 : 0.0;
        return BreakGlass(
          radius: BreakOverlayTheme.radiusPill,
          fillAlpha: 0.85,
          borderAlpha: 0,
          blur: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Liquid fill: elapsed share, wavy leading edge.
                  BreakSmoothProgress(
                    progress: progress,
                    builder: (context, anim) => RepaintBoundary(
                      child: CustomPaint(
                        painter: _LiquidPainter(
                          progress: anim,
                          ripple: _ripple,
                          color: _accent.withValues(alpha: 0.35),
                          still: reduced,
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        BreakOverlayTheme.radiusPill,
                      ),
                      border: Border.all(color: palette.border),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12 + 2 * t),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        BreakCountdown(
                          seconds: widget.remainingSeconds,
                          style: BreakOverlayTheme.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: BreakOverlayTheme.tabular,
                            height: 1.0,
                          ),
                          color: breakClockColor(widget.settings, palette),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _kind.label.toUpperCase(),
                          maxLines: 1,
                          softWrap: false,
                          style: BreakOverlayTheme.micro.copyWith(
                            color: palette.textMuted,
                            height: 1.0,
                          ),
                        ),
                        const Spacer(),
                        if (t > 0.6 && canSkip)
                          _Staggered(
                            visible: actionsOpacity > 0,
                            index: 0,
                            child: BreakSkipIcon(
                              onPressed: widget.onSkip!,
                              accent: _accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return BreakScaffold(
      canvas: Colors.transparent,
      scrim: palette.canvas.withValues(alpha: 0.20),
      scaled: false,
      showSkip: false,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      child: BreakDraggable(
        initialAnchor: Alignment.bottomCenter,
        inset: 40,
        child: Semantics(
          container: true,
          label: 'Break timer, ${widget.remainingSeconds} seconds remaining',
          child: MouseRegion(
            onEnter: (_) => _setHover(true),
            onExit: (_) => _setHover(false),
            child: FocusableActionDetector(
              onShowFocusHighlight: _setFocus,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    setState(() => _pinned = !_pinned);
                    _syncSize();
                    return null;
                  },
                ),
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The tip lives in a bubble above the pill while expanded.
                  AnimatedSize(
                    duration: BreakMotion.fast,
                    curve: BreakMotion.enter,
                    alignment: Alignment.bottomCenter,
                    child: _expanded && showTip
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: BreakGlass(
                                radius: BreakOverlayTheme.radiusMd,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Text(
                                  widget.breakInfo.tip,
                                  textAlign: TextAlign.center,
                                  style: BreakOverlayTheme.body.copyWith(
                                    color: palette.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(width: 0, height: 0),
                  ),
                  pill,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades a child in over [BreakMotion.fast], offset by 40ms per [index].
class _Staggered extends StatelessWidget {
  final bool visible;
  final int index;
  final Widget child;

  const _Staggered({
    required this.visible,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1.0 : 0.0),
      duration: BreakMotion.fast + Duration(milliseconds: 40 * index),
      curve: Interval(
        (40.0 * index) / (160 + 40.0 * index),
        1.0,
        curve: Curves.easeOut,
      ),
      builder: (context, v, c) => Opacity(opacity: v, child: c),
      child: child,
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final Animation<double> progress;
  final Animation<double> ripple;
  final Color color;
  final bool still;

  final Paint _paint = Paint();
  final Path _path = Path();

  _LiquidPainter({
    required this.progress,
    required this.ripple,
    required this.color,
    required this.still,
  }) : super(repaint: Listenable.merge([progress, ripple]));

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value.clamp(0.0, 1.0);
    if (p <= 0) return;
    final edge = size.width * p;
    final phase = still ? 0.0 : ripple.value * 2 * math.pi;
    _paint.color = color;

    // Leading edge: 2px-amplitude sine with a 6px wavelength.
    _path
      ..reset()
      ..moveTo(0, 0)
      ..lineTo(edge, 0);
    for (var y = 0.0; y <= size.height; y += 1.5) {
      _path.lineTo(edge + 2 * math.sin(y / 6 * 2 * math.pi + phase), y);
    }
    _path
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(_path, _paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter old) =>
      old.color != color || old.still != still;
}
