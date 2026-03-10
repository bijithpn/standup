import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';

class FlashOverlay extends StatefulWidget {
  const FlashOverlay({super.key});

  @override
  State<FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends State<FlashOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerFlash(SettingsModel settings) {
    if (_isVisible) return;
    
    _controller.duration = Duration(milliseconds: settings.flashDurationMs);
    setState(() => _isVisible = true);
    
    _controller.forward(from: 0).then((_) {
      setState(() => _isVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final settings = controller.settingsRepository.currentSettings;
        final isFlashing = controller.timerEngine.isFlashing;

        if (isFlashing && !_isVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _triggerFlash(settings));
        }

        if (!_isVisible) return const SizedBox.shrink();

        return Stack(
          children: [
            // Background Animation Overlay
            _buildAnimationOverlay(settings),
            
            // Floating Notification Card
            _buildNotificationCard(settings),
          ],
        );
      },
    );
  }

  Widget _buildAnimationOverlay(SettingsModel settings) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = (progress < 0.2) 
            ? (progress / 0.2) 
            : (progress > 0.8) 
                ? (1 - (progress - 0.8) / 0.2) 
                : 1.0;
        
        final intensity = settings.flashIntensity * opacity;

        switch (settings.flashAnimationType) {
          case 'glow':
            return ShaderMask(
              shaderCallback: (rect) {
                return RadialGradient(
                  center: Alignment.center,
                  radius: progress * 2,
                  colors: [
                    Color(settings.flashColorHex).withOpacity(intensity),
                    Colors.transparent,
                  ],
                ).createShader(rect);
              },
              blendMode: BlendMode.srcOver,
              child: Container(color: Colors.white.withOpacity(0.1 * intensity)),
            );
          case 'dim':
            return Container(color: Colors.black.withOpacity(0.7 * intensity));
          case 'edge':
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Color(settings.flashColorHex).withOpacity(intensity),
                  width: 20 * progress,
                ),
              ),
            );
          case 'fade':
            return Container(color: Color(settings.flashColorHex).withOpacity(0.3 * intensity));
          case 'pulse':
          default:
            return Container(
              color: Color(settings.flashColorHex).withOpacity(0.15 * intensity),
            );
        }
      },
    );
  }

  Widget _buildNotificationCard(SettingsModel settings) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final slide = (progress < 0.15) 
            ? (1 - progress / 0.15) * 50
            : (progress > 0.85) 
                ? (progress - 0.85) / 0.15 * 50
                : 0.0;
        
        final opacity = (progress < 0.1) 
            ? (progress / 0.1) 
            : (progress > 0.9) 
                ? (1 - (progress - 0.9) / 0.1) 
                : 1.0;

        return Positioned(
          top: 60 + slide,
          right: 30,
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(settings.flashColorHex).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.timer,
                          color: Color(settings.flashColorHex),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'BreakMate',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              settings.flashMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Starting in 30 seconds',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
