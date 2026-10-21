import 'package:flutter/material.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';

export 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';

/// Compatibility wrapper forwarding to [BreakTemplateSwitcher] so that
/// all callers share a single unified template engine with full template support.
class BreakTemplateSelector extends StatelessWidget {
  final SettingsModel settings;
  final BreakModel breakInfo;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onSkip;
  final PageController? pageController;
  final AnimationController kenBurnsController;
  final String? exerciseTitle;
  final String? exerciseInstructions;
  final String? classicImage;

  const BreakTemplateSelector({
    super.key,
    required this.settings,
    required this.breakInfo,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onSkip,
    this.pageController,
    required this.kenBurnsController,
    this.exerciseTitle,
    this.exerciseInstructions,
    this.classicImage,
  });

  @override
  Widget build(BuildContext context) {
    return BreakTemplateSwitcher(
      breakTemplate: settings.breakTemplate,
      breakInfo: breakInfo,
      settings: settings,
      remaining: remainingSeconds,
      total: totalSeconds,
      onSkip: onSkip,
      pageController: pageController,
      kenBurnsController: kenBurnsController,
      exerciseTitle: exerciseTitle,
      exerciseInstructions: exerciseInstructions,
      classicImage: classicImage,
    );
  }
}
