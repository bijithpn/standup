import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_helpers.dart';

/// The six resting places a floating card may snap to.
const List<Alignment> breakSixAnchors = [
  Alignment.topLeft,
  Alignment.topCenter,
  Alignment.topRight,
  Alignment.bottomLeft,
  Alignment.bottomCenter,
  Alignment.bottomRight,
];

/// A card that rests at an anchor, can be dragged anywhere, and springs to the
/// nearest anchor on release.
///
/// Resting layout is an [Align] with [inset] padding, so the child may change
/// size (hover, expand) and stay glued to its anchor. Dragging and snapping
/// are a translation on top of that, so no layout state changes per frame.
class BreakDraggable extends StatefulWidget {
  final Widget child;
  final Alignment initialAnchor;
  final List<Alignment> anchors;
  final double inset;
  final ValueChanged<bool>? onDragChanged;

  /// Called with the anchor the card settled on after a drag.
  final ValueChanged<Alignment>? onAnchorChanged;

  /// Slide in from the anchor's edge with a fade on first show.
  final bool animateEntrance;

  const BreakDraggable({
    super.key,
    required this.child,
    this.initialAnchor = Alignment.bottomRight,
    this.anchors = breakSixAnchors,
    this.inset = 32,
    this.onDragChanged,
    this.onAnchorChanged,
    this.animateEntrance = true,
  });

  @override
  State<BreakDraggable> createState() => _BreakDraggableState();
}

class _BreakDraggableState extends State<BreakDraggable>
    with TickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey();

  late Alignment _anchor = widget.initialAnchor;
  Offset _offset = Offset.zero; // while dragging
  Offset _snapFrom = Offset.zero; // spring start, relative to the new anchor
  bool _dragging = false;

  /// 1 -> 0 while snapping; unbounded so the spring may overshoot.
  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: BreakMotion.slow,
  );
  bool _entranceStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (!widget.animateEntrance || breakShouldFreeze(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Rect _restRect(Alignment a, Size parent, Size child) {
    final free = Size(
      math.max(0.0, parent.width - child.width - 2 * widget.inset),
      math.max(0.0, parent.height - child.height - 2 * widget.inset),
    );
    final left = widget.inset + free.width * (a.x + 1) / 2;
    final top = widget.inset + free.height * (a.y + 1) / 2;
    return Rect.fromLTWH(left, top, child.width, child.height);
  }

  void _onPanStart(DragStartDetails d) {
    _spring.stop();
    // Continue from wherever the card is right now.
    _offset = _snapFrom * _spring.value;
    setState(() => _dragging = true);
    widget.onDragChanged?.call(true);
  }

  void _onPanUpdate(DragUpdateDetails d, Size parent) {
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final rest = _restRect(_anchor, parent, size);
    var next = _offset + d.delta;
    final topLeft = rest.topLeft + next;
    final clamped = Offset(
      topLeft.dx.clamp(0.0, math.max(0.0, parent.width - size.width)),
      topLeft.dy.clamp(0.0, math.max(0.0, parent.height - size.height)),
    );
    next = clamped - rest.topLeft;
    setState(() => _offset = next);
  }

  void _onPanEnd(DragEndDetails d, Size parent) {
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      setState(() => _dragging = false);
      return;
    }
    final size = box.size;
    final current = _restRect(_anchor, parent, size).shift(_offset);
    var best = _anchor;
    var bestDist = double.infinity;
    for (final a in widget.anchors) {
      final dist =
          (_restRect(a, parent, size).center - current.center).distanceSquared;
      if (dist < bestDist) {
        bestDist = dist;
        best = a;
      }
    }
    final target = _restRect(best, parent, size);
    setState(() {
      _anchor = best;
      _snapFrom = current.topLeft - target.topLeft;
      _offset = Offset.zero;
      _dragging = false;
    });
    widget.onDragChanged?.call(false);
    widget.onAnchorChanged?.call(best);

    if (breakShouldFreeze(context)) {
      _spring.value = 0;
    } else {
      _spring.value = 1;
      _spring.animateWith(SpringSimulation(BreakMotion.spring, 1, 0, 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final parent = Size(c.maxWidth, c.maxHeight);
        return Padding(
          padding: EdgeInsets.all(widget.inset),
          child: Align(
            alignment: _anchor,
            child: AnimatedBuilder(
              animation: Listenable.merge([_spring, _entrance]),
              builder: (context, child) {
                final snap = _dragging ? _offset : _snapFrom * _spring.value;
                final enter = BreakMotion.enter.transform(
                  _entrance.value.clamp(0.0, 1.0),
                );
                // Slide in from the anchor's own edge.
                final slide = Offset(_anchor.x, _anchor.y) * (16 * (1 - enter));
                return Opacity(
                  opacity: enter,
                  child: Transform.translate(
                    offset: snap + slide,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: (d) => _onPanUpdate(d, parent),
                onPanEnd: (d) => _onPanEnd(d, parent),
                child: MouseRegion(
                  cursor: _dragging
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab,
                  child: KeyedSubtree(key: _childKey, child: widget.child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
