import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/overlay_chrome.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_overlay_transition_wrapper.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';

class BreakOverlay extends StatelessWidget {
  const BreakOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<BreakController, _BreakLayoutData?>(
      selector: (_, c) {
        final engine = c.timerEngine;
        if (engine.activeBreak == null ||
            engine.state != TimerState.breakActive) {
          return null;
        }
        return _BreakLayoutData(
          breakInfo: engine.activeBreak!,
          settings: c.settingsRepository.currentSettings,
        );
      },
      builder: (context, data, _) {
        if (data == null) {
          return const SizedBox.shrink();
        }

        final controller = context.read<BreakController>();

        return PopScope(
          canPop: false,
          child: BreakOverlayTransitionWrapper(
            breakInfo: data.breakInfo,
            settings: data.settings,
            builder: (context, pageController, kenBurnsController) {
              return _BreakOverlayContent(
                layoutData: data,
                controller: controller,
                pageController: pageController,
                kenBurnsController: kenBurnsController,
                countdownNotifier: controller.timerEngine.countdownNotifier,
              );
            },
          ),
        );
      },
    );
  }
}

class _BreakLayoutData {
  final BreakModel breakInfo;
  final SettingsModel settings;

  const _BreakLayoutData({required this.breakInfo, required this.settings});

  @override
  bool operator ==(Object other) =>
      other is _BreakLayoutData &&
      other.breakInfo == breakInfo &&
      other.settings == settings;

  @override
  int get hashCode => Object.hash(breakInfo, settings);
}

class _BreakOverlayContent extends StatelessWidget {
  final _BreakLayoutData layoutData;
  final BreakController controller;
  final PageController pageController;
  final AnimationController kenBurnsController;
  final ValueNotifier<int> countdownNotifier;

  const _BreakOverlayContent({
    required this.layoutData,
    required this.controller,
    required this.pageController,
    required this.kenBurnsController,
    required this.countdownNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final settings = layoutData.settings;
    final breakInfo = layoutData.breakInfo;
    final total = breakInfo.type == BreakType.short
        ? settings.shortBreakDurationSeconds
        : settings.longBreakDurationMinutes * 60;

    final templateOwnsChrome =
        breakInfo.type == BreakType.windDown ||
        settings.breakTemplate == 'wind_down';

    void onSkip() => controller.skipCurrentBreak();

    return OverlayChrome(
      templateOwnsChrome: templateOwnsChrome,
      isInternalPreview: false,
      canDismiss: !settings.strictMode,
      breakInfo: breakInfo,
      exerciseTitle: settings.showExercisesInBreak
          ? controller.currentExerciseTitle
          : null,
      intensityLevel: settings.intensityLevel,
      onSkip: onSkip,
      child: RepaintBoundary(
        child: ValueListenableBuilder<int>(
          valueListenable: countdownNotifier,
          builder: (_, remaining, _) => BreakTemplateSwitcher(
            breakTemplate: settings.breakTemplate,
            breakInfo: breakInfo,
            settings: settings,
            remaining: remaining,
            total: total,
            onSkip: null, // OverlayChrome provides authoritative skip affordance
            pageController: pageController,
            kenBurnsController: kenBurnsController,
            exerciseTitle: controller.currentExerciseTitle,
            exerciseInstructions: controller.currentExerciseInstructions,
          ),
        ),
      ),
    );
  }
}
