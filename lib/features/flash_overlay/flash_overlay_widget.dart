import 'package:flutter/material.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:standup/features/flash_overlay/flash_overlay_service.dart';
import 'package:standup/features/settings/settings_repository.dart';
import 'package:window_manager/window_manager.dart';

class FlashOverlayWidget extends StatefulWidget {
  final FlashOverlayService overlayService;
  final VoidCallback? onClose;

  const FlashOverlayWidget({
    super.key,
    required this.overlayService,
    this.onClose,
  });

  @override
  State<FlashOverlayWidget> createState() => _FlashOverlayWidgetState();
}

class _FlashOverlayWidgetState extends State<FlashOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _configureWindow();

    final settings = sl<SettingsRepository>().currentSettings;
    final durationMs = settings.flashDurationMs;

    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    _animation = _buildAnimation(settings.flashAnimationType);
    _animController.forward();

    // Auto-close after duration
    Future.delayed(Duration(milliseconds: durationMs), () {
      if (mounted) _handleClose();
    });
  }

  Animation<double> _buildAnimation(String type) {
    switch (type) {
      case 'pulse':
        return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeInOut,
          ),
        )..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _animController.reverse();
            } else if (status == AnimationStatus.dismissed) {
              _animController.forward();
            }
          });
      case 'glow':
        return Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
        );
      case 'fade':
        return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeIn),
        );
      case 'dim':
        return Tween<double>(begin: 0.8, end: 0.3).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOut),
        );
      case 'edge':
        return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
        );
      default:
        return Tween<double>(begin: 0.0, end: 1.0).animate(_animController);
    }
  }

  Future<void> _configureWindow() async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setFullScreen(true);
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> _handleClose() async {
    await widget.overlayService.hideOverlay();
    widget.onClose?.call();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = sl<SettingsRepository>().currentSettings;
    final flashColor = Color(settings.flashColorHex);
    final intensity = settings.flashIntensity;
    final animType = settings.flashAnimationType;
    final style = settings.flashStyle;
    final message = settings.flashMessage;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return _buildOverlay(
          context,
          flashColor: flashColor,
          intensity: intensity,
          animType: animType,
          style: style,
          message: message,
          animValue: _animation.value,
        );
      },
    );
  }

  Widget _buildOverlay(
    BuildContext context, {
    required Color flashColor,
    required double intensity,
    required String animType,
    required String style,
    required String message,
    required double animValue,
  }) {
    if (style == 'cat') {
      return _CatStretchFlash(
        color: flashColor,
        intensity: intensity,
        animValue: animValue,
        message: message,
        onClose: _handleClose,
      );
    }

    switch (animType) {
      case 'edge':
        return _EdgeFlash(
          color: flashColor,
          intensity: intensity,
          animValue: animValue,
          message: message,
          onClose: _handleClose,
        );
      case 'dim':
        return _DimFlash(
          color: flashColor,
          intensity: intensity * animValue,
          message: message,
          onClose: _handleClose,
        );
      default:
        // pulse, glow, fade all use the full-screen overlay
        return _FullScreenFlash(
          color: flashColor,
          intensity: intensity * animValue,
          message: message,
          onClose: _handleClose,
          animType: animType,
        );
    }
  }
}

class _CatStretchFlash extends StatelessWidget {
  final Color color;
  final double intensity;
  final double animValue;
  final String message;
  final VoidCallback onClose;

  const _CatStretchFlash({
    required this.color,
    required this.intensity,
    required this.animValue,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 0.94 + (animValue * 0.08);
    return GestureDetector(
      onTap: onClose,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: (0.28 + intensity * 0.35).clamp(0.0, 0.75)),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 600;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isSmall ? 100 : 132,
                        height: isSmall ? 100 : 132,
                        padding: EdgeInsets.all(isSmall ? 20 : 26),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.18),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 50 * intensity,
                              spreadRadius: 10 * intensity,
                            ),
                          ],
                        ),
                        child: Image.asset('assets/icons/cat/cat_stretch.png', fit: BoxFit.contain),
                      ),
                      SizedBox(height: isSmall ? 20 : 28),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 20 : 28,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

class _FullScreenFlash extends StatelessWidget {
  final Color color;
  final double intensity;
  final String message;
  final VoidCallback onClose;
  final String animType;

  const _FullScreenFlash({
    required this.color,
    required this.intensity,
    required this.message,
    required this.onClose,
    required this.animType,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Scaffold(
        backgroundColor: color.withValues(alpha: intensity.clamp(0.0, 0.95)),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 600;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (animType == 'glow')
                      Container(
                        width: isSmall ? 100 : 120,
                        height: isSmall ? 100 : 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.8),
                              blurRadius: 60 * intensity,
                              spreadRadius: 20 * intensity,
                            ),
                          ],
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        child: Icon(Icons.visibility, size: isSmall ? 50 : 60, color: Colors.black87),
                      )
                    else
                      Icon(
                        Icons.visibility,
                        size: isSmall ? 60 : 80,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    SizedBox(height: isSmall ? 24 : 32),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: isSmall ? 22 : 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap anywhere to dismiss',
                      style: TextStyle(
                        fontSize: isSmall ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

class _DimFlash extends StatelessWidget {
  final Color color;
  final double intensity;
  final String message;
  final VoidCallback onClose;

  const _DimFlash({
    required this.color,
    required this.intensity,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: intensity.clamp(0.0, 0.7)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white70,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeFlash extends StatelessWidget {
  final Color color;
  final double intensity;
  final double animValue;
  final String message;
  final VoidCallback onClose;

  const _EdgeFlash({
    required this.color,
    required this.intensity,
    required this.animValue,
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = 12.0 * intensity * animValue;
    return GestureDetector(
      onTap: onClose,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withValues(alpha: (intensity * animValue).clamp(0.0, 1.0)),
              width: borderWidth,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 20,
                      color: color,
                      fontWeight: FontWeight.w600,
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
