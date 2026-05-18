import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/settings/exercise_model.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/break_overlay/presentation/widgets/breathing_assistant.dart';

class BreakOverlay extends StatefulWidget {
  const BreakOverlay({super.key});

  @override
  State<BreakOverlay> createState() => _BreakOverlayState();
}

class _BreakOverlayState extends State<BreakOverlay> with TickerProviderStateMixin {
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
          breathingController: _breathingController,
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
  final AnimationController breathingController;

  const _BreakOverlayContent({
    required this.breakInfo,
    required this.settings,
    required this.timerEngine,
    required this.controller,
    required this.pageController,
    required this.kenBurnsController,
    required this.breathingController,
  });

  @override
  State<_BreakOverlayContent> createState() => _BreakOverlayContentState();
}

class _BreakOverlayContentState extends State<_BreakOverlayContent> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Layer with Ken Burns Effect
          AnimatedBuilder(
            animation: widget.kenBurnsController,
            builder: (context, child) {
              return PageView.builder(
                controller: widget.pageController,
                itemCount: AppConstants.wellnessSlideshow.length,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return Transform.scale(
                    scale: 1.1 + (0.1 * widget.kenBurnsController.value),
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

          // UI Layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  radius: 1.2,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: widget.timerEngine.isCompletionState
                      ? _buildCompletionState()
                      : _buildMainContent(),
                ),
              ),
            ),
          ),

          // Skip / Postpone UI
          if (!widget.timerEngine.isCompletionState && !widget.settings.strictMode)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(child: _buildActionButtons()),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final exercise = _selectedExercise();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.breakInfo.title.toUpperCase(),
          style: AppTheme.sectionTitle.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 12,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _formatDuration(widget.timerEngine.countdownSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 220,
            fontWeight: FontWeight.w100,
            letterSpacing: -14,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 60),
        BreathingAssistant(isShortBreak: widget.breakInfo.type == BreakType.short),
        const SizedBox(height: 36),
        if (exercise != null) _buildExercise(exercise),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Text(
            widget.breakInfo.tip,
            textAlign: TextAlign.center,
            style: AppTheme.tipStyle.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 22,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  ExerciseModel? _selectedExercise() {
    final exercises = (widget.settings.exercises.isEmpty
            ? ExerciseModel.defaults
            : widget.settings.exercises)
        .where((exercise) => exercise.enabled)
        .toList();
    if (exercises.isEmpty) return null;
    if (widget.breakInfo.type == BreakType.short) {
      return exercises.firstWhere(
        (exercise) => exercise.category == ExerciseCategory.eyeRest,
        orElse: () => exercises.first,
      );
    }
    return exercises.firstWhere(
      (exercise) => exercise.category != ExerciseCategory.eyeRest,
      orElse: () => exercises.first,
    );
  }

  Widget _buildExercise(ExerciseModel exercise) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        children: [
          Text(
            exercise.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            exercise.instructions,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 17,
              height: 1.35,
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
        const Icon(CupertinoIcons.checkmark_seal_fill, color: AppTheme.shortBreakColor, size: 80),
        const SizedBox(height: 32),
        const Text(
          'REFRESHED',
          style: TextStyle(
            letterSpacing: 12,
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w200,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You are ready to continue.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPillButton(
          icon: CupertinoIcons.arrow_right,
          label: 'Skip',
          onTap: () => widget.controller.skipCurrentBreak(),
          muted: true,
        ),
      ],
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: muted ? 0.05 : 0.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.white.withValues(alpha: muted ? 0.05 : 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.white.withValues(alpha: muted ? 0.4 : 0.8)),
                  const SizedBox(width: 8),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: muted ? 0.4 : 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
