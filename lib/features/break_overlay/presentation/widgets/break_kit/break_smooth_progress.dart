import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';

/// Turns per-second progress updates into a smooth 0..1 [Animation] for
/// painters, without rebuilding anything per frame.
class BreakSmoothProgress extends StatefulWidget {
  final double progress;
  final Widget Function(BuildContext context, Animation<double> progress)
  builder;

  const BreakSmoothProgress({
    super.key,
    required this.progress,
    required this.builder,
  });

  @override
  State<BreakSmoothProgress> createState() => _BreakSmoothProgressState();
}

class _BreakSmoothProgressState extends State<BreakSmoothProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: widget.progress.clamp(0.0, 1.0),
  );

  @override
  void didUpdateWidget(covariant BreakSmoothProgress old) {
    super.didUpdateWidget(old);
    final target = widget.progress.clamp(0.0, 1.0);
    if (target == _c.value) return;
    if (target > _c.value && !breakShouldFreeze(context)) {
      _c.animateTo(
        target,
        duration: const Duration(seconds: 1),
        curve: Curves.linear,
      );
    } else {
      _c.value = target;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}
