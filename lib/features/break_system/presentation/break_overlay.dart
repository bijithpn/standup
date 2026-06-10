import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';
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
import 'package:breakmate/features/break_overlay/presentation/templates/soft_arc_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/breathe_line_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/clock_face_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/one_word_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/open_field_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/haiku_card_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/ring_only_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/step_guide_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/time_slice_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/day_stack_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/pulse_dot_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/mono_time_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/split_view_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/warm_amber_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/focus_orb_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/wave_calm_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/iris_rest_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/quiet_pill_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/paper_light_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/dusk_glow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';
import 'package:breakmate/core/errors/error_handler.dart';

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
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted) return false;

    final isModifierPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isModifierPressed &&
        HardwareKeyboard.instance.isShiftPressed &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyB) {
      try {
        sl<MenuBarController>().handleAction('quit');
        return true;
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      try {
        final controller = context.read<BreakController>();
        final settings = controller.settingsRepository.currentSettings;
        if (!settings.strictMode) {
          controller.skipCurrentBreak();
          return true;
        }
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
    }
    return false;
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
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _slideshowTimer?.cancel();
    _pageController.dispose();
    _kenBurnsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

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
              countdownNotifier: controller.timerEngine.countdownNotifier,
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
  final ValueNotifier<int> countdownNotifier;

  const _BreakOverlayContent({
    required this.layoutData,
    required this.controller,
    required this.pageController,
    required this.kenBurnsController,
    required this.countdownNotifier,
  });

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
      case 'soft_arc':
        return SoftArcTemplate(
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
      case 'clock_face':
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
      case 'open_field':
        return OpenFieldTemplate(
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
      case 'ring_only':
        return RingOnlyTemplate(
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
      case 'time_slice':
        return TimeSliceTemplate(
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
      case 'pulse_dot':
        return PulseDotTemplate(
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
      case 'warm_amber':
        return WarmAmberTemplate(
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
      case 'paper_light':
        return PaperLightTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'dusk_glow':
        return DuskGlowTemplate(
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
        // KEY FIX: RepaintBoundary + ValueListenableBuilder wraps the template.
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: countdownNotifier,
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
}
