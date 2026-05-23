import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/companion/domain/pet_theme.dart';
import 'package:standup/features/companion/domain/pet_animation_state.dart';
import 'package:standup/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

class ZenModeTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ZenModeTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<ZenModeTemplate> createState() => _ZenModeTemplateState();
}

class _ZenModeTemplateState extends State<ZenModeTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;

  PetAnimationState _animationState = PetAnimationState.sleep;
  Timer? _behaviorTimer;

  final List<String> _zenQuotes = [
    'Silence is not silent. It is full of answers.',
    'Breathe in experience, breathe out poetry.',
    'Do not dwell in the past, dream of the future, concentrate the mind on the present.',
    'Within you, there is a sanctuary to which you can retreat at any time.',
    'Flow with whatever may happen, and let your mind be free.',
    'Mindfulness isn\'t difficult, we just need to remember to do it.',
  ];

  late String _activeQuote;

  @override
  void initState() {
    super.initState();
    // 16s cycle for Box Breathing: 4s Inhale, 4s Hold, 4s Exhale, 4s Hold
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _activeQuote = _zenQuotes[DateTime.now().minute % _zenQuotes.length];
    _startBehaviorCycle();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _behaviorTimer?.cancel();
    super.dispose();
  }

  void _startBehaviorCycle() {
    _behaviorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      final random = Random().nextDouble();
      setState(() {
        if (random < 0.65) {
          // Zen mode: mostly sleeping (65% chance)
          _animationState = PetAnimationState.sleep;
        } else if (random < 0.85) {
          // Sometimes stretching (20% chance)
          _animationState = PetAnimationState.stretch;
        } else {
          // Occasionally grooming (15% chance)
          _animationState = PetAnimationState.lick1;
        }
      });
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final petTheme = PetTheme.getTheme(widget.settings.companionPetTheme);
    final overallProgress = widget.totalSeconds > 0
        ? ((widget.totalSeconds - widget.remainingSeconds) /
                  widget.totalSeconds)
              .clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        // Soft morning zen atmospheric gradient (low GPU overhead)
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF14171E), Color(0xFF1F1A1E), Color(0xFF1B1817)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: Row(
              children: [
                // Left Panel: Vertical Stage Progress Timeline
                _buildVerticalTimeline(overallProgress),

                const SizedBox(width: 60),

                // Center Panel: Box Breathing Guide
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BOX BREATHING PRACTICE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Breath Ring Guides
                      AnimatedBuilder(
                        animation: _breathingController,
                        builder: (context, child) {
                          final val = _breathingController.value;
                          double scale = 0.5;
                          String text = 'Inhale';
                          String hint = 'Fill your lungs with energy';

                          if (val < 0.25) {
                            // Phase 1: Inhale (0s - 4s)
                            final t = val / 0.25;
                            scale = 0.5 + (t * 0.5);
                            text = 'Breathe In';
                            hint = 'Slowly inhale nose-to-belly';
                          } else if (val < 0.5) {
                            // Phase 2: Hold (4s - 8s)
                            scale = 1.0;
                            text = 'Hold';
                            hint = 'Keep your lungs comfortably full';
                          } else if (val < 0.75) {
                            // Phase 3: Exhale (8s - 12s)
                            final t = (val - 0.5) / 0.25;
                            scale = 1.0 - (t * 0.5);
                            text = 'Breathe Out';
                            hint = 'Release all tension with a sigh';
                          } else {
                            // Phase 4: Hold (12s - 16s)
                            scale = 0.5;
                            text = 'Hold';
                            hint = 'Remain empty and calm';
                          }

                          return Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // External ring
                                  Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  // Pulsing Breathing Circle with premium organic glow
                                  Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 230,
                                      height: 230,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(
                                          alpha: 0.02,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 40,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Centered breathing text
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w300,
                                          fontFamily: 'Satoshi',
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatDuration(
                                          widget.remainingSeconds,
                                        ),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Text(
                                hint,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Satoshi',
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 60),

                      // Focus Quote Box
                      Container(
                        width: 500,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              CupertinoIcons.quote_bubble,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _activeQuote,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 40),

                // Right Panel: Elegant Zen Companion Info
                SizedBox(
                  width: 250,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            CompanionSpriteWidget(
                              petTheme: petTheme,
                              animationState: _animationState,
                              scale: 3.5,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _animationState == PetAnimationState.sleep
                                  ? '${petTheme.name} is sleeping...'
                                  : _animationState == PetAnimationState.stretch
                                      ? '${petTheme.name} is stretching...'
                                      : '${petTheme.name} is relaxing...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (widget.onSkip != null)
                        GestureDetector(
                          onTap: widget.onSkip,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Skip Focus',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.6),
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
        ),
      ),
    );
  }

  Widget _buildVerticalTimeline(double overallProgress) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineNode(
          title: 'Start',
          subtitle: 'Disconnect',
          active: overallProgress >= 0.0,
          completed: overallProgress > 0.1,
        ),
        _buildTimelineLine(completed: overallProgress > 0.4),
        _buildTimelineNode(
          title: 'Midpoint',
          subtitle: 'Breathe Deep',
          active: overallProgress >= 0.5,
          completed: overallProgress > 0.6,
        ),
        _buildTimelineLine(completed: overallProgress > 0.9),
        _buildTimelineNode(
          title: 'Complete',
          subtitle: 'Re-energized',
          active: overallProgress >= 1.0,
          completed: overallProgress >= 1.0,
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required String title,
    required String subtitle,
    required bool active,
    required bool completed,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? Colors.white
                : active
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.transparent,
            border: Border.all(
              color: completed
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: completed
                    ? Colors.white
                    : active
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Satoshi',
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: completed
                    ? Colors.white.withValues(alpha: 0.6)
                    : active
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.2),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: 'Satoshi',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineLine({required bool completed}) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.only(left: 3.5),
      color: completed ? Colors.white : Colors.white.withValues(alpha: 0.1),
    );
  }
}
