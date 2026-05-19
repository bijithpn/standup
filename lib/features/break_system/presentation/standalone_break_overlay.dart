import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/native/macos_bridge.dart';

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
  late AnimationController _breathingController;
  late AnimationController _kenBurnsController;
  
  String _title = "Time for a Break";
  int _durationSeconds = 300;
  int _remainingSeconds = 300;
  String _overlayType = 'breakScreen';
  int _screenId = 0;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _durationSeconds = widget.durationSeconds;
    _remainingSeconds = widget.durationSeconds;
    
    _pageController = PageController();
    _startSlideshow();
    
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _setupBridge();
  }

  void _setupBridge() {
    _bridge.setMethodCallHandler((call) async {
      if (call.method == 'updateOverlayData') {
        final args = call.arguments as Map;
        if (mounted) {
          setState(() {
            _title = args['title'] ?? _title;
            _durationSeconds = args['durationSeconds'] ?? _durationSeconds;
            _remainingSeconds = args['remainingSeconds'] ?? _remainingSeconds;
            _overlayType = args['type'] ?? _overlayType;
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
    _breathingController.dispose();
    _kenBurnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_overlayType == 'flashNotification') {
      return _buildFlashNotification();
    }
    
    return _buildBreakScreen();
  }

  Widget _buildFlashNotification() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.accessibility_new, color: Colors.blueAccent, size: 64),
              const SizedBox(height: 24),
              Text(
                "Posture Reminder",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Sit up straight and take a deep breath",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer
          AnimatedBuilder(
            animation: _kenBurnsController,
            builder: (context, child) {
              return PageView.builder(
                controller: _pageController,
                itemCount: AppConstants.wellnessSlideshow.length,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return Transform.scale(
                    scale: 1.1 + (0.1 * _kenBurnsController.value),
                    child: Image.asset(
                      AppConstants.wellnessSlideshow[index],
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.5),
                      colorBlendMode: BlendMode.darken,
                    ),
                  );
                },
              );
            },
          ),

          // UI Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                if (_screenId != 0)
                   Text(
                    "Display $_screenId",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                  ),
                const Spacer(),
                
                // Breathing Assistant
                Center(
                  child: AnimatedBuilder(
                    animation: _breathingController,
                    builder: (context, child) {
                      return Container(
                        width: 220 + (60 * _breathingController.value),
                        height: 220 + (60 * _breathingController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent.withValues(alpha: 0.1 + (0.2 * _breathingController.value)),
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _breathingController.value < 0.5 ? "Inhale" : "Exhale",
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w200),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const Spacer(),
                
                // Action area
                Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        label: "Skip",
                        onPressed: () => MacOSBridge.hideOverlay(),
                      ),
                      const SizedBox(width: 40),
                      CircularProgressIndicator(
                        value: _durationSeconds > 0 ? _remainingSeconds / _durationSeconds : 0.0,
                        strokeWidth: 8,
                        backgroundColor: Colors.white10,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 40),
                      _ActionButton(
                        label: "Done",
                        primary: true,
                        onPressed: () => MacOSBridge.hideOverlay(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: primary ? Colors.blueAccent : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
