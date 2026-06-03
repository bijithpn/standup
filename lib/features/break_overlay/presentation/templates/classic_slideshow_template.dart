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
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

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
    final compact = screenWidth < 760 || screenHeight < 620;

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
    final actualPath = path != null && path.startsWith("disabled:")
        ? path.substring(9)
        : path;

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
          RepaintBoundary(child: backgroundWidget),

          // Calming dimming gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header Row
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 24 : 40,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399), // Cozy Green dot
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppConstants.appName.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('HH:mm').format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
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
                      width: 500,
                      margin: EdgeInsets.symmetric(
                        horizontal: compact ? 24 : 0,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 28 : 40,
                        vertical: compact ? 32 : 44,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1115).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
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
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatDuration(widget.remainingSeconds),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 64 : 80,
                              fontWeight: FontWeight.w200,
                              letterSpacing: -3.0,
                              height: 1.0,
                              fontFamily: 'Inter',
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.breakInfo.tip,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                              fontFamily: 'Inter',
                            ),
                          ),

                          // Optional exercise instruction card
                          if (widget.settings.showExercisesInBreak &&
                              widget.exerciseTitle != null &&
                              widget.exerciseInstructions != null) ...[
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
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
                                        color: Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'EXERCISE: ${widget.exerciseTitle!}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
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
                                        alpha: 0.55,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 1.45,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 24 : 40,
                    vertical: compact ? 20 : 30,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Weekly activity chart
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0F1115,
                                ).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
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
                                        color: Color(0xFF34D399),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'WEEKLY REST ACTIVITY',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 40,
                                    child: BreakActivityGraph(
                                      dataPoints: _dataPoints,
                                      color: const Color(0xFF34D399),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Skip Button
                      if (widget.onSkip != null && !widget.settings.strictMode)
                        SkipBreakButton(onSkip: widget.onSkip!),
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
