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
import 'package:standup/features/break_overlay/presentation/templates/classic_slideshow_template.dart';

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
  late AnimationController _fadeController;
  bool _classicEffectsRunning = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  void _startSlideshow() {
    if (_slideshowTimer != null) return;
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

  void _syncClassicEffects(bool enabled) {
    if (_classicEffectsRunning == enabled) return;
    _classicEffectsRunning = enabled;

    if (enabled) {
      _startSlideshow();
      _kenBurnsController.repeat(reverse: true);
    } else {
      _slideshowTimer?.cancel();
      _slideshowTimer = null;
      _kenBurnsController.stop();
    }
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    _kenBurnsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;
        final breakInfo = timerEngine.activeBreak;

        if (breakInfo == null || timerEngine.state != TimerState.breakActive) {
          _syncClassicEffects(false);
          if (_fadeController.value > 0) {
            _fadeController.reverse();
          }
          return const SizedBox.shrink();
        }

        final settings = controller.settingsRepository.currentSettings;
        _syncClassicEffects(settings.breakTemplate == 'classic');
        if (_fadeController.status != AnimationStatus.forward &&
            _fadeController.value < 1) {
          _fadeController.forward();
        }

        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutCubic,
          ),
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (!controller.settingsRepository.currentSettings.strictMode &&
                  details.primaryDelta! < -10) {
                controller.skipCurrentBreak();
              }
            },
            onHorizontalDragUpdate: (details) {},
            child: _BreakOverlayContent(
              breakInfo: breakInfo,
              settings: settings,
              timerEngine: timerEngine,
              controller: controller,
              pageController: _pageController,
              kenBurnsController: _kenBurnsController,
            ),
          ),
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

    Widget templateWidget;
    switch (widget.settings.breakTemplate) {
      case 'classic':
        templateWidget = ClassicSlideshowTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
          pageController: widget.pageController,
          kenBurnsController: widget.kenBurnsController,
          exerciseTitle: widget.controller.currentExerciseTitle,
          exerciseInstructions: widget.controller.currentExerciseInstructions,
        );
        break;
      case 'companion':
        templateWidget = CompanionInteractiveTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'zen':
        templateWidget = ZenModeTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'hud':
        templateWidget = ProductivityHudTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'floating':
        templateWidget = SoftFloatingWidgetTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'minimal':
      default:
        templateWidget = MinimalFocusTemplate(
          breakInfo: widget.breakInfo,
          settings: widget.settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        templateWidget,
        if (!widget.settings.strictMode)
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
        // Global visual indicator to swipe up to dismiss
        if (!widget.settings.strictMode)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.chevron_up,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  Text(
                    'Swipe up to dismiss',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
