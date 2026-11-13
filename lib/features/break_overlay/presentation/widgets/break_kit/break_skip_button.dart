import 'package:flutter/material.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

/// Accessible pill-shaped Skip button with hover and focus states.
class BreakSkipButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color? accent;
  final String label;

  const BreakSkipButton({
    super.key,
    required this.onPressed,
    this.accent,
    this.label = 'Skip',
  });

  @override
  State<BreakSkipButton> createState() => _BreakSkipButtonState();
}

class _BreakSkipButtonState extends State<BreakSkipButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final ring = widget.accent ?? BreakOverlayTheme.eyeRest;
    return Semantics(
      container: true,
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
            duration: BreakMotion.reduced(context)
                ? Duration.zero
                : BreakMotion.fast,
            constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: palette.surface.withValues(alpha: _hovered ? 1 : 0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: _focused
                    ? BorderSide(color: ring, width: 2)
                    : BorderSide(color: palette.border),
              ),
            ),
            child: AnimatedOpacity(
              duration: BreakMotion.reduced(context)
                  ? Duration.zero
                  : BreakMotion.fast,
              opacity: _hovered || _focused ? 1.0 : 0.82,
              child: Text(
                widget.label,
                style: BreakOverlayTheme.body.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
