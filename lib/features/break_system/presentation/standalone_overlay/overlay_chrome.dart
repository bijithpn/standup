import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/looked_away_button.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class OverlayChrome extends StatelessWidget {
  final Widget child;
  final bool templateOwnsChrome;
  final bool isInternalPreview;
  final bool canDismiss;
  final BreakModel breakInfo;
  final String? exerciseTitle;
  final String intensityLevel;
  final VoidCallback onSkip;

  /// Eye-rest "I looked away" button: shown when [onLookedAway] is set.
  final bool lookedAway;
  final VoidCallback? onLookedAway;

  const OverlayChrome({
    super.key,
    required this.child,
    required this.templateOwnsChrome,
    required this.isInternalPreview,
    required this.canDismiss,
    required this.breakInfo,
    this.exerciseTitle,
    required this.intensityLevel,
    required this.onSkip,
    this.lookedAway = false,
    this.onLookedAway,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BreakPalette.of(context);
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        child,
        if (!templateOwnsChrome)
          Positioned(
            top: 28,
            left: 28,
            child: SafeArea(
              child: BreakContextPill(
                breakInfo: breakInfo,
                exerciseTitle: exerciseTitle,
              ),
            ),
          ),
        if (onLookedAway != null && !templateOwnsChrome)
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            child: Center(
              child: SafeArea(
                child: LookedAwayButton(
                  confirmed: lookedAway,
                  onPressed: onLookedAway!,
                ),
              ),
            ),
          ),
        if (isInternalPreview)
          Positioned(
            top: 32,
            left: 0,
            right: 0,
            child: Center(
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.eye_fill,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'PREVIEW MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (canDismiss)
          Positioned(
            top: 28,
            right: 28,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Skip break',
                onPressed: onSkip,
                icon: const Icon(CupertinoIcons.xmark),
                color: palette.textSecondary,
                style: IconButton.styleFrom(
                  backgroundColor: palette.isDark
                      ? Colors.black.withValues(alpha: 0.24)
                      : Colors.white.withValues(alpha: 0.6),
                  fixedSize: const Size.square(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: palette.border),
                  ),
                ),
              ),
            ),
          ),
        if (canDismiss)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: SwipeToDismissHint()),
          ),
        if (!canDismiss)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: StrictModeNote(intensityLevel: intensityLevel),
            ),
          ),
      ],
    );
  }
}
