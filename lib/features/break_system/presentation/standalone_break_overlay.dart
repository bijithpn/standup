import 'dart:async' show Timer;

import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/minimal_focus_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/companion_interactive_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/zen_mode_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/productivity_hud_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/soft_floating_widget_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/classic_slideshow_template.dart';
import 'package:breakmate/features/break_overlay/presentation/templates/activities_break_template.dart';
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
import 'package:breakmate/features/break_overlay/presentation/templates/wind_down_template.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

enum BreakTheme {
  image,
  ocean,
  forest,
  minimal,
  sunset, // Warm orange and purple gradients
  nebula, // Deep space purple and blue
  midnight, // Pure deep dark navy
  cyberpunk, // Neon pink and blue
  zen, // Soft earth tones and cream
}

// Templates that own their own chrome (skip button, top rail, etc.)
const _kTemplatesWithChrome = {
  'minimal', 'activities', 'companion', 'zen', 'hud', 'floating', 'classic',
  'soft_arc', 'breathe_line', 'clock_face', 'one_word', 'open_field',
  'haiku_card', 'ring_only', 'step_guide', 'time_slice', 'day_stack',
  'pulse_dot', 'mono_time', 'split_view', 'warm_amber', 'focus_orb',
  'wave_calm', 'iris_rest', 'quiet_pill', 'paper_light', 'dusk_glow',
};

class StandaloneBreakOverlay extends StatefulWidget {
  final String title;
  final String message;
  final int durationSeconds;

  static final List<void Function(FlutterErrorDetails)> onErrorCallbacks = [];

  const StandaloneBreakOverlay({
    super.key,
    this.title = "Time for a Break",
    this.message = "Take a moment to stretch and breathe",
    this.durationSeconds = 300,
  });

  @override
  State<StandaloneBreakOverlay> createState() => _StandaloneBreakOverlayState();
}

