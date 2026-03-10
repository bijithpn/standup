import 'package:flutter/material.dart';

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isDestructive = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDestructive
        ? const Color(0xFFEF4444)
        : const Color(0xFF4A90D9);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering ? baseColor : baseColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: baseColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _hovering ? Colors.white : baseColor,
            ),
          ),
        ),
      ),
    );
  }
}
