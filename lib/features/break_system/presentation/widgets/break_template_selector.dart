import 'package:flutter/material.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';

import 'package:breakmate/features/break_overlay/presentation/templates/minimal_focus_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/companion_interactive_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/zen_mode_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/productivity_hud_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/classic_slideshow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/activities_break_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wind_down_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/clock_face_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/one_word_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/pulse_dot_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wave_calm_template.dart';

class BreakTemplateSelector extends StatelessWidget {
  final SettingsModel settings;
  final BreakModel breakInfo;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onSkip;
  final PageController pageController;
  final AnimationController kenBurnsController;
  final String? exerciseTitle;
  final String? exerciseInstructions;

  const BreakTemplateSelector({
    super.key,
    required this.settings,
    required this.breakInfo,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onSkip,
    required this.pageController,
    required this.kenBurnsController,
    this.exerciseTitle,
    this.exerciseInstructions,
  });

  @override
  Widget build(BuildContext context) {
    if (breakInfo.type == BreakType.windDown) {
      return const WindDownTemplate();
    }

    switch (settings.breakTemplate) {
      case 'classic':
      case 'dusk_glow':
      case 'open_field':
        return ClassicSlideshowTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
          pageController: pageController,
          kenBurnsController: kenBurnsController,
          exerciseTitle: exerciseTitle,
          exerciseInstructions: exerciseInstructions,
        );
      case 'companion':
        return CompanionInteractiveTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'zen':
      case 'breathe_line':
      case 'warm_amber':
        return ZenModeTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'hud':
      case 'time_slice':
      case 'mono_time':
      case 'split_view':
      case 'step_guide':
        return ProductivityHudTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'activities':
        return ActivitiesBreakTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'clock_face':
      case 'ring_only':
        return ClockFaceTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'one_word':
        return OneWordTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'pulse_dot':
      case 'focus_orb':
        return PulseDotTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'wave_calm':
        return WaveCalmTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
      case 'minimal':
      case 'soft_arc':
      case 'haiku_card':
      case 'day_stack':
      case 'iris_rest':
      case 'quiet_pill':
      case 'floating':
      case 'paper_light':
      default:
        return MinimalFocusTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          onSkip: onSkip,
        );
    }
  }
}
