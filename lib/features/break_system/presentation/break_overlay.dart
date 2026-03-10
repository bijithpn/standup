import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/ui/theme/app_theme.dart';
import 'package:standup/features/break_system/domain/break_model.dart';

class BreakOverlay extends StatefulWidget {
  const BreakOverlay({super.key});

  @override
  State<BreakOverlay> createState() => _BreakOverlayState();
}

class _BreakOverlayState extends State<BreakOverlay> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentSlide = 0;
  Timer? _slideshowTimer;
  late AnimationController _breathingController;
  late Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startSlideshow();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _timeStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  }

  void _startSlideshow() {
    _slideshowTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted) return;
      setState(() {
        _currentSlide = (_currentSlide + 1) % AppConstants.wellnessSlideshow.length;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentSlide,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOutCubic,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;
        final breakInfo = timerEngine.activeBreak;
        final settings = controller.settingsRepository.currentSettings;

        if (breakInfo == null) return const SizedBox.shrink();

        return Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Layer
              _buildBackground(settings),

              // UI Layer
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: settings.clockFaceBlurEnabled ? 50 : 0, 
                  sigmaY: settings.clockFaceBlurEnabled ? 50 : 0
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.7),
                      ],
                      radius: 1.5,
                    ),
                  ),
                  child: SafeArea(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        padding: const EdgeInsets.all(40),
                        child: timerEngine.isCompletionState
                            ? _buildCompletionState()
                            : _buildClockFace(settings, breakInfo, timerEngine, controller),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Skip Button at bottom
              if (!timerEngine.isCompletionState)
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildSkipButton(context, controller, settings.strictMode)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackground(SettingsModel settings) {
    return PageView.builder(
      controller: _pageController,
      itemCount: AppConstants.wellnessSlideshow.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return AnimatedOpacity(
          opacity: 0.4,
          duration: const Duration(seconds: 2),
          child: Image.asset(
            AppConstants.wellnessSlideshow[index],
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _buildClockFace(SettingsModel settings, BreakModel breakInfo, TimerEngine timerEngine, BreakController controller) {
    switch (settings.clockFaceStyle.toLowerCase()) {
      case 'desktop':
        return _buildDesktopClock(timerEngine, settings);
      case 'personal':
      case 'ambient':
        return _buildAmbientClock(timerEngine, settings);
      case 'focus':
        return _buildFocusClock(timerEngine, settings);
      case 'breakloop':
      default:
        return _buildStandardBreakLoop(breakInfo, timerEngine, settings);
    }
  }

  Widget _buildStandardBreakLoop(BreakModel breakInfo, TimerEngine timerEngine, SettingsModel settings) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          breakInfo.title.toUpperCase(),
          style: TextStyle(
            letterSpacing: 10,
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _formatDuration(timerEngine.countdownSeconds),
          style: TextStyle(
            color: Color(settings.clockFaceTextColorHex),
            fontSize: 200,
            fontWeight: FontWeight.w100,
            letterSpacing: -10,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 20),
        _buildInstructionCard(breakInfo),
      ],
    );
  }

  Widget _buildDesktopClock(TimerEngine timerEngine, SettingsModel settings) {
    return StreamBuilder<DateTime>(
      stream: _timeStream,
      builder: (context, snapshot) {
        final time = snapshot.data ?? DateTime.now();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('hh:mm a').format(time),
              style: TextStyle(
                color: Color(settings.clockFaceTextColorHex),
                fontSize: 120,
                fontWeight: FontWeight.w200,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_formatDuration(timerEngine.countdownSeconds)} remaining',
                style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w300),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildAmbientClock(TimerEngine timerEngine, SettingsModel settings) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Ring
          SizedBox(
            width: 400,
            height: 400,
            child: CircularProgressIndicator(
              value: timerEngine.countdownSeconds / (timerEngine.activeBreak?.durationSeconds ?? 60),
              strokeWidth: 4,
              color: AppTheme.accentColor.withOpacity(0.3),
              backgroundColor: Colors.white10,
            ),
          ),
          StreamBuilder<DateTime>(
            stream: _timeStream,
            builder: (context, snapshot) {
              final time = snapshot.data ?? DateTime.now();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(time),
                    style: TextStyle(
                      color: Color(settings.clockFaceTextColorHex),
                      fontSize: 80,
                      fontWeight: FontWeight.w100,
                    ),
                  ),
                  Text(
                    _formatDuration(timerEngine.countdownSeconds),
                    style: const TextStyle(color: Colors.white38, fontSize: 24),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildFocusClock(TimerEngine timerEngine, SettingsModel settings) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            final size = 200 + (100 * _breathingController.value);
            final isInhale = _breathingController.status == AnimationStatus.forward;
            return Column(
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentColor.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withOpacity(0.2 * _breathingController.value),
                        blurRadius: 40,
                        spreadRadius: 20 * _breathingController.value,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isInhale ? 'INHALE' : 'EXHALE',
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 4,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Text(
                  _formatDuration(timerEngine.countdownSeconds),
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w100),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildInstructionCard(BreakModel breakInfo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            breakInfo.isLong ? CupertinoIcons.wind : CupertinoIcons.eye,
            color: AppTheme.accentColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            breakInfo.isLong ? 'Take deep breaths and stretch' : 'Look at something far away',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CupertinoIcons.checkmark_seal_fill, color: AppTheme.shortBreakColor, size: 100),
        const SizedBox(height: 30),
        const Text(
          'WELL DONE',
          style: TextStyle(
            letterSpacing: 10,
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w200,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You\'re ready to continue.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildSkipButton(BuildContext context, BreakController controller, bool strictMode) {
    if (strictMode) return const SizedBox.shrink();
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => controller.skipCurrentBreak(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            'Skip this break'.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
