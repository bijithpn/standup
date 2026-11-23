import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_skip_button.dart';

/// Shared frame around a break template: context pill, preview label, skip button, and strict-mode note.
class OverlayChrome extends StatelessWidget {
  final Widget child;
  final bool templateOwnsChrome;
  final bool compactControls;
  final bool isInternalPreview;
  final bool canDismiss;
  final BreakModel breakInfo;
  final String? exerciseTitle;
  final String intensityLevel;
  final VoidCallback onSkip;

  const OverlayChrome({
    super.key,
    required this.child,
    required this.templateOwnsChrome,
    this.compactControls = false,
    required this.isInternalPreview,
    required this.canDismiss,
    required this.breakInfo,
    this.exerciseTitle,
    required this.intensityLevel,
    required this.onSkip,
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
            top: 32,
            left: 32,
            child: SafeArea(
              child: BreakContextPill(
                breakInfo: breakInfo,
                exerciseTitle: exerciseTitle,
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
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(
                      BreakOverlayTheme.radiusSm,
                    ),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Preview',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: BreakOverlayTheme.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (canDismiss && !compactControls)
          Positioned(
            bottom: BreakOverlayTheme.skipBottom,
            right: BreakOverlayTheme.skipRight,
            child: BreakSkipButton(onPressed: onSkip),
          ),
        if (!canDismiss && !compactControls)
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
