import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/break_system/presentation/widgets/break_activity_graph.dart';

class BreakOverlay extends StatefulWidget {
  const BreakOverlay({super.key});

  @override
  State<BreakOverlay> createState() => _BreakOverlayState();
}

class _BreakOverlayState extends State<BreakOverlay> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentSlide = 0;
  Timer? _slideshowTimer;
  late AnimationController _kenBurnsController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startSlideshow();
    
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
    _kenBurnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;
        final breakInfo = timerEngine.activeBreak;

        if (breakInfo == null || timerEngine.state != TimerState.breakActive) {
          return const SizedBox.shrink();
        }

        return _BreakOverlayContent(
          breakInfo: breakInfo,
          settings: controller.settingsRepository.currentSettings,
          timerEngine: timerEngine,
          controller: controller,
          pageController: _pageController,
          kenBurnsController: _kenBurnsController,
        );
      },
    );
  }
}

class _BreakOverlayContent extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final TimerEngine timerEngine;
  final BreakController controller;
  final PageController pageController;
  final AnimationController kenBurnsController;

  const _BreakOverlayContent({
    required this.breakInfo,
    required this.settings,
    required this.timerEngine,
    required this.controller,
    required this.pageController,
    required this.kenBurnsController,
  });

  @override
  State<_BreakOverlayContent> createState() => _BreakOverlayContentState();
}

class _BreakOverlayContentState extends State<_BreakOverlayContent> {
  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatsService>(context, listen: false).load();
    final weeklyData = stats.weeklyData.map((d) => d.breaksCompleted).toList();
    
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer with Blur
          AnimatedBuilder(
            animation: widget.kenBurnsController,
            builder: (context, child) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: widget.pageController,
                    itemCount: AppConstants.wellnessSlideshow.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return Transform.scale(
                        scale: 1.1 + (0.1 * widget.kenBurnsController.value),
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

          // Content Layer
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
                        _formatDuration(widget.timerEngine.countdownSeconds),
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
                              widget.breakInfo.type == BreakType.short 
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
                              widget.breakInfo.tip,
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
                
                const Spacer(),
                
                // Graph Area
                Column(
                  children: [
                    BreakActivityGraph(
                      dataPoints: weeklyData.isEmpty ? [1, 3, 2, 4, 3, 5, 4] : weeklyData,
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
                      if (!widget.settings.strictMode)
                        _buildSkipButton(),
                      const Spacer(),
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

  Widget _buildSkipButton() {
    return GestureDetector(
      onTap: () => widget.controller.skipCurrentBreak(),
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
