import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

/// 32px circular skip control for compact surfaces (floating card, pill).
class BreakSkipIcon extends StatefulWidget {
  final VoidCallback onPressed;
  final Color accent;

  const BreakSkipIcon({
    super.key,
    required this.onPressed,
    required this.accent,
  });

  @override
  State<BreakSkipIcon> createState() => _BreakSkipIconState();
}

class _BreakSkipIconState extends State<BreakSkipIcon> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    return Semantics(
      button: true,
      label: 'Skip break',
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: BreakMotion.fast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.isDark
                  ? Colors.white.withValues(alpha: _hovered ? 0.14 : 0.07)
                  : Colors.black.withValues(alpha: _hovered ? 0.1 : 0.05),
              border: _focused
                  ? Border.all(color: widget.accent, width: 2)
                  : null,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
