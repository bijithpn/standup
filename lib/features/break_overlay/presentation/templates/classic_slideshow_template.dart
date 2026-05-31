import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_activity_graph.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'dart:io';

class ClassicSlideshowTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;
  final PageController? pageController;
  final AnimationController kenBurnsController;
  final String? singleImage;
  final String? exerciseTitle;
  final String? exerciseInstructions;

  const ClassicSlideshowTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
    this.pageController,
    required this.kenBurnsController,
    this.singleImage,
    this.exerciseTitle,
    this.exerciseInstructions,
  });

  @override
  State<ClassicSlideshowTemplate> createState() =>
      _ClassicSlideshowTemplateState();
}

class _ClassicSlideshowTemplateState extends State<ClassicSlideshowTemplate> {
  List<int> _dataPoints = [2, 4, 3, 5, 2, 6, 4];

  @override
  void initState() {
    super.initState();
    _loadStatsData();
  }

  void _loadStatsData() {
    try {
      final statsService = sl<StatsService>();
      final stats = statsService.load();
      if (stats.weeklyData.isNotEmpty) {
        final data = stats.weeklyData.map((d) => d.breaksCompleted).toList();
        if (data.isNotEmpty) {
          setState(() {
            _dataPoints = data.length > 7
                ? data.sublist(data.length - 7)
                : data;
          });
        }
      }
    } catch (e) {
      // Fallback silently to mock data
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Renders either a dynamic sliding PageView or a static single random image fallback
    Widget buildAssetBackground() {
      if (widget.pageController != null) {
        return PageView.builder(
          controller: widget.pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: AppConstants.wellnessSlideshow.length,
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: widget.kenBurnsController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.05 + (0.1 * widget.kenBurnsController.value),
                  child: Image.asset(
                    AppConstants.wellnessSlideshow[index],
                    fit: BoxFit.cover,
                    cacheWidth: screenWidth.toInt().clamp(100, 1920),
                    cacheHeight: screenHeight.toInt().clamp(100, 1080),
                    filterQuality: FilterQuality.low,
                  ),
                );
              },
            );
          },
        );
      } else {
        final fallbackImg =
            widget.singleImage ?? AppConstants.wellnessSlideshow.first;
        return AnimatedBuilder(
          animation: widget.kenBurnsController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.05 + (0.1 * widget.kenBurnsController.value),
              child: Image.asset(
                fallbackImg,
                fit: BoxFit.cover,
                cacheWidth: screenWidth.toInt().clamp(100, 1920),
                cacheHeight: screenHeight.toInt().clamp(100, 1080),
                filterQuality: FilterQuality.low,
              ),
            );
          },
        );
      }
    }

    Widget backgroundWidget;
    final path = widget.settings.customImagePath;
    final isCustomEnabled = path != null && !path.startsWith("disabled:");
    final actualPath = path != null && path.startsWith("disabled:") ? path.substring(9) : path;

    if (isCustomEnabled &&
        actualPath != 'default_path' &&
        actualPath != null &&
        File(actualPath).existsSync()) {
      backgroundWidget = AnimatedBuilder(
        animation: widget.kenBurnsController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.05 + (0.1 * widget.kenBurnsController.value),
            child: Image.file(
              File(actualPath),
              fit: BoxFit.cover,
              cacheWidth: screenWidth.toInt().clamp(100, 1920),
              cacheHeight: screenHeight.toInt().clamp(100, 1080),
              filterQuality: FilterQuality.low,
            ),
          );
        },
      );
    } else {
      backgroundWidget = buildAssetBackground();
    }

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Slideshow Background with Ken Burns
          RepaintBoundary(child: backgroundWidget),

          // Calming dimming glassmorphic/gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Main Interactive Layout
          SafeArea(
            child: Column(
              children: [
                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 20.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF32D74B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppConstants.appName.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('HH:mm').format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Centered Main Time and Tip Card
                RepaintBoundary(
                  child: Center(
                    child: Container(
                      width: 560,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 48,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.34),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.breakInfo.type == BreakType.short
                                ? 'Rest Your Eyes'
                                : 'Time to Recharge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatDuration(widget.remainingSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 90,
                              fontWeight: FontWeight.w200,
                              letterSpacing: -4.0,
                              height: 1.0,
                              fontFamily: 'Inter',
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.breakInfo.tip,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                              fontFamily: 'Inter',
                            ),
                          ),

                          // Optional exercise instruction card
                          if (widget.settings.showExercisesInBreak &&
                              widget.exerciseTitle != null &&
                              widget.exerciseInstructions != null) ...[
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        CupertinoIcons.heart_fill,
                                        size: 13,
                                        color: Color(0xFFFF453A),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'EXERCISE: ${widget.exerciseTitle!}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.exerciseInstructions!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Panel: Streak Activity Graph & Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 30.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Weekly activity chart
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.graph_square_fill,
                                        size: 12,
                                        color: Color(0xFF32D74B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'WEEKLY REST ACTIVITY',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 50,
                                    child: BreakActivityGraph(
                                      dataPoints: _dataPoints,
                                      color: const Color(0xFF32D74B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Skip Button
                      if (widget.onSkip != null)
                        GestureDetector(
                          onTap: widget.onSkip,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Skip Break',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    CupertinoIcons.arrow_right,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
