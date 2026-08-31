import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

import 'package:breakmate/features/break_overlay/presentation/templates/activities_break_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/breathe_line_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/classic_slideshow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/clock_face_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/companion_interactive_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/day_stack_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/dusk_glow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/focus_orb_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/haiku_card_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/iris_rest_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/minimal_focus_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/mono_time_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/one_word_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/open_field_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/paper_light_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/productivity_hud_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/pulse_dot_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/quiet_pill_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/ring_only_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/soft_arc_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/soft_floating_widget_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/split_view_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/step_guide_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/time_slice_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/warm_amber_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wave_calm_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wind_down_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/zen_mode_template.dart';

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
      case 'dusk_glow':
        return DuskGlowTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'open_field':
        return OpenFieldTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
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
        return ZenModeTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'breathe_line':
        return BreatheLineTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'warm_amber':
        return WarmAmberTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'hud':
        return ProductivityHudTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'time_slice':
        return TimeSliceTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'mono_time':
        return MonoTimeTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'split_view':
        return SplitViewTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'step_guide':
        return StepGuideTemplate(
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
        return ClockFaceTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'ring_only':
        return RingOnlyTemplate(
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
        return PulseDotTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'focus_orb':
        return FocusOrbTemplate(
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
      case 'soft_arc':
        return SoftArcTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'haiku_card':
        return HaikuCardTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'day_stack':
        return DayStackTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'iris_rest':
        return IrisRestTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'quiet_pill':
        return QuietPillTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'floating':
        return SoftFloatingWidgetTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'paper_light':
        return PaperLightTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'wind_down':
        return const WindDownTemplate();
      case 'minimal':
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
