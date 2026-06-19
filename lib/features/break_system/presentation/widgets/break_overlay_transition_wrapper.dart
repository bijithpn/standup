import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/menu_bar/controllers/menu_bar_controller.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';

/// A wrapper widget that manages transition animations (Fade, Ken Burns),
/// automatic slideshow timers, and keyboard input handlers during an active break.
class BreakOverlayTransitionWrapper extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final Widget Function(
    BuildContext context,
    PageController pageController,
    AnimationController kenBurnsController,
  ) builder;

  const BreakOverlayTransitionWrapper({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.builder,
  });

  @override
  State<BreakOverlayTransitionWrapper> createState() =>
      _BreakOverlayTransitionWrapperState();
}

class _BreakOverlayTransitionWrapperState
    extends State<BreakOverlayTransitionWrapper> with TickerProviderStateMixin {
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

  @override
  void didUpdateWidget(BreakOverlayTransitionWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClassicEffects(widget.settings.breakTemplate == 'classic');
    if (_fadeController.status != AnimationStatus.forward &&
        _fadeController.value < 1) {
      _fadeController.forward();
    }
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
        controller.skipCurrentBreak();
        return true;
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
    _syncClassicEffects(widget.settings.breakTemplate == 'classic');
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
          final dy = details.delta.dy;
          if (!widget.settings.strictMode && dy < -10) {
            controller.skipCurrentBreak();
          }
        },
        onHorizontalDragUpdate: (_) {},
        child: widget.builder(context, _pageController, _kenBurnsController),
      ),
    );
  }
}
