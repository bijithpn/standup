import 'package:flutter/material.dart';
import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/looked_away_button.dart';
import 'package:breakmate/features/break_overlay/wellness/wellness_overlay_view.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/accessible_break_view.dart';
import 'package:breakmate/features/break_system/presentation/widgets/quick_reminder_overlay.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/overlay_chrome.dart';

/// Chooses what the overlay shows: a compact reminder/warning, an accessible break view, or the wellness template.
class BreakOverlayContent extends StatelessWidget {
  final OverlayWindowConfig config;
  final AnimationController fadeAnimation;
  final ValueNotifier<int> remainingSecondsNotifier;
  final VoidCallback onSkip;
  final bool canDismiss;
  final BreakModel breakInfo;
  final SettingsModel settings;
  final bool lookedAway;
  final VoidCallback onLookedAway;

  const BreakOverlayContent({
    super.key,
    required this.config,
    required this.fadeAnimation,
    required this.remainingSecondsNotifier,
    required this.onSkip,
    required this.canDismiss,
    required this.breakInfo,
    required this.settings,
    required this.lookedAway,
    required this.onLookedAway,
  });

  bool get _compact => config.windowMode == 'compact';

  bool _needsAccessibleView(BuildContext context) =>
      settings.experience.highContrast ||
      MediaQuery.highContrastOf(context) ||
      MediaQuery.textScalerOf(context).scale(1) > 1 ||
      settings.experience.textScale > 1 ||
      settings.experience.hasExerciseRestrictions;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (config.overlayType == 'quickReminder' ||
        config.overlayType == 'preBreakWarning') {
      content = QuickReminderOverlay(
        reminderType: config.reminderType,
        overlayType: config.overlayType,
        fadeAnimation: fadeAnimation,
        title: config.title,
        durationSeconds: config.durationSeconds,
        remainingSecondsNotifier: remainingSecondsNotifier,
        onSkip: onSkip,
        allowFullPoster:
            config.overlayType == 'quickReminder' && config.allowFullPoster,
        templateId: config.breakTemplate,
      );
    } else if (_needsAccessibleView(context)) {
      content = OverlayChrome(
        templateOwnsChrome: false,
        isInternalPreview: config.isPreview,
        canDismiss: canDismiss,
        breakInfo: breakInfo,
        exerciseTitle: config.showWellnessNotes ? config.exerciseTitle : null,
        intensityLevel: config.intensityLevel,
        onSkip: onSkip,
        lookedAway: lookedAway,
        onLookedAway: _lookedAwayHandler,
        child: ValueListenableBuilder<int>(
          valueListenable: remainingSecondsNotifier,
          builder: (_, remaining, _) => AccessibleBreakView(
            breakInfo: breakInfo,
            settings: settings,
            remaining: remaining,
            instructions: config.exerciseInstructions,
            exerciseTitle: config.exerciseTitle,
          ),
        ),
      );
    } else {
      final handler = _lookedAwayHandler;
      content = Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: WellnessOverlayView(
              config: config,
              remainingSecondsNotifier: remainingSecondsNotifier,
              onSkip: canDismiss ? onSkip : null,
            ),
          ),
          if (handler != null && !_compact)
            Positioned(
              top: 28,
              left: 0,
              right: 0,
              child: Center(
                child: SafeArea(
                  child: LookedAwayButton(
                    confirmed: lookedAway,
                    onPressed: handler,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      // Swipe up to dismiss, only when dismissing is allowed and the surface is full screen.
      onVerticalDragUpdate: (details) {
        if (canDismiss && !_compact && details.delta.dy < -10) {
          onSkip();
        }
      },
      onHorizontalDragUpdate: (_) {},
      child: content,
    );
  }

  VoidCallback? get _lookedAwayHandler =>
      config.lookedAwayPromptEnabled &&
          breakInfo.type == BreakType.short &&
          config.overlayType == 'breakScreen'
      ? onLookedAway
      : null;
}
