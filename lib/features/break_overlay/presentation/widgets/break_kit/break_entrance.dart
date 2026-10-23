import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

/// One-shot entrance: opacity 0->1 and scale 0.96->1 over [BreakMotion.slow]
/// after [delay] (use 60ms steps to stagger text). Reduced motion becomes an
/// opacity-only fade over [BreakMotion.medium]; gallery thumbnails render the
/// final state immediately.
class BreakEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool scale;

  /// Length of the fade/scale itself; defaults to [BreakMotion.slow].
  final Duration? duration;

  const BreakEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.scale = true,
    this.duration,
  });

  /// Stagger helper: the n-th text element enters n * 60ms after the focal one.
  static Duration stagger(int index) => Duration(milliseconds: 60 * index);

  @override
  State<BreakEntrance> createState() => _BreakEntranceState();
}

class _BreakEntranceState extends State<BreakEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (BreakPreviewScope.isPreview(context)) return;

    final reduced = BreakMotion.reduced(context);
    final delay = reduced ? Duration.zero : widget.delay;
    final run = reduced
        ? BreakMotion.medium
        : (widget.duration ?? BreakMotion.slow);
    final total = delay + run;
    final c = AnimationController(vsync: this, duration: total);
    final curve = CurvedAnimation(
      parent: c,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1.0,
        curve: BreakMotion.enter,
      ),
    );
    _opacity = curve;
    _scale = Tween<double>(
      begin: reduced || !widget.scale ? 1.0 : 0.96,
      end: 1.0,
    ).animate(curve);
    _controller = c..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Plays the completion moment once when [complete] turns true: the child
/// pulses 1.0 -> [peak] -> 1.0 over 400ms (an opacity flash under reduced
/// motion). Does not close the overlay; that stays with the break controller.
class BreakCompletionPulse extends StatefulWidget {
  final bool complete;
  final Widget child;
  final double peak;

  const BreakCompletionPulse({
    super.key,
    required this.complete,
    required this.child,
    this.peak = 1.04,
  });

  @override
  State<BreakCompletionPulse> createState() => _BreakCompletionPulseState();
}

class _BreakCompletionPulseState extends State<BreakCompletionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(covariant BreakCompletionPulse old) {
    super.didUpdateWidget(old);
    if (widget.complete && !old.complete) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = BreakMotion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(
          _c.value < 0.5 ? _c.value * 2 : (1 - _c.value) * 2,
        );
        if (reduced) {
          return Opacity(opacity: 1.0 - 0.4 * t, child: child);
        }
        return Transform.scale(
          scale: 1.0 + (widget.peak - 1.0) * t,
          child: child,
        );
      },
    );
  }
}
