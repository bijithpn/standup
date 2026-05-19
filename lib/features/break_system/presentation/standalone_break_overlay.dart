import 'dart:async';
import 'package:flutter/material.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/native/macos_bridge.dart';

class StandaloneBreakOverlay extends StatefulWidget {
  final String title;
  final String message;
  final int durationSeconds;
  final int remainingSeconds;

  const StandaloneBreakOverlay({
    super.key,
    this.title = "Time for a Break",
    this.message = "Take a moment to stretch and breathe",
    this.durationSeconds = 300,
    this.remainingSeconds = 300,
  });

  @override
  State<StandaloneBreakOverlay> createState() => _StandaloneBreakOverlayState();
}

class _StandaloneBreakOverlayState extends State<StandaloneBreakOverlay> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentSlide = 0;
  Timer? _slideshowTimer;
  late AnimationController _breathingController;
  late AnimationController _kenBurnsController;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer with Ken Burns Effect
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
                      color: Colors.black.withValues(alpha: 0.6),
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
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                
                // Breathing Assistant
                SizedBox(
                  height: 300,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _breathingController,
                      builder: (context, child) {
                        return Container(
                          width: 200 + (50 * _breathingController.value),
                          height: 200 + (50 * _breathingController.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withValues(alpha: 0.2 + (0.3 * _breathingController.value)),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3 * _breathingController.value),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _breathingController.value < 0.5 ? "Inhale" : "Exhale",
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Timer / Action area
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        label: "Skip",
                        onPressed: () async {
                          await MacOSBridge.hideOverlay();
                        },
                      ),
                      const SizedBox(width: 40),
                      CircularProgressIndicator(
                        value: widget.remainingSeconds / widget.durationSeconds,
                        strokeWidth: 8,
                        backgroundColor: Colors.white10,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 40),
                      _ActionButton(
                        label: "Done",
                        primary: true,
                        onPressed: () async {
                          await MacOSBridge.hideOverlay();
                        },
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: primary ? Colors.blueAccent : Colors.white12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
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
