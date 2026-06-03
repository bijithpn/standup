import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/minimal_focus_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/companion_interactive_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/zen_mode_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/productivity_hud_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/soft_floating_widget_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/classic_slideshow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/activities_break_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wind_down_template.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

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
      duration: const Duration(milliseconds: 350),
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
    // Low-frequency selector: only rebuilds when break state or settings change,
    // NOT every second. Countdown is isolated below via a nested Selector.
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
          _syncClassicEffects(false);
          if (_fadeController.value > 0) _fadeController.reverse();
          return const SizedBox.shrink();
        }

        _syncClassicEffects(data.settings.breakTemplate == 'classic');
        if (_fadeController.status != AnimationStatus.forward &&
            _fadeController.value < 1) {
          _fadeController.forward();
        }

        final controller = context.read<BreakController>();

        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (!data.settings.strictMode && details.primaryDelta! < -10) {
                controller.skipCurrentBreak();
              }
            },
            onHorizontalDragUpdate: (_) {},
            child: _BreakOverlayContent(
              layoutData: data,
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

  const _BreakOverlayContent({
    required this.layoutData,
    required this.controller,
    required this.pageController,
    required this.kenBurnsController,
  });

  @override
  Widget build(BuildContext context) {
    final settings = layoutData.settings;
    final breakInfo = layoutData.breakInfo;
    final total = breakInfo.type == BreakType.short
        ? settings.shortBreakDurationSeconds
        : settings.longBreakDurationMinutes * 60;
    // Every named template manages its own top rail, skip UI, and action area.
    // Setting this to true for all of them prevents the global pill, close
    // button, and swipe-hint from being stacked on top of template chrome.
    final templateOwnsChrome =
        settings.breakTemplate == 'minimal' ||
        settings.breakTemplate == 'activities' ||
        settings.breakTemplate == 'companion' ||
        settings.breakTemplate == 'zen' ||
        settings.breakTemplate == 'hud' ||
        settings.breakTemplate == 'floating' ||
        settings.breakTemplate == 'classic';
    void onSkip() => controller.skipCurrentBreak();

    return Stack(
      fit: StackFit.expand,
      children: [
        // RepaintBoundary isolates the high-frequency countdown region from
        // the static overlay chrome (skip button, swipe hint).
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: controller.timerEngine.countdownNotifier,
            builder: (_, remaining, _) => _buildTemplate(
              settings: settings,
              breakInfo: breakInfo,
              remaining: remaining,
              total: total,
              onSkip: onSkip,
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
        if (!settings.strictMode && !templateOwnsChrome)
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
        if (!settings.strictMode && !templateOwnsChrome)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: SwipeToDismissHint()),
          ),
        if (settings.strictMode && !templateOwnsChrome)
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

  Widget _buildTemplate({
    required SettingsModel settings,
    required BreakModel breakInfo,
    required int remaining,
    required int total,
    required VoidCallback onSkip,
  }) {
    if (breakInfo.type == BreakType.windDown) {
      return const WindDownTemplate();
    }

    switch (settings.breakTemplate) {
      case 'classic':
        return ClassicSlideshowTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
          pageController: pageController,
          kenBurnsController: kenBurnsController,
          exerciseTitle: controller.currentExerciseTitle,
          exerciseInstructions: controller.currentExerciseInstructions,
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
      case 'hud':
        return ProductivityHudTemplate(
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
      case 'activities':
        return ActivitiesBreakTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
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
