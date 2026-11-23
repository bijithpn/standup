import 'dart:convert';
import 'package:breakmate/core/services/simple_prefs.dart';
import 'package:breakmate/features/settings/experience_preferences.dart';
import 'package:breakmate/shared/utils/accessibility_preferences.dart';
import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'package:breakmate/core/ipc/ipc_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_system/presentation/widgets/skip_reason_picker.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_timer_manager.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_keyboard_handler.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_content.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_config_loader.dart';

/// Root widget of the separate overlay window/engine; renders break, pre-break warning and quick reminder from data pushed by the main app.
class StandaloneBreakOverlay extends StatefulWidget {
  final String title;
  final String message;
  final int initialDurationSeconds;

  const StandaloneBreakOverlay({
    super.key,
    this.title = "Time for a Break",
    this.message = "Take a moment to stretch and breathe",
    this.initialDurationSeconds = 60,
  });

  @override
  State<StandaloneBreakOverlay> createState() => _StandaloneBreakOverlayState();
}

class _StandaloneBreakOverlayState extends State<StandaloneBreakOverlay>
    with TickerProviderStateMixin, BreakTimerManager {
  // Native bridge: delivers overlay data/lifecycle calls from the main app and takes quit/dismiss requests back.
  static const MethodChannel _bridge = MethodChannel(
    'com.breakmate.desktop/bridge',
  );

  late OverlayWindowConfig _config;
  ExperiencePreferences _experience = const ExperiencePreferences();
  late AnimationController _fadeController;

  int _screenId = 0;
  int _maxWarningSeconds = 10;

  BreakModel? _cachedBreakModel;
  SettingsModel? _cachedSettingsModel;

  bool _initialized = false;
  // The overlay stays blank until the first data arrives; native polls this via "isReady" before showing the window.
  bool _hasReceivedOverlayData = false;
  // Bumps on each data push so stale delayed callbacks (quick-reminder auto-dismiss) can detect they were superseded.
  int _overlayDataGeneration = 0;

  @override
  void initState() {
    super.initState();
    durationSeconds = widget.initialDurationSeconds;
    remainingSeconds = widget.initialDurationSeconds;

    _config = BreakOverlayConfigLoader.loadFromPrefs(
      defaultTitle: widget.title,
      defaultMessage: widget.message,
      defaultDurationSeconds: widget.initialDurationSeconds,
    );
    try {
      _experience = ExperiencePreferences.fromMap(
        jsonDecode(SimplePrefs.instance.getString('experience_preferences')),
      );
    } catch (_) {}
    AppMotion.reduceMotion = _config.reduceMotion || !_config.enableAnimations;
    _initialized = true;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _setupBridge();
    _loadInitialData();
  }

  // Pulls data that was set before this engine was ready to receive "updateOverlayData".
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

  /// Applies a new config from the main app; the end time is wall-clock based so the countdown stays correct if updates are late.
  void _applyOverlayData(Map args) {
    if (!mounted) return;

    if (args.containsKey('experience')) {
      _experience = ExperiencePreferences.fromMap(args['experience']);
    }
    _hasReceivedOverlayData = true;
    _overlayDataGeneration++;
    final myGeneration = _overlayDataGeneration;

    isDismissing = false;
    completing.value = false;
    lookedAway = false;
    _cachedBreakModel = null;
    _cachedSettingsModel = null;

    final config = OverlayWindowConfig.fromJson(stringKeyedMap(args));
    BreakOverlayConfigLoader.updateStatsIfNeeded(config);

    final targetEndMs = config.targetEndTime;
    if (targetEndMs != null) {
      targetEndTime = DateTime.fromMillisecondsSinceEpoch(targetEndMs);
      startLocalTimer(_completeBreak);
    } else {
      targetEndTime = null;
      cancelTimer();
    }

    final newRemaining = config.remainingSeconds;
    // Main app signalled the end of the break; fade out.
    if (newRemaining == 0 && remainingSeconds > 0) {
      _fadeController.reverse();
    }

    setState(() {
      _config = config;
      AppMotion.reduceMotion = config.reduceMotion || !config.enableAnimations;
      durationSeconds = config.durationSeconds;

      final end = targetEndTime;
      remainingSeconds = end == null
          ? config.remainingSeconds
          : end
                .difference(DateTime.now())
                .inSeconds
                .clamp(0, config.durationSeconds);
      remainingSecondsNotifier.value = remainingSeconds;
      if (config.reminderType != null &&
          config.reminderType != _config.reminderType) {
        _maxWarningSeconds = newRemaining;
      }
      if (newRemaining > _maxWarningSeconds) {
        _maxWarningSeconds = newRemaining;
      }

      final isQuick = _config.overlayType == 'quickReminder';
      final isPreBreak = _config.overlayType == 'preBreakWarning';
      _fadeController.duration = prefersReducedMotion
          ? Duration.zero
          : Duration(milliseconds: (isQuick || isPreBreak) ? 400 : 600);

      if (isQuick) {
        final capturedType = _config.overlayType;
        Future.delayed(AppConstants.healthReminderDismissDuration, () {
          if (mounted &&
              _overlayDataGeneration == myGeneration &&
              _config.overlayType == capturedType) {
            _skipBreak();
          }
        });
      }
    });

    if (_fadeController.status != AnimationStatus.forward &&
        _fadeController.value < 1) {
      _fadeController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion) _fadeController.duration = Duration.zero;
  }

  // Native -> overlay calls: updateOverlayData, isReady, resetOverlay (reuse the window for the next break), setScreenInfo.
  void _setupBridge() {
    _bridge.setMethodCallHandler((call) async {
      if (call.method == 'updateOverlayData') {
        _applyOverlayData(call.arguments as Map);
      } else if (call.method == 'isReady') {
        return mounted && _initialized && _hasReceivedOverlayData;
      } else if (call.method == 'resetOverlay') {
        if (mounted) {
          cancelTimer();
          targetEndTime = null;
          _fadeController.value = 0;
          setState(() {
            _askingReason = false;
            _hasReceivedOverlayData = false;
            _cachedBreakModel = null;
            _cachedSettingsModel = null;
          });
        }
      } else if (call.method == 'setScreenInfo') {
        final args = call.arguments as Map;
        if (mounted) {
          setState(() => _screenId = args['id'] ?? _screenId);
        }
      }
    });
  }

  void _completeBreak() =>
      completeBreak(_config.isPreview, _config.overlayType, _fadeController);
  bool _askingReason = false;

  void _skipBreak() {
    if (_askingReason) return;
    final isRealBreak =
        !_config.isPreview && _config.overlayType == 'breakScreen';
    if (_config.askSkipReason && isRealBreak) {
      setState(() => _askingReason = true);
      return;
    }
    skipBreak(_config.isPreview, _config.overlayType, _fadeController);
  }

  void _skipWithReason(String reason) {
    setState(() => _askingReason = false);
    skipBreak(
      _config.isPreview,
      _config.overlayType,
      _fadeController,
      reason: reason,
    );
  }

  void _snoozeBreak() => snoozeBreak(_fadeController);
  void _quitApp() => _bridge.invokeMethod('quitApp');

  bool get _isCompact =>
      _config.overlayType == 'breakScreen' && _config.windowMode == 'compact';

  // Strict mode only locks real breaks; reminders and previews can always be dismissed.
  bool get _canDismiss =>
      _config.isPreview ||
      (!_config.strictMode && !_config.skipLocked) ||
      _config.overlayType == 'quickReminder';

  @override
  void dispose() {
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

    _cachedBreakModel ??= _config.toBreakModel(durationSeconds);
    _cachedSettingsModel ??= _config.toSettingsModel().copyWith(
      experience: _experience,
    );

    final isDimmedOverlay =
        _config.overlayType == 'preBreakWarning' ||
        _config.overlayType == 'quickReminder';

    final palette = BreakPalette.forMode(
      _cachedSettingsModel!.overlayThemeMode,
      MediaQuery.platformBrightnessOf(context),
    );

    final media = MediaQuery.of(context);
    return MediaQuery(
      data: accessibleMediaData(
        media,
        _cachedSettingsModel!,
        legacyLargeScale: 1.35,
      ),
      child: PopScope(
        canPop: false,
        child: BreakPaletteScope(
          palette: palette,
          child: FadeTransition(
            opacity: _fadeController,
            child: Material(
              color: _config.overlayType == 'preBreakWarning' || _isCompact
                  ? Colors.transparent
                  : (isDimmedOverlay
                        ? Colors.black.withValues(alpha: 0.25)
                        : palette.canvas),
              child: BreakOverlayKeyboardHandler(
                canDismiss: _canDismiss && !_askingReason,
                onSkip: _skipBreak,
                onQuitApp: _quitApp,
                child: RepaintBoundary(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: completing,
                    builder: (_, done, child) =>
                        BreakCompletionScope(completing: done, child: child!),
                    child: TickerMode(
                      enabled:
                          !(media.disableAnimations ||
                              _config.reduceMotion ||
                              !_config.enableAnimations),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          BreakOverlayContent(
                            config: _config,
                            fadeAnimation: _fadeController,
                            remainingSecondsNotifier: remainingSecondsNotifier,
                            onSkip: _skipBreak,
                            onSnooze: _snoozeBreak,
                            canDismiss: _canDismiss,
                            breakInfo: _cachedBreakModel!,
                            settings: _cachedSettingsModel!,
                            lookedAway: lookedAway,
                            onLookedAway: () =>
                                setState(() => lookedAway = true),
                          ),
                          if (_askingReason)
                            SkipReasonPicker(
                              onReason: _skipWithReason,
                              onCancel: () =>
                                  setState(() => _askingReason = false),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
