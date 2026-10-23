import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

/// "I looked away" confirmation for eye-rest breaks. One tap, then it rests as
/// a quiet acknowledgement.
class LookedAwayButton extends StatelessWidget {
  final bool confirmed;
  final VoidCallback onPressed;

  const LookedAwayButton({
    super.key,
    required this.confirmed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    final accent = palette.accentOn(BreakOverlayTheme.eyeRest);
    final label = confirmed ? 'Looked away' : 'I looked away';
    return Semantics(
      button: true,
      enabled: !confirmed,
      label: confirmed ? 'Looked away, confirmed' : 'Confirm you looked away',
      excludeSemantics: true,
      onTap: confirmed ? null : onPressed,
      child: MouseRegion(
        cursor: confirmed ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: confirmed ? null : onPressed,
          child: AnimatedContainer(
            duration: BreakMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: confirmed ? 0.06 : 0.14),
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
              border: Border.all(
                color: accent.withValues(alpha: confirmed ? 0.2 : 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  confirmed ? CupertinoIcons.checkmark_alt : CupertinoIcons.eye,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: BreakOverlayTheme.micro.copyWith(
                    color: palette.textPrimary,
                    letterSpacing: 0.3,
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
