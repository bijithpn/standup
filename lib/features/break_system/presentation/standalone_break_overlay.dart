import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/features/break_system/presentation/widgets/break_activity_graph.dart';

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

class _StandaloneBreakOverlayState extends State<StandaloneBreakOverlay> with TickerProviderStateMixin {
  static const MethodChannel _bridge = MethodChannel('com.breakmate.macos/bridge');
  
  late PageController _pageController;
  int _currentSlide = 0;
  Timer? _slideshowTimer;
  late AnimationController _kenBurnsController;
  late AnimationController _fadeController;
  
  String _title = "Time for a Break";
  String _tip = "Take a moment to recharge.";
  int _durationSeconds = 300;
  int _remainingSeconds = 300;
  String _overlayType = 'breakScreen';
  int _screenId = 0;
  bool _strictMode = false;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _durationSeconds = widget.durationSeconds;
    _remainingSeconds = widget.durationSeconds;
    
    _pageController = PageController();
    _startSlideshow();
    
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

  void _startSlideshow() {
    _slideshowTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      setState(() {
        _currentSlide = (_currentSlide + 1) % AppConstants.wellnessSlideshow.length;
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

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
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
        child: _buildBreakScreen(),
      ),
    );
  }


  Widget _buildBreakScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Layer
        AnimatedBuilder(
          animation: _kenBurnsController,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: AppConstants.wellnessSlideshow.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Transform.scale(
                      scale: 1.1 + (0.1 * _kenBurnsController.value),
                      child: Image.asset(
                        AppConstants.wellnessSlideshow[index],
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
              ],
            );
          },
        ),

        // UI Content
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Timer and Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 100,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -2,
                        fontFamily: 'Satoshi',
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title.toUpperCase().contains('SHORT') || _title.toUpperCase().contains('EYE')
                              ? 'Rest Your Eyes, Refresh Your Mind'
                              : 'Step Away, Recharge Completely',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              fontFamily: 'Satoshi',
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _tip,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Satoshi',
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_screenId != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    "Display $_screenId",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12, fontFamily: 'Satoshi'),
                  ),
                ),
                
              const Spacer(),
              
              // Graph Area
              Column(
                children: [
                  const BreakActivityGraph(
                    dataPoints: [2, 4, 3, 6, 5, 8, 7], // Real stats not easily accessible in isolated overlay
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Break alert!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                  Text(
                    "Let's keep that streak going.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ],
              ),
              
              const Spacer(flex: 2),
              
              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      DateFormat('HH:mm').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!_strictMode)
                      _buildSkipButton(),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkipButton() {
    return GestureDetector(
      onTap: () => MacOSBridge.hideOverlay(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Skip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.arrow_right, size: 12, color: Colors.white.withValues(alpha: 0.8)),
          ],
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
