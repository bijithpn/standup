import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_template_switcher.dart';
import 'package:breakmate/features/break_system/presentation/widgets/quick_reminder_overlay.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/core/services/error_toast_service.dart';
import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/presentation_detection_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/break_system/presentation/widgets/poster_reminder_gate.dart';

import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_timer_manager.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/overlay_chrome.dart';

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
  'night_sky',
};

class StandaloneBreakOverlay extends StatefulWidget {
  final String title;
  final String message;
  final int initialDurationSeconds;

  static final List<void Function(FlutterErrorDetails)> onErrorCallbacks = [];

  const StandaloneBreakOverlay({
    super.key,
    this.title = "Time for a Break",
    this.message = "Take a moment to stretch and breathe",
    this.initialDurationSeconds = 300,
  });

  @override
  State<StandaloneBreakOverlay> createState() => _StandaloneBreakOverlayState();
}

class _StandaloneBreakOverlayState extends State<StandaloneBreakOverlay>
    with TickerProviderStateMixin, BreakTimerManager {
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
  String _overlayType = 'breakScreen';
  int _screenId = 0;
  bool _strictMode = false;
  bool _enableAnimations = true;
  String _intensityLevel = 'standard';
  String? _reminderType;
  bool _showWellnessNotes = true;
  bool _isInternalPreview =
      false; // Flag to disable expensive animations during preview

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

  // Cached so _buildBreakScreen() (called on every build, including builds
  // triggered by unrelated setState() calls) doesn't reconstruct these value
  // objects every time OverlayChrome rebuilds its Stack.
  BreakModel? _cachedBreakModel;
  SettingsModel? _cachedSettingsModel;

  // True once SimplePrefs settings are loaded; the overlay renders immediately.
  // The async bridge call still runs to refine timer data, but does not gate rendering.
  bool _initialized = false;

  void _loadInitialSettings() {
    try {
      if (SimplePrefs.instance.isReady) {
        final template = SimplePrefs.instance.getString(
          'break_template',
          defaultValue: 'minimal',
        );
        final petTheme = SimplePrefs.instance.getString(
          'companion_pet_theme',
          defaultValue: 'grey_cat',
        );
        final showNotes = SimplePrefs.instance.getBool(
          'show_exercises_in_break',
          defaultValue: true,
        );
        final strict = SimplePrefs.instance.getBool(
          'strict_mode',
          defaultValue: false,
        );
        final anim = SimplePrefs.instance.getBool(
          'enable_animations',
          defaultValue: true,
        );
        final intensity = SimplePrefs.instance.getString(
          'intensity_level',
          defaultValue: 'standard',
        );
        final textColor = SimplePrefs.instance.getInt(
          'clock_face_text_color_hex',
          defaultValue: 0xFFFFFFFF,
        );
        final blurEnabled = SimplePrefs.instance.getBool(
          'clock_face_blur_enabled',
          defaultValue: true,
        );
        final customImg = SimplePrefs.instance.getString(
          'custom_image_path',
          defaultValue: '',
        );

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
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    durationSeconds = widget.initialDurationSeconds;
    remainingSeconds = widget.initialDurationSeconds;

    // Load settings synchronously from SimplePrefs so the template can render
    // on the first frame without waiting for the async bridge call.
    _loadInitialSettings();

    // Mark initialized now — SimplePrefs settings are sufficient to render.
    // The async _loadInitialData() will update remaining-seconds and any
    // per-break fields (exercise, theme, etc.) once the bridge responds.
    _initialized = true;

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

    _setupBridge();
    _loadInitialData();

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
    }
  }

  void _applyOverlayData(Map args) {
    if (!mounted) return;

    _cachedBreakModel = null;
    _cachedSettingsModel = null;

    final config = OverlayWindowConfig.fromJson(
      Map<String, dynamic>.from(args),
    );

    if (config.breaksCompleted != null) {
      final count = config.breaksCompleted!;
      try {
        if (sl.isRegistered<StatsService>()) {
          final service = sl<StatsService>();
          if (service.runtimeType.toString() == 'FakeStatsService') {
            (service as dynamic).updateBreaksCompleted(count);
          }
        }
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
    }

    final targetEndMs = config.targetEndTime;
    if (targetEndMs != null) {
      targetEndTime = DateTime.fromMillisecondsSinceEpoch(targetEndMs);
      startLocalTimer(_completeBreak);
    } else {
      targetEndTime = null;
      cancelTimer();
    }

    final newRemaining = config.remainingSeconds;
    if (newRemaining == 0 && remainingSeconds > 0) {
      _fadeController.reverse();
    }

    setState(() {
      _title = config.title;
      _tip = config.tip;
      durationSeconds = config.durationSeconds;
      if (targetEndMs == null) {
        remainingSeconds = config.remainingSeconds;
        remainingSecondsNotifier.value = remainingSeconds;
      }
      _overlayType = config.overlayType;
      _strictMode = config.strictMode;
      _enableAnimations = config.enableAnimations;
      _intensityLevel = config.intensityLevel;
      _showWellnessNotes = config.showWellnessNotes;
      _isInternalPreview = config.isPreview;
      if (config.breakType != null) {
        _breakTypeStr = config.breakType;
      }

      if (config.theme != null) {
        final String themeStr = config.theme!;
        _currentTheme = BreakTheme.values.firstWhere(
          (e) => e.name == themeStr,
          orElse: () => _currentTheme,
        );
      }
      if (config.classicImage != null) {
        _currentTemplate = config.classicImage!;
      }
      _breakTemplate = config.breakTemplate;
      _syncClassicEffects(_breakTemplate == 'classic' && _enableAnimations);
      _companionPetTheme = config.companionPetTheme;
      _clockFaceTextColorHex = config.clockFaceTextColorHex;
      _clockFaceBlurEnabled = config.clockFaceBlurEnabled;
      _customImagePath = config.customImagePath;
      if (config.exerciseTitle != null) {
        _exerciseTitle = config.exerciseTitle;
      }
      if (config.exerciseInstructions != null) {
        _exerciseInstructions = config.exerciseInstructions;
      }
      if (config.reminderType != null) {
        final newReminderType = config.reminderType;
        if (newReminderType != _reminderType) {
          _maxWarningSeconds = newRemaining;
        }
        _reminderType = newReminderType;
      }
      if (newRemaining > _maxWarningSeconds) {
        _maxWarningSeconds = newRemaining;
      }

      if (_overlayType == 'quickReminder' ||
          _overlayType == 'preBreakWarning') {
        _fadeController.duration = const Duration(milliseconds: 400);
        final dismissDelay =
            _overlayType == 'preBreakWarning' || _overlayType == 'quickReminder'
            ? const Duration(seconds: 2)
            : const Duration(seconds: 5);
        Future.delayed(dismissDelay, () {
          if (mounted &&
              (_overlayType == 'quickReminder' ||
                  _overlayType == 'preBreakWarning')) {
            _skipBreak();
          }
        });
      } else {
        _fadeController.duration = const Duration(milliseconds: 600);
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
    completeBreak(_isInternalPreview, _overlayType, _fadeController);
  }

  void _skipBreak() {
    skipBreak(_isInternalPreview, _overlayType, _fadeController);
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
      _bridge.invokeMethod('quitApp');
      return true;
    }

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _skipBreak();
      return true;
    }
    return false;
  }

  bool get _canDismiss =>
      _isInternalPreview ||
      (!_strictMode) ||
      _overlayType == 'quickReminder' ||
      _overlayType == 'preBreakWarning';

  void _handleTemplateError(FlutterErrorDetails details) {
    if (!_templateFailed) {
      debugPrint('Template $_breakTemplate failed: ${details.exception}');
      _templateFailed = true;
      ErrorToastService.showError(
        'Template "$_breakTemplate" could not be loaded.',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _breakTemplate = 'error_template';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    StandaloneBreakOverlay.onErrorCallbacks.remove(_handleTemplateError);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
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

    return PopScope(
      canPop: false,
      child: FadeTransition(
        opacity: _fadeController,
        child: Material(
          color:
              _overlayType == 'preBreakWarning' ||
                  _overlayType == 'quickReminder'
              ? Colors.black.withValues(alpha: 0.34)
              : Colors.black,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              final dy = details.delta.dy;
              if (_canDismiss && dy < -10) {
                _skipBreak();
              }
            },
            // We consume horizontal drag so it doesn't do anything (not strict, but prevents movement)
            onHorizontalDragUpdate: (details) {},
            child: RepaintBoundary(child: _buildBreakScreen()),
          ),
        ),
      ),
    );
  }

  BreakModel _buildBreakModel() {
    BreakType type;
    if (_breakTypeStr != null) {
      type = BreakType.values.firstWhere(
        (e) => e.name == _breakTypeStr,
        orElse: () => BreakType.long,
      );
    } else {
      type =
          _title.toUpperCase().contains('SHORT') ||
              _title.toUpperCase().contains('EYE')
          ? BreakType.short
          : BreakType.long;
    }
    return BreakModel(
      type: type,
      durationSeconds: durationSeconds,
      title: _title,
      tip: _tip,
    );
  }

  SettingsModel _buildSettingsModel() => SettingsModel(
    strictMode: _strictMode,
    enableAnimations: _enableAnimations,
    companionPetTheme: _companionPetTheme,
    breakTemplate: _breakTemplate,
    showExercisesInBreak: _showWellnessNotes,
    clockFaceTextColorHex: _clockFaceTextColorHex,
    clockFaceBlurEnabled: _clockFaceBlurEnabled,
    customImagePath: _customImagePath,
  );

  Widget _buildBreakScreen() {
    if (_overlayType == 'quickReminder' || _overlayType == 'preBreakWarning') {
      return QuickReminderOverlay(
        reminderType: _reminderType,
        overlayType: _overlayType,
        fadeAnimation: _fadeController,
        title: _title,
        durationSeconds: durationSeconds,
        allowFullPoster:
            _overlayType == 'quickReminder' && _allowFullPosterReminder,
      );
    }

    _cachedBreakModel ??= _buildBreakModel();
    _cachedSettingsModel ??= _buildSettingsModel();
    final breakInfo = _cachedBreakModel!;
    final settings = _cachedSettingsModel!;

    final total = durationSeconds;
    // Always pass the callback; templates use their own !settings.strictMode guard
    // to decide whether to render it. The global overlay button below is the
    // authoritative skip affordance and is controlled by _canDismiss independently.
    final VoidCallback onSkip = _skipBreak;

    return OverlayChrome(
      templateOwnsChrome: _templateOwnsChrome,
      isInternalPreview: _isInternalPreview,
      canDismiss: _canDismiss,
      breakInfo: breakInfo,
      exerciseTitle: _showWellnessNotes ? _exerciseTitle : null,
      intensityLevel: _intensityLevel,
      onSkip: onSkip,
      child: RepaintBoundary(
        child: ValueListenableBuilder<int>(
          valueListenable: remainingSecondsNotifier,
          builder: (_, remaining, _) => _buildTemplateWidget(
            breakInfo: breakInfo,
            settings: settings,
            remaining: remaining,
            total: total,
            onSkip: onSkip,
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateWidget({
    required BreakModel breakInfo,
    required SettingsModel settings,
    required int remaining,
    required int total,
    required VoidCallback? onSkip,
  }) {
    return BreakTemplateSwitcher(
      breakTemplate: _breakTemplate,
      breakInfo: breakInfo,
      settings: settings,
      remaining: remaining,
      total: total,
      onSkip: onSkip,
      currentTemplate: _currentTemplate,
      kenBurnsController: _kenBurnsController,
      exerciseTitle: _exerciseTitle,
      exerciseInstructions: _exerciseInstructions,
    );
  }

  bool get _allowFullPosterReminder {
    final settings = sl<SettingsRepository>().currentSettings;
    return allowFullPosterReminder(
      detectMeetings: settings.detectMeetings,
      calendarMeetingActive: sl<MeetingDetectionService>().isMeetingActive,
      detectVideoCalls: settings.detectVideoCalls,
      videoCallActive: sl<SmartDetectionService>().isVideoCallActive,
      presenting: sl<PresentationDetectionService>().isPresenting,
    );
  }

  bool get _templateOwnsChrome {
    // This prevents the global pill / close / swipe-hint from being stacked
    final isWindDown =
        _title.toUpperCase().contains('WIND DOWN') ||
        (_breakTypeStr == 'windDown');
    if (isWindDown) return true;
    return _kTemplatesWithChrome.contains(_breakTemplate) ||
        _breakTemplate == 'wind_down';
  }
}
