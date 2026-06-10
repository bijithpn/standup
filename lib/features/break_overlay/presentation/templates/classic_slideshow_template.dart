import 'dart:io';
import 'package:flutter/material.dart';
import 'package:breakmate/core/constants/app_constants.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class ClassicSlideshowTemplate extends StatelessWidget {
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

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isShort = breakInfo.type == BreakType.short;
    final path = settings.customImagePath;
    final isCustomEnabled = path != null && !path.startsWith('disabled:');
    final actualPath = path != null && path.startsWith('disabled:')
        ? path.substring(9)
        : path;

    Widget background;
    if (isCustomEnabled &&
        actualPath != null &&
        actualPath != 'default_path' &&
        File(actualPath).existsSync()) {
      background = Image.file(
        File(actualPath),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
      );
    } else if (pageController != null) {
      background = PageView.builder(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: AppConstants.wellnessSlideshow.length,
        itemBuilder: (_, i) => Image.asset(
          AppConstants.wellnessSlideshow[i],
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        ),
      );
    } else {
      final img = singleImage ?? AppConstants.wellnessSlideshow.first;
      background = Image.asset(
        img,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
      );
    }

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: background),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xA6000000)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isShort ? 'Rest your eyes' : 'Time to recharge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatTime(remainingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        fontFamily: 'Inter',
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: -3.0,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      breakInfo.tip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!settings.strictMode && onSkip != null)
            Positioned(
              bottom: 36,
              right: 40,
              child: GestureDetector(
                onTap: onSkip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
