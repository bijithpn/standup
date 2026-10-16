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
  // Whether a quickReminder may take over the whole screen as a full poster.
  // Computed on the main engine — which has SettingsRepository and the
  // meeting/presentation detection services registered — and handed to
  // this overlay's own, separate Flutter isolate via
  // `OverlayWindowConfig.allowFullPoster`. This isolate only registers a
  // minimal set of services (see `overlayMain()`), so calling those
  // services directly from here throws every time (this used to crash the
  // whole overlay build, leaving a stuck black screen).
  bool _allowFullPoster = false;

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

  // True once the first real `updateOverlayData`/`getOverlayData` payload
  // has been applied. SimplePrefs alone can't tell this window whether it's
  // a full break screen or a brief quickReminder poster — that only comes
  // over the bridge — so guessing 'breakScreen' as a placeholder used to
  // flash the wrong, heavy full-break template (visible as a black-screen
  // jump) for every reminder before the real payload landed. Until this
  // flips true, render nothing instead of guessing wrong.
  bool _hasReceivedOverlayData = false;

  // Bumped on every `_applyOverlayData` call so each one's auto-dismiss
  // timer can tell whether it's still the *latest* payload by the time it
  // fires — see the dismissDelay `Future.delayed` below. Without this, an
  // earlier session's 2s dismiss timer could fire after a newer payload
  // has already landed (e.g. two reminders shown back-to-back on a reused,
  // warm engine) and force-hide a session it knows nothing about.
  int _overlayDataGeneration = 0;

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

    _currentTemplate = AppConstants.wellnessSlideshow.isNotEmpty
        ? AppConstants.wellnessSlideshow[Random().nextInt(
            AppConstants.wellnessSlideshow.length,
          )]
        : '';
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

    // Deferred until the first real overlay payload lands (see
    // `_hasReceivedOverlayData`) — fading in blank content and then
    // snapping to the real one looks worse than just waiting for it.

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

    _hasReceivedOverlayData = true;
    _overlayDataGeneration++;
    final myGeneration = _overlayDataGeneration;

    // A fresh overlay payload (e.g. swapping templates while previewing)
    // always means a fresh dismissible session — don't let a dismiss
    // attempt from a previous payload keep this one permanently stuck.
    isDismissing = false;

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
      _allowFullPoster = config.allowFullPoster;
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
        // Health reminders (quickReminder) and the pre-break warning are
        // two separate purposes and must not share one dismiss clock —
        // each gets its own fixed delay here, fully independent of
        // BreakTimerManager's targetEndTime/localTimer countdown used by
        // real breaks below.
        final capturedOverlayType = _overlayType;
        final dismissDelay = capturedOverlayType == 'quickReminder'
            ? AppConstants.healthReminderDismissDuration
            : const Duration(seconds: 2);
        Future.delayed(dismissDelay, () {
          if (mounted &&
              _overlayDataGeneration == myGeneration &&
              _overlayType == capturedOverlayType) {
            _skipBreak();
          }
        });
      } else {
        _fadeController.duration = const Duration(milliseconds: 600);
      }
    });

    // Now that we know what to render, start the fade-in — unless it's
    // already fully visible or mid-fade-in. The native side now keeps this
    // engine warm and reuses it for later shows instead of recreating it
    // each time (see `warmPool` in MainFlutterWindow.swift, the fix for
    // Preview's ~3s cold-start delay), so a later `updateOverlayData` can
    // land on a widget that already faded out from a previous session and
    // needs to fade back in — not just on a first-ever payload.
    if (_fadeController.status != AnimationStatus.forward &&
        _fadeController.value < 1) {
      _fadeController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_breakTemplate == 'classic' && _currentTemplate.isNotEmpty) {
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

    // Any key dismisses the overlay when it's allowed to be dismissed
    // (preview, non-strict mode, or a quick reminder/pre-break warning) —
    // don't force the user to sit through the full timer or hunt for the
    // one "correct" key. Bare modifier presses are ignored so they don't
    // eat a real shortcut before its companion key arrives.
    if (_canDismiss &&
        event is KeyDownEvent &&
        !_isModifierKey(event.logicalKey)) {
      _skipBreak();
      return true;
    }
    return false;
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.fn;
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
    if (!_initialized || !_hasReceivedOverlayData) {
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
          // A brief reminder should read as a light dimming of whatever's
          // already on screen, not an opaque takeover — low opacity (~0.25)
          // so the user's actual desktop/app stays visible underneath.
          color:
              _overlayType == 'preBreakWarning' ||
                  _overlayType == 'quickReminder'
              ? Colors.black.withValues(alpha: 0.25)
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
        allowFullPoster: _overlayType == 'quickReminder' && _allowFullPoster,
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
            onSkip: null, // OverlayChrome handles the authoritative skip button
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

  bool get _templateOwnsChrome {
    // Only full-screen custom routines (like wind_down) own their entire layout.
    // All other templates receive unified OverlayChrome (context pill, controls).
    final isWindDown =
        _title.toUpperCase().contains('WIND DOWN') ||
        (_breakTypeStr == 'windDown') ||
        _breakTemplate == 'wind_down';
    return isWindDown;
  }
}
