import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'dart:math';
import 'package:breakmate/core/ipc/ipc_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/core/ipc/overlay_window_config.dart';
import 'package:breakmate/core/services/error_toast_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_theme.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_timer_manager.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_keyboard_handler.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_content.dart';
import 'package:breakmate/features/break_system/presentation/standalone_overlay/break_overlay_config_loader.dart';

export 'package:breakmate/features/break_system/presentation/standalone_overlay/break_theme.dart';

class StandaloneBreakOverlay extends StatefulWidget {
  final String title;
  final String message;
  final int initialDurationSeconds;

  static final List<void Function(FlutterErrorDetails)> onErrorCallbacks = [];

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
  static const MethodChannel _bridge = MethodChannel(
    'com.breakmate.desktop/bridge',
  );

  late OverlayWindowConfig _config;
  late String _currentTemplate;
  late BreakTheme _currentTheme;
  late AnimationController _kenBurnsController;
  late AnimationController _fadeController;
  bool _classicEffectsRunning = false;

  int _screenId = 0;
  int _maxWarningSeconds = 10;
  bool _templateFailed = false;

  BreakModel? _cachedBreakModel;
  SettingsModel? _cachedSettingsModel;

  bool _initialized = false;
  bool _hasReceivedOverlayData = false;
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
    StandaloneBreakOverlay.onErrorCallbacks.add(_handleTemplateError);
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

    isDismissing = false;
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
    if (newRemaining == 0 && remainingSeconds > 0) {
      _fadeController.reverse();
    }

    setState(() {
      _config = config;
      durationSeconds = config.durationSeconds;
      // Show the right time on this very frame. Waiting for the timer's first
      // tick left the previous break's countdown on screen for a second or two.
      final end = targetEndTime;
      remainingSeconds = end == null
          ? config.remainingSeconds
          : end
                .difference(DateTime.now())
                .inSeconds
                .clamp(0, config.durationSeconds);
      remainingSecondsNotifier.value = remainingSeconds;
      if (config.theme != null) {
        _currentTheme = BreakTheme.values.firstWhere(
          (e) => e.name == config.theme,
          orElse: () => _currentTheme,
        );
      }
      if (config.classicImage != null) {
        _currentTemplate = config.classicImage!;
      }
      _syncClassicEffects(
        config.breakTemplate == 'classic' && config.enableAnimations,
      );

      if (config.reminderType != null &&
          config.reminderType != _config.reminderType) {
        _maxWarningSeconds = newRemaining;
      }
      if (newRemaining > _maxWarningSeconds) {
        _maxWarningSeconds = newRemaining;
      }

      final isQuick = _config.overlayType == 'quickReminder';
      final isPreBreak = _config.overlayType == 'preBreakWarning';
      _fadeController.duration = Duration(
        milliseconds: (isQuick || isPreBreak) ? 400 : 600,
      );

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
    if (_config.breakTemplate == 'classic' && _currentTemplate.isNotEmpty) {
      precacheImage(AssetImage(_currentTemplate), context);
    }
  }

  void _setupBridge() {
    _bridge.setMethodCallHandler((call) async {
      if (call.method == 'updateOverlayData') {
        _applyOverlayData(call.arguments as Map);
      } else if (call.method == 'resetOverlay') {
        // Engine is kept warm between breaks: drop the last break's state so
        // its time/content never shows before the next data arrives.
        if (mounted) {
          cancelTimer();
          targetEndTime = null;
          _fadeController.value = 0;
          setState(() {
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

  void _syncClassicEffects(bool enabled) {
    if (_classicEffectsRunning == enabled) return;
    _classicEffectsRunning = enabled;
    if (enabled) {
      _kenBurnsController.repeatUnlessReducedMotion(
        reverse: true,
        staticValue: 0,
      );
    } else {
      _kenBurnsController.stop();
    }
  }

  void _completeBreak() =>
      completeBreak(_config.isPreview, _config.overlayType, _fadeController);
  void _skipBreak() =>
      skipBreak(_config.isPreview, _config.overlayType, _fadeController);
  void _quitApp() => _bridge.invokeMethod('quitApp');

  bool get _canDismiss =>
      _config.isPreview ||
      (!_config.strictMode) ||
      _config.overlayType == 'quickReminder' ||
      _config.overlayType == 'preBreakWarning';

  void _handleTemplateError(FlutterErrorDetails details) {
    if (!_templateFailed) {
      debugPrint(
        'Template ${_config.breakTemplate} failed: ${details.exception}',
      );
      _templateFailed = true;
      ErrorToastService.showError(
        'Template "${_config.breakTemplate}" could not be loaded.',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _config = _config.copyWith(breakTemplate: 'error_template');
            _cachedSettingsModel = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    StandaloneBreakOverlay.onErrorCallbacks.remove(_handleTemplateError);
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

    _cachedBreakModel ??= _config.toBreakModel(durationSeconds);
    _cachedSettingsModel ??= _config.toSettingsModel();

    final isDimmedOverlay =
        _config.overlayType == 'preBreakWarning' ||
        _config.overlayType == 'quickReminder';

    return PopScope(
      canPop: false,
      child: FadeTransition(
        opacity: _fadeController,
        child: Material(
          color: _config.overlayType == 'preBreakWarning'
              ? Colors.transparent
              : (isDimmedOverlay
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black),
          child: BreakOverlayKeyboardHandler(
            canDismiss: _canDismiss,
            onSkip: _skipBreak,
            onQuitApp: _quitApp,
            child: RepaintBoundary(
              child: BreakOverlayContent(
                config: _config,
                fadeAnimation: _fadeController,
                remainingSecondsNotifier: remainingSecondsNotifier,
                onSkip: _skipBreak,
                canDismiss: _canDismiss,
                breakInfo: _cachedBreakModel!,
                settings: _cachedSettingsModel!,
                currentTemplate: _currentTemplate,
                kenBurnsController: _kenBurnsController,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
