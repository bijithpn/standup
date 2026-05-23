import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/companion/domain/pet_theme.dart';
import 'package:standup/features/companion/domain/pet_animation_state.dart';
import 'package:standup/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

class MinimalFocusTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const MinimalFocusTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<MinimalFocusTemplate> createState() => _MinimalFocusTemplateState();
}

class _MinimalFocusTemplateState extends State<MinimalFocusTemplate>
    with SingleTickerProviderStateMixin {
  late AnimationController _gradientController;

  PetAnimationState _animationState = PetAnimationState.breakMode;
  Timer? _behaviorTimer;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _startBehaviorCycle();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _behaviorTimer?.cancel();
    super.dispose();
  }

  void _startBehaviorCycle() {
    _behaviorTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted) return;
      final random = Random().nextDouble();
      setState(() {
        if (random < 0.25) {
          _animationState = PetAnimationState.stretch;
        } else if (random < 0.5) {
          _animationState = PetAnimationState.sleep;
        } else if (random < 0.75) {
          _animationState = PetAnimationState.lick1;
        } else {
          _animationState = PetAnimationState.idle;
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
    final progress = widget.totalSeconds > 0
        ? (widget.remainingSeconds / widget.totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          // Slow breathing dark HSL linear gradients
          final color1 = Color.lerp(
            const Color(0xFF0F0F11),
            const Color(0xFF16161A),
            _gradientController.value,
          )!;
          final color2 = Color.lerp(
            const Color(0xFF1B1B22),
            const Color(0xFF0C0C0E),
            _gradientController.value,
          )!;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color1, color2],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background design grid/texture lines
              Positioned.fill(
                child: Opacity(
                  opacity: 0.03,
                  child: GridPaper(
                    color: Colors.white,
                    interval: 120,
                    divisions: 1,
                    subdivisions: 1,
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main Modern UI Card
                    Container(
                      width: 520,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.015),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 60,
                            offset: const Offset(0, 30),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Label
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.breakInfo.type == BreakType.short
                                      ? CupertinoIcons.eye
                                      : CupertinoIcons.wind,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.breakInfo.type == BreakType.short
                                      ? 'EYE REST'
                                      : 'MINDFUL BREAK',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Circular Progress Ring enclosing clean timer
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 200,
                                height: 200,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 2,
                                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(widget.remainingSeconds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: -1.5,
                                  fontFamily: 'Satoshi',
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 48),

                          // Text Information Block
                          Text(
                            widget.breakInfo.type == BreakType.short
                                ? 'Rest Your Eyes, Refresh Your Mind'
                                : 'Step Away, Recharge Completely',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Satoshi',
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              widget.breakInfo.tip,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Satoshi',
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Embedded Animated Companion sitting peacefully
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CompanionSpriteWidget(
                          petTheme: petTheme,
                          animationState: _animationState,
                          scale: 3.5,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Shh... resting is productive too.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Bar: Current Time & Skip
              Positioned(
                bottom: 30,
                left: 40,
                right: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    if (widget.onSkip != null)
                      GestureDetector(
                        onTap: widget.onSkip,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Satoshi',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  CupertinoIcons.arrow_right,
                                  size: 12,
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
      ),
    );
  }
}
