import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

import 'package:breakmate/features/break_overlay/presentation/templates/minimal_focus_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/companion_interactive_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/zen_mode_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/productivity_hud_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/classic_slideshow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/activities_break_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/clock_face_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/one_word_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/pulse_dot_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wave_calm_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wind_down_template.dart';

class BreakTemplateSwitcher extends StatelessWidget {
  final String breakTemplate;
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remaining;
  final int total;
  final VoidCallback? onSkip;

  // Slide details for 'classic' slideshow mode
  final String currentTemplate;
  final AnimationController kenBurnsController;
  final String? exerciseTitle;
  final String? exerciseInstructions;

  const BreakTemplateSwitcher({
    super.key,
    required this.breakTemplate,
    required this.breakInfo,
    required this.settings,
    required this.remaining,
    required this.total,
    required this.onSkip,
    required this.currentTemplate,
    required this.kenBurnsController,
    this.exerciseTitle,
    this.exerciseInstructions,
  });

  @override
  Widget build(BuildContext context) {
    if (breakInfo.type == BreakType.windDown) {
      return const WindDownTemplate();
    }

    switch (breakTemplate) {
      case 'classic':
      case 'dusk_glow':
      case 'open_field':
        return ClassicSlideshowTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
          singleImage: currentTemplate,
          kenBurnsController: kenBurnsController,
          exerciseTitle: exerciseTitle,
          exerciseInstructions: exerciseInstructions,
        );
      case 'companion':
        return CompanionInteractiveTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'zen':
      case 'breathe_line':
      case 'warm_amber':
        return ZenModeTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
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
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'activities':
        return ActivitiesBreakTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'clock_face':
      case 'ring_only':
        return ClockFaceTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'one_word':
        return OneWordTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'pulse_dot':
      case 'focus_orb':
        return PulseDotTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'wave_calm':
        return WaveCalmTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'wind_down':
        return const WindDownTemplate();
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
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
    }
  }
}
