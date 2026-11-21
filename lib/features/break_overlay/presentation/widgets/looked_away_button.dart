import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

/// Button where the user confirms they looked away from the screen; disabled once confirmed.
class LookedAwayButton extends StatefulWidget {
  final bool confirmed;
  final VoidCallback onPressed;

  const LookedAwayButton({
    super.key,
    required this.confirmed,
    required this.onPressed,
  });

  @override
  State<LookedAwayButton> createState() => _LookedAwayButtonState();
}

class _LookedAwayButtonState extends State<LookedAwayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(BreakOverlayTheme.eyeRest);
    final confirmed = widget.confirmed;
    return Semantics(
      button: true,
      enabled: !confirmed,
      label: confirmed ? 'Looked away, confirmed' : 'Confirm you looked away',
      excludeSemantics: true,
      onTap: confirmed ? null : widget.onPressed,
      child: FocusableActionDetector(
        enabled: !confirmed,
        mouseCursor: confirmed ? MouseCursor.defer : SystemMouseCursors.click,
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
          onTap: confirmed ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: BreakMotion.reduced(context)
                ? Duration.zero
                : BreakMotion.fast,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusSm),
              border: Border.all(
                color: _focused ? accent : palette.border,
                width: _focused ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  confirmed ? CupertinoIcons.checkmark_alt : CupertinoIcons.eye,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  confirmed ? 'Looked away' : 'I looked away',
                  style: BreakOverlayTheme.micro.copyWith(
                    color: palette.textPrimary,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
