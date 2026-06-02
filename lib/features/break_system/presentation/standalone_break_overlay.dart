import 'dart:async' show Timer;

import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart';
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
  String _displayId = "Primary";
  double _displayWidth = 0;
  double _displayHeight = 0;
  int _screenId = 0;
  bool _strictMode = false;
  bool _enableAnimations = true;
  String _intensityLevel = 'standard';
  String? _reminderType;
  bool _isInternalPreview =
      false; // Flag to disable expensive animations during preview

  DateTime? _targetEndTime;
  Timer? _localTimer;

  String? _exerciseTitle;
  String? _exerciseInstructions;
  String _breakTemplate = 'minimal';
  String _companionPetTheme = 'grey_cat';

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _durationSeconds = widget.durationSeconds;
    _remainingSeconds = widget.durationSeconds;
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

    // Smoothly fade in
    _fadeController.forward();
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
        if (mounted) {
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
            _isInternalPreview = args['isPreview'] ?? false;

            // Display Context
            final displayId = args['displayId'] as String?;
            final bWidth = (args['boundsWidth'] as num?)?.toDouble() ?? 0;
            final bHeight = (args['boundsHeight'] as num?)?.toDouble() ?? 0;
            if (displayId != null) {
              _displayId = displayId;
              _displayWidth = bWidth;
              _displayHeight = bHeight;
            }

            if (args['theme'] != null) {
              final String themeStr = args['theme'];
              _currentTheme = BreakTheme.values.firstWhere(
                (e) => e.name == themeStr,
                orElse: () => _currentTheme,
              );
            }
            if (args['breakTemplate'] != null) {
              _breakTemplate = args['breakTemplate'];
            } else if (args['template'] != null) {
              _breakTemplate = args['template'];
            }
            _syncClassicEffects(
              _breakTemplate == 'classic' && _enableAnimations,
            );
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
              _reminderType = args['reminderType'];
            }

            // Auto-dismiss quick reminders after 2 seconds
            if (_overlayType == 'quickReminder') {
              _fadeController.duration = const Duration(milliseconds: 250);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _skipBreak();
              });
            }
          });
        }
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
      showExercisesInBreak: _exerciseTitle != null,
    );

    final total = _durationSeconds;
    final remaining = _remainingSeconds;
    Future<void> onSkip() async => _skipBreak();

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
        templateWidget = Stack(
          fit: StackFit.expand,
          children: [
            // Background Layer - Separated into its own RepaintBoundary to avoid UI invalidation
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _kenBurnsController,
                builder: (context, child) {
                  return _buildBackground();
                },
              ),
            ),

            // UI Content - Wrapped in RepaintBoundary to isolate from background animation
            SafeArea(
              child: RepaintBoundary(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Main content centered
                    _buildMainContent(),

                    const Spacer(),

                    // Footer
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        templateWidget,
        Positioned(
          top: 28,
          left: 28,
          child: SafeArea(
            child: BreakContextPill(
              breakInfo: breakInfo,
              exerciseTitle: _exerciseTitle,
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
        if (!_strictMode)
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
        if (!_strictMode)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: const IgnorePointer(
              child: SwipeToDismissHint(),
            ),
          ),
        if (_strictMode)
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

  Widget _buildQuickReminder() {
    final isPosture = _reminderType == 'posture';
    final isBreakStart = _reminderType == 'breakStart';
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
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: 10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBreakStart
                      ? CupertinoIcons.timer
                      : isPosture
                      ? CupertinoIcons.person_crop_circle_badge_checkmark
                      : CupertinoIcons.eye,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isBreakStart
                    ? 'Break Starts Soon'
                    : isPosture
                    ? 'Check Your Posture'
                    : 'Rest Your Eyes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isBreakStart
                    ? 'You have ${_remainingSeconds.clamp(0, 999)} seconds to save your work and pause cleanly.'
                    : isPosture
                    ? 'Sit up straight, relax your neck, and drop your shoulders.'
                    : 'Blink a few times and focus on something far away.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Text(
          _title.toUpperCase().contains('SHORT') ||
                  _title.toUpperCase().contains('EYE')
              ? 'Rest Your Eyes'
              : 'Time to Recharge',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 24),

        RepaintBoundary(
          child: Text(
            _formatTime(_remainingSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 160,
              fontWeight: FontWeight.w200,
              letterSpacing: -4,
              fontFamily: 'Inter',
              fontFeatures: [FontFeature.tabularFigures()],
              height: 1.0,
            ),
          ),
        ),

        const SizedBox(height: 24),

        Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Text(
            _tip,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              height: 1.5,
            ),
          ),
        ),

        if (_exerciseTitle != null && _exerciseInstructions != null)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: _buildExerciseCard(),
          ),

        if (_displayId.isNotEmpty && _displayId != "Primary")
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              _displayId,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('HH:mm').format(DateTime.now()),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
          if (true) _buildSkipButton(),
        ],
      ),
    );
  }

  Widget _buildExerciseCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.heart_fill,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Exercise: ${_exerciseTitle!}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _exerciseInstructions!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final screenW = _displayWidth > 0 ? _displayWidth : 1920.0;
    final screenH = _displayHeight > 0 ? _displayHeight : 1080.0;

    // Using a RepaintBoundary here ensures background animations don't trigger UI rebuilds
    return RepaintBoundary(child: _buildThemeContent(screenW, screenH));
  }

  Widget _buildThemeContent(double screenW, double screenH) {
    switch (_currentTheme) {
      case BreakTheme.image:
        return Stack(
          fit: StackFit.expand,
          children: [
            // Optimized image loading
            // Only use transform if NOT in preview to save 100% of that CPU cost
            (_isInternalPreview || !_enableAnimations)
                ? Image.asset(
                    _currentTemplate,
                    fit: BoxFit.cover,
                    cacheWidth: screenW.toInt().clamp(100, 1920),
                    cacheHeight: screenH.toInt().clamp(100, 1080),
                  )
                : Transform.scale(
                    scale: 1.05 + (0.1 * _kenBurnsController.value),
                    child: Image.asset(
                      _currentTemplate,
                      fit: BoxFit.cover,
                      cacheWidth: screenW.toInt().clamp(100, 1920),
                      cacheHeight: screenH.toInt().clamp(100, 1080),
                      filterQuality: FilterQuality.low,
                    ),
                  ),

            // Speed optimization: Use simpler solid color with opacity instead of multi-stop gradient when possible
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ],
        );

      case BreakTheme.sunset:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: const [Color(0xFFFF512F), Color(0xFFDD2476)],
              stops: [
                0.0,
                0.5 +
                    (0.1 *
                        (_isInternalPreview ? 0 : _kenBurnsController.value)),
              ],
            ),
          ),
        );

      case BreakTheme.nebula:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius:
                  1.2 +
                  (0.3 * (_isInternalPreview ? 0 : _kenBurnsController.value)),
              colors: const [Color(0xFF6441A5), Color(0xFF2a0845)],
            ),
          ),
        );

      case BreakTheme.midnight:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Color(0xFF000428), Color(0xFF004e92)],
            ),
          ),
        );

      case BreakTheme.cyberpunk:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [Color(0xFF00F260), Color(0xFF0575E6)],
              stops: [
                0.0,
                0.6 +
                    (0.1 *
                        (_isInternalPreview ? 0 : _kenBurnsController.value)),
              ],
            ),
          ),
        );

      case BreakTheme.zen:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [Color(0xFFe6e9f0), Color(0xFFeef1f5)],
            ),
          ),
        );

      case BreakTheme.ocean:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                0.0,
                0.5 +
                    (0.05 *
                        (_isInternalPreview ? 0 : _kenBurnsController.value)),
                1.0,
              ],
              colors: const [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ],
            ),
          ),
        );
      case BreakTheme.forest:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              stops: [
                0.0,
                0.5 +
                    (0.05 *
                        (_isInternalPreview ? 0 : _kenBurnsController.value)),
                1.0,
              ],
              colors: const [
                Color(0xFF134E5E),
                Color(0xFF71B280),
                Color(0xFF134E5E),
              ],
            ),
          ),
        );
      case BreakTheme.minimal:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius:
                  0.8 +
                  (0.2 * (_isInternalPreview ? 0 : _kenBurnsController.value)),
              colors: const [Color(0xFF1A1A1A), Color(0xFF050505)],
            ),
          ),
        );
    }
  }

  Widget _buildSkipButton() {
    return SkipBreakButton(onSkip: _skipBreak);
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
