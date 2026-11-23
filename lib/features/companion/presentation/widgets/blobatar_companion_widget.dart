import 'dart:async';
import 'package:flutter/material.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/domain/blobatar_emotion_mapper.dart';

/// Blobatar companion with a tap bounce and a short temporary expression override.
class BlobatarCompanionWidget extends StatefulWidget {
  final String name;
  final double size;
  final Expression? expression;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool isInteractive;
  final BlobatarAnimate animate;

  const BlobatarCompanionWidget({
    super.key,
    required this.name,
    this.size = 140.0,
    this.expression,
    this.onTap,
    this.onDoubleTap,
    this.isInteractive = true,
    this.animate = BlobatarAnimate.always,
  });

  @override
  State<BlobatarCompanionWidget> createState() =>
      _BlobatarCompanionWidgetState();
}

class _BlobatarCompanionWidgetState extends State<BlobatarCompanionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  Timer? _reactionTimer;
  Expression? _overrideExpression;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0),
        weight: 50,
      ),
    ]).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_bounceController);
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isInteractive) return;

    _reactionTimer?.cancel();
    setState(() {
      _overrideExpression = loveExpression;
    });

    _bounceController.forward(from: 0.0);

    widget.onTap?.call();

    _reactionTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _overrideExpression = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName = BlobatarEmotionMapper.sanitizePetName(widget.name);
    final effectiveExpression =
        _overrideExpression ?? widget.expression ?? happyExpression;

    final child = ScaleTransition(
      scale: _scaleAnimation,
      child: Center(
        child: Blobatar(
          key: ValueKey<String>(effectiveName),
          name: effectiveName,
          size: widget.size,
          animate: widget.animate,
          expression: effectiveExpression,
        ),
      ),
    );

    if (!widget.isInteractive) {
      return child;
    }

    return Semantics(
      button: true,
      label: 'Pet $effectiveName',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onDoubleTap: widget.onDoubleTap,
          child: child,
        ),
      ),
    );
  }
}
