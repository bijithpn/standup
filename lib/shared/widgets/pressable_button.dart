import 'package:flutter/material.dart';

class PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double scaleFactor;
  final double translateOffset;

  const PressableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleFactor = 0.96,
    this.translateOffset = 2.0,
  });

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(_) => _controller.forward();
  void _handleTapUp(_) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 1.0,
          end: widget.scaleFactor,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
        child: Transform.translate(
          offset: Offset(0, _controller.value * widget.translateOffset),
          child: widget.child,
        ),
      ),
    );
  }
}
