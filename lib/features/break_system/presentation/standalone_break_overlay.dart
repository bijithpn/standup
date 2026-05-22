import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/native/macos_bridge.dart';

enum BreakTheme { image, ocean, forest, minimal }

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
    'com.breakmate.macos/bridge',
  );

  late String _currentTemplate;
  late BreakTheme _currentTheme;
  late AnimationController _kenBurnsController;
  late AnimationController _fadeController;

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
  bool _isInternalPreview = false; // Flag to disable expensive animations during preview

  String? _exerciseTitle;
  String? _exerciseInstructions;

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
    // Fallback theme initialized here; will be overwritten immediately by bridge args if provided.

    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _setupBridge();
  }

  void _setupBridge() {
    _bridge.setMethodCallHandler((call) async {
      if (call.method == 'updateOverlayData') {
        final args = call.arguments as Map;
        if (mounted) {
          setState(() {
            _title = args['title'] ?? _title;
            _tip = args['tip'] ?? _tip;
            _durationSeconds = args['durationSeconds'] ?? _durationSeconds;
            _remainingSeconds = args['remainingSeconds'] ?? _remainingSeconds;
            _overlayType = args['type'] ?? _overlayType;
            _strictMode = args['strictMode'] ?? _strictMode;
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
            if (args['template'] != null) {
              _currentTemplate = args['template'];
            }
            if (args.containsKey('exerciseTitle')) {
              _exerciseTitle = args['exerciseTitle'];
            }
            if (args.containsKey('exerciseInstructions')) {
              _exerciseInstructions = args['exerciseInstructions'];
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

  @override
  void dispose() {
    _kenBurnsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: FadeTransition(
        opacity: _fadeController,
        child: RepaintBoundary(
          child: _buildBreakScreen(),
        ),
      ),
    );
  }

  Widget _buildBreakScreen() {
    return Stack(
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
            fontFamily: 'Satoshi',
          ),
        ),
        const SizedBox(height: 24),

        Text(
          _formatTime(_remainingSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 160,
            fontWeight: FontWeight.w200,
            letterSpacing: -4,
            fontFamily: 'Satoshi',
            fontFeatures: [FontFeature.tabularFigures()],
            height: 1.0,
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
              fontFamily: 'Satoshi',
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
                fontFamily: 'Satoshi',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 30,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('HH:mm').format(DateTime.now()),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Satoshi',
            ),
          ),
          if (!_strictMode) _buildSkipButton(),
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
                  fontFamily: 'Satoshi',
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
              fontFamily: 'Satoshi',
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
    
    switch (_currentTheme) {
      case BreakTheme.image:
        return Stack(
          fit: StackFit.expand,
          children: [
            // Optimized image loading with cache sizing
            Transform.scale(
              scale: _isInternalPreview ? 1.0 : (1.05 + (0.1 * _kenBurnsController.value)),
              child: Image.asset(
                _currentTemplate, 
                fit: BoxFit.cover,
                cacheWidth: screenW.toInt(),
                cacheHeight: screenH.toInt(),
                filterQuality: _isInternalPreview ? FilterQuality.none : FilterQuality.low, 
              ),
            ),
            
            // Simulating blur/depth with a complex gradient instead of BackdropFilter
            // This is SIGNIFICANTLY faster than BackdropFilter on high-res displays
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
      case BreakTheme.ocean:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5 + (0.05 * _kenBurnsController.value), 1.0],
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
              stops: [0.0, 0.5 + (0.05 * _kenBurnsController.value), 1.0],
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
              radius: 0.8 + (0.2 * _kenBurnsController.value),
              colors: const [Color(0xFF1A1A1A), Color(0xFF050505)],
            ),
          ),
        );
    }
  }

  Widget _buildSkipButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => MacOSBridge.skipBreak(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Skip Break',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Satoshi',
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.arrow_right,
                size: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
