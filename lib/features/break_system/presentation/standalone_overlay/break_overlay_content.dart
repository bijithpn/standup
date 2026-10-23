import 'package:flutter/material.dart';
import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';
import 'package:breakmate/features/break_system/presentation/widgets/quick_reminder_overlay.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/overlay_chrome.dart';

/// Renders the visual body of the overlay: switches between
/// [QuickReminderOverlay] and [OverlayChrome] + [BreakTemplateSwitcher],
/// with drag-to-dismiss gesture handling.
class BreakOverlayContent extends StatelessWidget {
  final OverlayWindowConfig config;
  final AnimationController fadeAnimation;
  final ValueNotifier<int> remainingSecondsNotifier;
  final VoidCallback onSkip;
  final bool canDismiss;
  final BreakModel breakInfo;
  final SettingsModel settings;
  final String currentTemplate;
  final AnimationController kenBurnsController;
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
    required this.currentTemplate,
    required this.kenBurnsController,
    required this.lookedAway,
    required this.onLookedAway,
  });

  bool get _templateOwnsChrome {
    // Only full-screen custom routines (like wind_down) own their entire layout.
    // All other templates receive unified OverlayChrome (context pill, controls).
    final isWindDown =
        config.title.toUpperCase().contains('WIND DOWN') ||
        (config.breakType == 'windDown') ||
        config.breakTemplate == 'wind_down';
    return isWindDown;
  }

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
      );
    } else {
      content = OverlayChrome(
        templateOwnsChrome: _templateOwnsChrome,
        isInternalPreview: config.isPreview,
        canDismiss: canDismiss,
        breakInfo: breakInfo,
        exerciseTitle: config.showWellnessNotes ? config.exerciseTitle : null,
        intensityLevel: config.intensityLevel,
        onSkip: onSkip,
        lookedAway: lookedAway,
        onLookedAway:
            config.lookedAwayPromptEnabled &&
                breakInfo.type == BreakType.short &&
                config.overlayType == 'breakScreen'
            ? onLookedAway
            : null,
        child: RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: remainingSecondsNotifier,
            builder: (_, remaining, _) => BreakTemplateSwitcher(
              breakTemplate: config.breakTemplate,
              breakInfo: breakInfo,
              settings: settings,
              remaining: remaining,
              total: config.durationSeconds,
              onSkip:
                  null, // OverlayChrome handles the authoritative skip button
              currentTemplate: currentTemplate,
              kenBurnsController: kenBurnsController,
              exerciseTitle: config.exerciseTitle,
              exerciseInstructions: config.exerciseInstructions,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (canDismiss && details.delta.dy < -10) {
          onSkip();
        }
      },
      onHorizontalDragUpdate: (_) {},
      child: content,
    );
  }
}
