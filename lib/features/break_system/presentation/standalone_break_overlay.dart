import 'dart:async' show Timer;

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
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

class StandaloneBreakOverlay extends StatefulWidget {
  final String title;
  final String message;
  final int durationSeconds;

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

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _durationSeconds = widget.durationSeconds;
    _remainingSeconds = widget.durationSeconds;

    // Resolve user's actual selected template and settings from SettingsRepository on startup
    try {
      final settings = sl<SettingsRepository>().currentSettings;
      _breakTemplate = settings.breakTemplate;
      _companionPetTheme = settings.companionPetTheme;
      _showWellnessNotes = settings.showExercisesInBreak;
      _strictMode = settings.strictMode;
      _enableAnimations = settings.enableAnimations;
      _intensityLevel = settings.intensityLevel;
    } catch (_) {
      // Fallback to defaults
    }

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

    // Smoothly fade in
    _fadeController.forward();
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

      // Auto-dismiss quick reminders after 5 seconds (breakStart gets more time)
      if (_overlayType == 'quickReminder') {
        _fadeController.duration = const Duration(milliseconds: 400);
        final dismissDelay = _reminderType == 'breakStart'
            ? Duration(seconds: _remainingSeconds.clamp(5, 30))
            : const Duration(seconds: 5);
        Future.delayed(dismissDelay, () {
          if (mounted && _overlayType == 'quickReminder') _skipBreak();
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
            _fadeController.reverse();
          }
          setState(() {
            _remainingSeconds = newRemaining;
          });
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

  void _skipBreak() {
    // Reverse fade for a smooth exit, then call the native bridge
    _fadeController.reverse().then((_) {
      if (_isInternalPreview) {
        // If it's a preview, just hide the overlay without notifying
        // the main engine or recording a skipped break in the DB.
        _bridge.invokeMethod('hideOverlay', {'restoreMainWindow': true});
      } else {
        NativeBridge.skipBreak();
      }
    });
  }

  @override
  void dispose() {
    _localTimer?.cancel();
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
        color: _overlayType == 'quickReminder'
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            // If dragging up, dismiss the overlay completely (only if not in strict mode).
            if (!_strictMode && details.primaryDelta! < -10) {
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
    if (_overlayType == 'quickReminder') {
      return _buildQuickReminder();
    }

    final breakInfo = BreakModel(
      type:
          _title.toUpperCase().contains('SHORT') ||
              _title.toUpperCase().contains('EYE')
          ? BreakType.short
          : BreakType.long,
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
    );

    final total = _durationSeconds;
    final remaining = _remainingSeconds;
    // Only provide a live skip callback when not in strict mode.
    final VoidCallback? onSkip = _strictMode ? null : _skipBreak;

    Widget templateWidget;
    switch (_breakTemplate) {
      case 'classic':
        templateWidget = ClassicSlideshowTemplate(
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
        break;
      case 'companion':
        templateWidget = CompanionInteractiveTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'zen':
        templateWidget = ZenModeTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'hud':
        templateWidget = ProductivityHudTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'floating':
        templateWidget = SoftFloatingWidgetTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'activities':
        templateWidget = ActivitiesBreakTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      case 'minimal':
        templateWidget = MinimalFocusTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
        break;
      default:
        templateWidget = MinimalFocusTemplate(
          breakInfo: breakInfo,
          settings: settings,
          remainingSeconds: remaining,
          totalSeconds: total,
          onSkip: onSkip,
        );
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        templateWidget,
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
        if (!_strictMode && !_templateOwnsChrome)
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
        if (!_strictMode && !_templateOwnsChrome)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: SwipeToDismissHint()),
          ),
        if (_strictMode && !_templateOwnsChrome)
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

  bool get _templateOwnsChrome {
    // All named templates self-manage their chrome (top rail, skip, hints).
    // This prevents the global pill / close / swipe-hint from being stacked
    // on top of template-owned header and footer areas.
    return _breakTemplate == 'minimal' ||
        _breakTemplate == 'activities' ||
        _breakTemplate == 'companion' ||
        _breakTemplate == 'zen' ||
        _breakTemplate == 'hud' ||
        _breakTemplate == 'floating' ||
        _breakTemplate == 'classic';
  }

  Widget _buildQuickReminder() {
    final isPosture = _reminderType == 'posture';
    final isBreakStart = _reminderType == 'breakStart';

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
    final secs = _remainingSeconds.clamp(0, 999);
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

    final String dynamicMessage = isPosture
        ? 'Wrap up what you\'re doing. A posture break\nis coming in just a moment.'
        : isEye
        ? 'Wrap up what you\'re doing. An eye break\nis coming in just a moment.'
        : 'Wrap up what you\'re doing. A break\nis coming in just a moment.';

    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: Container(
          width: 420,
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.1),
                blurRadius: 48,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceCard,
                AppTheme.surfaceCard.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top label pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      labelText,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(mainIcon, color: AppTheme.accent, size: 32),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Break Starts Soon',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                dynamicMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Countdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$secs',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'Inter',
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'seconds remaining',
                      style: TextStyle(
                        color: AppTheme.accent.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: _maxWarningSeconds > 0
                            ? (secs / _maxWarningSeconds).clamp(0.0, 1.0)
                            : 0.0,
                        backgroundColor: AppTheme.accent.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.accent,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tips row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWarningTip(
                    isPosture
                        ? CupertinoIcons.arrow_up_to_line
                        : CupertinoIcons.eye_fill,
                    isPosture ? 'Sit up straight' : 'Look far away',
                  ),
                  const SizedBox(width: 16),
                  _buildWarningTip(
                    CupertinoIcons.hand_raised,
                    'Save your work',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningTip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