class _StandaloneBreakOverlayState extends State<StandaloneBreakOverlay>
    with TickerProviderStateMixin {
  static const MethodChannel _bridge = MethodChannel(
    'com.breakmate.desktop/bridge',
  );

  late String _currentTemplate;
  late BreakTheme _currentTheme;
  late AnimationController _kenBurnsController;
  late AnimationController _fadeController;
  bool _classicEffectsRunning = false;

  String _title = "Time for a Break";
  String _tip = "Take a moment to recharge.";
  int _durationSeconds = 300;
  int _remainingSeconds = 300;
  String _overlayType = 'breakScreen';
  int _screenId = 0;
  bool _strictMode = false;
  bool _enableAnimations = true;
  String _intensityLevel = 'standard';
  String? _reminderType;
  bool _showWellnessNotes = true;
  bool _isInternalPreview =
      false; // Flag to disable expensive animations during preview

  DateTime? _targetEndTime;
  Timer? _localTimer;

  String? _exerciseTitle;
  String? _exerciseInstructions;
  String _breakTemplate = 'minimal';
  String _companionPetTheme = 'grey_cat';
  int _maxWarningSeconds = 10;

  bool _templateFailed = false;
  String? _breakTypeStr;

  int _clockFaceTextColorHex = 0xFFFFFFFF;
  bool _clockFaceBlurEnabled = true;
  String? _customImagePath;

  bool _initialized = false;
  bool _isDismissing = false;

  // KEY PERFORMANCE FIX: ValueNotifier for countdown allows ValueListenableBuilder
  // to isolate rebuilds to only the template widget, not the entire screen.
  // This keeps StatefulWidget templates (WaveCalm, BreatheLineTemplate, etc.)
  // alive across every-second ticks — preserving their AnimationControllers.
  late final ValueNotifier<int> _remainingSecondsNotifier;

  void _loadInitialSettings() {
    try {
      if (SimplePrefs.instance.isReady) {
        final template = SimplePrefs.instance.getString('break_template', defaultValue: 'minimal');
        final petTheme = SimplePrefs.instance.getString('companion_pet_theme', defaultValue: 'grey_cat');
        final showNotes = SimplePrefs.instance.getBool('show_exercises_in_break', defaultValue: true);
        final strict = SimplePrefs.instance.getBool('strict_mode', defaultValue: false);
        final anim = SimplePrefs.instance.getBool('enable_animations', defaultValue: true);
        final intensity = SimplePrefs.instance.getString('intensity_level', defaultValue: 'standard');
        final textColor = SimplePrefs.instance.getInt('clock_face_text_color_hex', defaultValue: 0xFFFFFFFF);
        final blurEnabled = SimplePrefs.instance.getBool('clock_face_blur_enabled', defaultValue: true);
        final customImg = SimplePrefs.instance.getString('custom_image_path', defaultValue: '');
        
        setState(() {
          _breakTemplate = template;
          _companionPetTheme = petTheme;
          _showWellnessNotes = showNotes;
          _strictMode = strict;
          _enableAnimations = anim;
          _intensityLevel = intensity;
          _clockFaceTextColorHex = textColor;
          _clockFaceBlurEnabled = blurEnabled;
          _customImagePath = customImg == "" ? null : customImg;
        });
      }
    } catch (_) {
      // Fallback to defaults
    }
  }

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _durationSeconds = widget.durationSeconds;
    _remainingSeconds = widget.durationSeconds;

    // Resolve user's actual selected template and settings from SimplePrefs on startup
    _loadInitialSettings();

    _currentTemplate =
        AppConstants.wellnessSlideshow[Random().nextInt(
          AppConstants.wellnessSlideshow.length,
        )];
    _currentTheme =
        BreakTheme.values[Random().nextInt(BreakTheme.values.length)];

    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _remainingSecondsNotifier = ValueNotifier<int>(_remainingSeconds);

    _setupBridge();
    _loadInitialData();

    // Smoothly fade in
    _fadeController.forward();

    StandaloneBreakOverlay.onErrorCallbacks.add(_handleTemplateError);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  Future<void> _loadInitialData() async {
    try {
      final Map? data = await _bridge.invokeMethod<Map>('getOverlayData');
      if (data != null && mounted) {
        _applyOverlayData(data);
      }
    } catch (e) {
      debugPrint('Error getting initial overlay data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    }
  }

  void _applyOverlayData(Map args) {
    if (!mounted) return;

    if (args.containsKey('breaksCompleted')) {
      final count = args['breaksCompleted'] as int;
      try {
        if (sl.isRegistered<StatsService>()) {
          final service = sl<StatsService>();
          if (service.runtimeType.toString() == 'FakeStatsService') {
            (service as dynamic).updateBreaksCompleted(count);
          }
        }
      } catch (_) {}
    }

    // If targetEndTime is passed, use it to count down locally!
    final targetEndMs = args['targetEndTime'] as int?;
    if (targetEndMs != null) {
      _targetEndTime = DateTime.fromMillisecondsSinceEpoch(targetEndMs);
      _startLocalTimer();
    } else {
      _targetEndTime = null;
      _localTimer?.cancel();
      _localTimer = null;
    }

    // If we are transitioning to zero remaining seconds (auto-close),
    // or explicitly told to close, trigger fade out.
    final newRemaining = args['remainingSeconds'] ?? _remainingSeconds;
    if (newRemaining == 0 && _remainingSeconds > 0) {
      _fadeController.reverse();
    }

    setState(() {
      _title = args['title'] ?? _title;
      _tip = args['tip'] ?? _tip;
      _durationSeconds = args['durationSeconds'] ?? _durationSeconds;
      if (targetEndMs == null) {
        _remainingSeconds = args['remainingSeconds'] ?? _remainingSeconds;
      }
      _overlayType = args['type'] ?? _overlayType;
      _strictMode = args['strictMode'] ?? _strictMode;
      _enableAnimations = args['enableAnimations'] ?? _enableAnimations;
      _intensityLevel = args['intensityLevel'] ?? _intensityLevel;
      _showWellnessNotes = args['showWellnessNotes'] ?? _showWellnessNotes;
      _isInternalPreview = args['isPreview'] ?? false;
      if (args.containsKey('breakType')) {
        _breakTypeStr = args['breakType'];
      }

      if (args['theme'] != null) {
        final String themeStr = args['theme'];
        _currentTheme = BreakTheme.values.firstWhere(
          (e) => e.name == themeStr,
          orElse: () => _currentTheme,
        );
      }
      // Use the coordinator-chosen image so all displays show the same one
      if (args['classicImage'] != null) {
        _currentTemplate = args['classicImage'] as String;
      }
      if (args['breakTemplate'] != null) {
        _breakTemplate = args['breakTemplate'];
      } else if (args['template'] != null) {
        _breakTemplate = args['template'];
      }
      _syncClassicEffects(_breakTemplate == 'classic' && _enableAnimations);
      if (args['companionPetTheme'] != null) {
        _companionPetTheme = args['companionPetTheme'];
      } else if (args['companionCatTheme'] != null) {
        _companionPetTheme = args['companionCatTheme'];
      }
      if (args.containsKey('clockFaceTextColorHex')) {
        _clockFaceTextColorHex = args['clockFaceTextColorHex'] as int;
      }
      if (args.containsKey('clockFaceBlurEnabled')) {
        _clockFaceBlurEnabled = args['clockFaceBlurEnabled'] as bool;
      }
      if (args.containsKey('customImagePath')) {
        _customImagePath = args['customImagePath'] as String?;
        if (_customImagePath == "") _customImagePath = null;
      }
      if (args.containsKey('exerciseTitle')) {
        _exerciseTitle = args['exerciseTitle'];
      }
      if (args.containsKey('exerciseInstructions')) {
        _exerciseInstructions = args['exerciseInstructions'];
      }
      if (args['reminderType'] != null) {
        final newReminderType = args['reminderType'];
        if (newReminderType != _reminderType) {
          _maxWarningSeconds = newRemaining;
        }
        _reminderType = newReminderType;
      }
      if (newRemaining > _maxWarningSeconds) {
        _maxWarningSeconds = newRemaining;
      }

      // Auto-dismiss quick reminders / prebreak warnings after 5/3 seconds
      if (_overlayType == 'quickReminder' || _overlayType == 'preBreakWarning') {
        _fadeController.duration = const Duration(milliseconds: 400);
        final dismissDelay = _overlayType == 'preBreakWarning'
            ? const Duration(seconds: 3)
            : const Duration(seconds: 5);
        Future.delayed(dismissDelay, () {
          if (mounted && (_overlayType == 'quickReminder' || _overlayType == 'preBreakWarning')) {
            _skipBreak();
          }
        });
      } else {
        // Reset to default duration for normal break screens
        _fadeController.duration = const Duration(milliseconds: 600);
      }
    });
  }

  void _startLocalTimer() {
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_targetEndTime != null) {
        final newRemaining = _targetEndTime!
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, _durationSeconds);

        if (newRemaining != _remainingSeconds) {
          if (newRemaining == 0 && _remainingSeconds > 0) {
            _completeBreak();
          }
          _remainingSeconds = newRemaining;
          // Update the notifier directly — only rebuilds ValueListenableBuilder subtree,
          // NOT the entire widget tree. This preserves StatefulWidget template states.
          _remainingSecondsNotifier.value = newRemaining;
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_breakTemplate == 'classic') {
      precacheImage(AssetImage(_currentTemplate), context);
    }
  }

  void _setupBridge() {
    _bridge.setMethodCallHandler((call) async {
      if (call.method == 'updateOverlayData') {
        final args = call.arguments as Map;
        _applyOverlayData(args);
      } else if (call.method == 'setScreenInfo') {
        final args = call.arguments as Map;
        if (mounted) {
          setState(() {
            _screenId = args['id'] ?? _screenId;
          });
        }
      }
    });
  }

  void _syncClassicEffects(bool enabled) {
    if (_classicEffectsRunning == enabled) return;
    _classicEffectsRunning = enabled;

    if (enabled) {
      _kenBurnsController.repeat(reverse: true);
    } else {
      _kenBurnsController.stop();
    }
  }

  void _completeBreak() {
    if (_isDismissing) return;
    _isDismissing = true;

    bool callbackTriggered = false;
    void triggerDismiss() {
      if (callbackTriggered) return;
      callbackTriggered = true;
      if (_isInternalPreview || _overlayType == 'preBreakWarning' || _overlayType == 'quickReminder') {
        // Just hide the overlay window without skipping the actual upcoming break or reminder statistics
        _bridge.invokeMethod('hideOverlay', {'restoreMainWindow': true});
      } else {
        _bridge.invokeMethod('completeBreak');
      }
    }

    // Safety fallback: if ticker is throttled/paused by macOS window level, trigger dismissal after 800ms
    Timer(const Duration(milliseconds: 800), triggerDismiss);

    // Reverse fade for a smooth exit, then call the native bridge
    _fadeController.reverse().then((_) {
      triggerDismiss();
    });
  }

  void _skipBreak() {
    if (_isDismissing) return;
    _isDismissing = true;

    bool callbackTriggered = false;
    void triggerDismiss() {
      if (callbackTriggered) return;
      callbackTriggered = true;
      if (_isInternalPreview || _overlayType == 'preBreakWarning' || _overlayType == 'quickReminder') {
        // Just hide the overlay window without skipping the actual upcoming break or reminder statistics
        _bridge.invokeMethod('hideOverlay', {'restoreMainWindow': true});
      } else {
        NativeBridge.skipBreak();
      }
    }

    // Safety fallback: if ticker is throttled/paused by macOS window level, trigger dismissal after 800ms
    Timer(const Duration(milliseconds: 800), triggerDismiss);

    // Reverse fade for a smooth exit, then call the native bridge
    _fadeController.reverse().then((_) {
      triggerDismiss();
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted) return false;

    // Check for Command/Control + Shift + B to quit the app
    final isModifierPressed = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isModifierPressed &&
        HardwareKeyboard.instance.isShiftPressed &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyB) {
      _bridge.invokeMethod('quitApp');
      return true;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (_canDismiss) {
        _skipBreak();
        return true;
      }
    }
    return false;
  }

  bool get _canDismiss =>
      (!_strictMode && !_isInternalPreview) ||
      _overlayType == 'quickReminder' ||
      _overlayType == 'preBreakWarning';

  void _handleTemplateError(FlutterErrorDetails details) {
    if (!_templateFailed) {
      debugPrint('Template $_breakTemplate failed: ${details.exception}');
      _templateFailed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _breakTemplate = 'minimal';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    StandaloneBreakOverlay.onErrorCallbacks.remove(_handleTemplateError);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _localTimer?.cancel();
    _remainingSecondsNotifier.dispose();
    _kenBurnsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Material(
        color: Colors.transparent,
        child: SizedBox.shrink(),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Material(
        color: _overlayType == 'quickReminder' || _overlayType == 'preBreakWarning'
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            // If dragging up, dismiss the overlay completely (only if not in strict mode, or preview/warning).
            if (_canDismiss && details.primaryDelta! < -10) {
              _skipBreak();
            }
          },
          // We consume horizontal drag so it doesn't do anything (not strict, but prevents movement)
          onHorizontalDragUpdate: (details) {},
          child: RepaintBoundary(child: _buildBreakScreen()),
        ),
      ),
    );
  }

  Widget _buildBreakScreen() {
    if (_overlayType == 'quickReminder' || _overlayType == 'preBreakWarning') {
      return _buildQuickReminder();
    }

    BreakType type;
    if (_breakTypeStr != null) {
      type = BreakType.values.firstWhere(
        (e) => e.name == _breakTypeStr,
        orElse: () => BreakType.long,
      );
    } else {
      type = _title.toUpperCase().contains('SHORT') ||
              _title.toUpperCase().contains('EYE')
          ? BreakType.short
          : BreakType.long;
    }

    final breakInfo = BreakModel(
      type: type,
      durationSeconds: _durationSeconds,
      title: _title,
      tip: _tip,
    );

    final settings = SettingsModel(
      strictMode: _strictMode,
      enableAnimations: _enableAnimations,
      companionPetTheme: _companionPetTheme,
      breakTemplate: _breakTemplate,
      showExercisesInBreak: _showWellnessNotes,
      clockFaceTextColorHex: _clockFaceTextColorHex,
      clockFaceBlurEnabled: _clockFaceBlurEnabled,
      customImagePath: _customImagePath,
    );

    final total = _durationSeconds;
    // Only provide a live skip callback when not in strict mode (or in preview/warning).
    final VoidCallback? onSkip = _canDismiss ? _skipBreak : null;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // KEY PERFORMANCE FIX: ValueListenableBuilder wraps ONLY the template.
        // The outer Stack (chrome items) stays stable — only the template
        // rebuilds each second. Flutter's element reconciliation keeps the same
        // StatefulWidget element alive (same runtimeType), so AnimationControllers
        // in WaveCalm, BreatheLineTemplate, ActivitiesBreak, etc. are preserved.
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _remainingSecondsNotifier,
            builder: (_, remaining, _) => _buildTemplateWidget(
              breakInfo: breakInfo,
              settings: settings,
              remaining: remaining,
              total: total,
              onSkip: onSkip,
            ),
          ),
        ),
        if (!_templateOwnsChrome)
          Positioned(
            top: 28,
            left: 28,
            child: SafeArea(
              child: BreakContextPill(
                breakInfo: breakInfo,
                exerciseTitle: _showWellnessNotes ? _exerciseTitle : null,
              ),
            ),
          ),
        if (_isInternalPreview)
          Positioned(
            top: 32,
            left: 0,
            right: 0,
            child: Center(
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.eye_fill,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'PREVIEW MODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_canDismiss && !_templateOwnsChrome)
          Positioned(
            top: 28,
            right: 28,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Skip break',
                onPressed: _skipBreak,
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
        if (_canDismiss && !_templateOwnsChrome)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: SwipeToDismissHint()),
          ),
        if (!_canDismiss && !_templateOwnsChrome)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: StrictModeNote(intensityLevel: _intensityLevel),
            ),
          ),
      ],
    );
  }

  Widget _buildTemplateWidget({
    required BreakModel breakInfo,
    required SettingsModel settings,
    required int remaining,
    required int total,
    required VoidCallback? onSkip,
  }) {
    if (breakInfo.type == BreakType.windDown) {
      return const WindDownTemplate();
    }

    switch (_breakTemplate) {
      case 'classic':
        return ClassicSlideshowTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
          singleImage: _currentTemplate,
          kenBurnsController: _kenBurnsController,
          exerciseTitle: _exerciseTitle,
          exerciseInstructions: _exerciseInstructions,
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
        return MinimalFocusTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
      case 'soft_arc':
        return SoftArcTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'breathe_line':
        return BreatheLineTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'clock_face':
        return ClockFaceTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'one_word':
        return OneWordTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'open_field':
        return OpenFieldTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'haiku_card':
        return HaikuCardTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'ring_only':
        return RingOnlyTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'step_guide':
        return StepGuideTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'time_slice':
        return TimeSliceTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'day_stack':
        return DayStackTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'pulse_dot':
        return PulseDotTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'mono_time':
        return MonoTimeTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'split_view':
        return SplitViewTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'warm_amber':
        return WarmAmberTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'focus_orb':
        return FocusOrbTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'wave_calm':
        return WaveCalmTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'iris_rest':
        return IrisRestTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'quiet_pill':
        return QuietPillTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'paper_light':
        return PaperLightTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'dusk_glow':
        return DuskGlowTemplate(breakInfo: breakInfo, settings: settings, remainingSeconds: remaining, totalSeconds: total, onSkip: onSkip);
      case 'wind_down':
        return const WindDownTemplate();
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

  bool get _templateOwnsChrome {
    // All named templates self-manage their chrome (top rail, skip, hints).
    // This prevents the global pill / close / swipe-hint from being stacked
    // on top of template-owned header and footer areas.
    final isWindDown = _title.toUpperCase().contains('WIND DOWN') || (_breakTypeStr == 'windDown');
    if (isWindDown) return true;
    return _kTemplatesWithChrome.contains(_breakTemplate) || _breakTemplate == 'wind_down';
  }

  Widget _buildQuickReminder() {
    final isPosture = _reminderType == 'posture';
    final isBreakStart = _reminderType == 'breakStart' || _overlayType == 'preBreakWarning';

    if (isBreakStart) {
      return _buildBreakStartWarning();
    }

    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceCard,
                AppTheme.surfaceCard.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtle top label
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isPosture ? 'POSTURE CHECK' : 'EYE REFRESH',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isPosture
                      ? CupertinoIcons.person_crop_circle_badge_checkmark
                      : CupertinoIcons.eye_fill,
                  color: AppTheme.accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPosture ? 'Check Your Posture' : 'Rest Your Eyes',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPosture
                    ? 'Sit up straight, relax your neck, and drop your shoulders.'
                    : 'Blink a few times and focus on something far away.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakStartWarning() {
    final isPosture = _title.toUpperCase().contains('POSTURE');
    final isEye = _title.toUpperCase().contains('EYE');

    final String labelText = isPosture
        ? 'POSTURE BREAK'
        : isEye
        ? 'EYE BREAK'
        : 'UPCOMING BREAK';

    final IconData mainIcon = isPosture
        ? CupertinoIcons.person_fill
        : isEye
        ? CupertinoIcons.eye_fill
        : CupertinoIcons.timer;

    final String timeLabel = _durationSeconds >= 60
        ? '${(_durationSeconds / 60).round()} minute${(_durationSeconds / 60).round() > 1 ? 's' : ''}'
        : '$_durationSeconds seconds';

    final String dynamicMessage = isPosture
        ? 'A posture break will start in $timeLabel. Prepare to stand up.'
        : isEye
        ? 'An eye break will start in $timeLabel. Prepare to look away.'
        : 'A break will start in $timeLabel. Prepare to step away and rest.';

    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceCard,
                AppTheme.surfaceCard.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  labelText,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(mainIcon, color: AppTheme.accent, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Break Starts Soon',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dynamicMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
