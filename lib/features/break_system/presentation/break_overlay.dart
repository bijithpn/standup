import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/break_overlay/presentation/templates/minimal_focus_template.dart';
import 'package:standup/features/break_overlay/presentation/templates/companion_interactive_template.dart';
import 'package:standup/features/break_overlay/presentation/templates/zen_mode_template.dart';
import 'package:standup/features/break_overlay/presentation/templates/productivity_hud_template.dart';
import 'package:standup/features/break_overlay/presentation/templates/soft_floating_widget_template.dart';

class BreakOverlay extends StatefulWidget {
  const BreakOverlay({super.key});

  @override
  State<BreakOverlay> createState() => _BreakOverlayState();
}

class _BreakOverlayState extends State<BreakOverlay>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentSlide = 0;
  Timer? _slideshowTimer;
  late AnimationController _kenBurnsController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startSlideshow();

    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  void _startSlideshow() {
    _slideshowTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      setState(() {
        _currentSlide =
            (_currentSlide + 1) % AppConstants.wellnessSlideshow.length;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentSlide,
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeInOutQuart,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    _kenBurnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;
        final breakInfo = timerEngine.activeBreak;

        if (breakInfo == null || timerEngine.state != TimerState.breakActive) {
          return const SizedBox.shrink();
        }

        return _BreakOverlayContent(
          breakInfo: breakInfo,
          settings: controller.settingsRepository.currentSettings,
          timerEngine: timerEngine,
          controller: controller,
          pageController: _pageController,
          kenBurnsController: _kenBurnsController,
        );
      },
    );
  }
}

class _BreakOverlayContent extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final TimerEngine timerEngine;
  final BreakController controller;
  final PageController pageController;
  final AnimationController kenBurnsController;

  const _BreakOverlayContent({
    required this.breakInfo,
    required this.settings,
    required this.timerEngine,
    required this.controller,
    required this.pageController,
    required this.kenBurnsController,
  });

  @override
  State<_BreakOverlayContent> createState() => _BreakOverlayContentState();
}

class _BreakOverlayContentState extends State<_BreakOverlayContent> {
  @override
  Widget build(BuildContext context) {
    final remaining = widget.timerEngine.countdownSeconds;
    final total = widget.breakInfo.type == BreakType.short
        ? widget.settings.shortBreakDurationSeconds
        : widget.settings.longBreakDurationMinutes * 60;
    void onSkip() => widget.controller.skipCurrentBreak();

    switch (widget.settings.breakTemplate) {
      case 'companion':
        return CompanionInteractiveTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'zen':
        return ZenModeTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'hud':
        return ProductivityHudTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'floating':
        return SoftFloatingWidgetTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'minimal':
      default:
        return MinimalFocusTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
    }
  }
}
