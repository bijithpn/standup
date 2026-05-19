import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/shared/theme/app_theme.dart';

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerFlash(settings);
          });
        }

        if (!_isVisible) return const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          children: [
            // Immersive Background Glow
            _buildImmersiveGlow(settings),

            // Centered Immersive Message
            Center(child: _buildImmersiveMessage(settings)),
          ],
        );
      },
    );
  }

  Widget _buildImmersiveGlow(SettingsModel settings) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = (progress < 0.2)
            ? (progress / 0.2)
            : (progress > 0.8)
                ? (1 - (progress - 0.8) / 0.2)
                : 1.0;

        final color = Color(settings.flashColorHex);
        final intensity = settings.flashIntensity * opacity;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withValues(alpha: 0.4 * intensity),
              width: 40 * progress,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2 * intensity),
                blurRadius: 100,
                spreadRadius: 50 * progress,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImmersiveMessage(SettingsModel settings) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final opacity = (progress < 0.2)
            ? (progress / 0.2)
            : (progress > 0.8)
                ? (1 - (progress - 0.8) / 0.2)
                : 1.0;

        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.textPrimary.withValues(alpha: 0.1)),
                ),
                child: Icon(
                  CupertinoIcons.wind,
                  color: Color(settings.flashColorHex),
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                settings.flashMessage.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Break starting in 30 seconds',
                style: TextStyle(
                  color: AppTheme.textPrimary.withValues(alpha: 0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
