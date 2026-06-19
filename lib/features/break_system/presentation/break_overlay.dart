import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_overlay_transition_wrapper.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_selector.dart';

const _kTemplatesWithChrome = {
  'minimal',
  'activities',
  'companion',
  'zen',
  'hud',
  'floating',
  'classic',
  'soft_arc',
  'breathe_line',
  'clock_face',
  'one_word',
  'open_field',
  'haiku_card',
  'ring_only',
  'step_guide',
  'time_slice',
  'day_stack',
  'pulse_dot',
  'mono_time',
  'split_view',
  'warm_amber',
  'focus_orb',
  'wave_calm',
  'iris_rest',
  'quiet_pill',
  'paper_light',
  'dusk_glow',
};

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
        _kTemplatesWithChrome.contains(settings.breakTemplate);

    void onSkip() => controller.skipCurrentBreak();

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: countdownNotifier,
            builder: (_, remaining, _) => BreakTemplateSelector(
              settings: settings,
              breakInfo: breakInfo,
              remainingSeconds: remaining,
              totalSeconds: total,
              onSkip: onSkip,
              pageController: pageController,
              kenBurnsController: kenBurnsController,
              exerciseTitle: controller.currentExerciseTitle,
              exerciseInstructions: controller.currentExerciseInstructions,
            ),
          ),
        ),
        if (!templateOwnsChrome)
          Positioned(
            top: 28,
            left: 28,
            child: SafeArea(
              child: BreakContextPill(
                breakInfo: breakInfo,
                exerciseTitle: settings.showExercisesInBreak
                    ? controller.currentExerciseTitle
                    : null,
              ),
            ),
          ),
        if (!settings.strictMode)
          Positioned(
            top: 28,
            right: 28,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Skip break',
                onPressed: onSkip,
                icon: const Icon(CupertinoIcons.xmark),
                color: Colors.white.withValues(alpha: 0.78),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.24),
                  fixedSize: const Size.square(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!settings.strictMode)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: SwipeToDismissHint()),
          ),
        if (settings.strictMode)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: StrictModeNote(intensityLevel: settings.intensityLevel),
            ),
          ),
      ],
    );
  }
}
