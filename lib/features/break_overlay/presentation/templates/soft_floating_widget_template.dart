import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/companion/domain/cat_theme.dart';
import 'package:standup/features/companion/domain/cat_animation_state.dart';
import 'package:standup/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

class SoftFloatingWidgetTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SoftFloatingWidgetTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<SoftFloatingWidgetTemplate> createState() =>
      _SoftFloatingWidgetTemplateState();
}

class _SoftFloatingWidgetTemplateState extends State<SoftFloatingWidgetTemplate>
    with SingleTickerProviderStateMixin {
  // Placement coordinates
  double? _x;
  double? _y;
  bool _isDragging = false;
  bool _isHovered = false;

  // Pulsing neon shadow animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _snapToBoundaries(
    double screenWidth,
    double screenHeight,
    double width,
    double height,
  ) {
    if (_x == null || _y == null) return;

    // Corner options: Top-Left, Top-Right, Bottom-Left, Bottom-Right
    final offset = 30.0;
    final corners = [
      Offset(offset, offset), // TL
      Offset(screenWidth - width - offset, offset), // TR
      Offset(offset, screenHeight - height - offset - 50), // BL
      Offset(
        screenWidth - width - offset,
        screenHeight - height - offset - 50,
      ), // BR
    ];

    Offset nearest = corners.first;
    double minDist = double.infinity;

    for (final c in corners) {
      final dist = sqrt(pow(_x! - c.dx, 2) + pow(_y! - c.dy, 2));
      if (dist < minDist) {
        minDist = dist;
        nearest = c;
      }
    }

    setState(() {
      _x = nearest.dx;
      _y = nearest.dy;
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final catTheme = CatTheme.getTheme(widget.settings.companionCatTheme);
    final double closedWidth = 180.0;
    final double openWidth = 320.0;
    final double height = 80.0;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Default start location: bottom right
          if (_x == null || _y == null) {
            _x = constraints.maxWidth - closedWidth - 30;
            _y = constraints.maxHeight - height - 100;
          }

          final currentWidth = _isHovered ? openWidth : closedWidth;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Extra light dimming overlay to keep focus on screen
              Container(color: Colors.black.withValues(alpha: 0.4)),

              // Corner Snappable Floating Pill
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: _x,
                top: _y,
                child: MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _isHovered = true;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _isHovered = false;
                    });
                  },
                  child: GestureDetector(
                    onPanStart: (_) {
                      setState(() {
                        _isDragging = true;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _x = (_x! + details.delta.dx).clamp(
                          0.0,
                          constraints.maxWidth - currentWidth,
                        );
                        _y = (_y! + details.delta.dy).clamp(
                          0.0,
                          constraints.maxHeight - height - 50,
                        );
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        _isDragging = false;
                      });
                      _snapToBoundaries(
                        constraints.maxWidth,
                        constraints.maxHeight,
                        currentWidth,
                        height,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      width: currentWidth,
                      height: height,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(height / 2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          // Slow glowing outer warnings pulse
                          BoxShadow(
                            color: Colors.white.withValues(
                              alpha: 0.05 + (_pulseController.value * 0.05),
                            ),
                            blurRadius: 10 + (_pulseController.value * 10),
                            spreadRadius: 2 + (_pulseController.value * 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: openWidth,
                          child: Row(
                            children: [
                              // Compact Pet Avatar (Visible in both)
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.04),
                                ),
                                child: Center(
                                  child: CompanionSpriteWidget(
                                    catTheme: catTheme,
                                    animationState: CatAnimationState.breakMode,
                                    scale: 2.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Time remaining pill
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDuration(widget.remainingSeconds),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.breakInfo.type == BreakType.short
                                        ? 'Eye Rest'
                                        : 'Mindful Rest',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),

                              // Hover state actions section (Faded in/out)
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: _isHovered ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 1,
                                        height: 32,
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          widget.breakInfo.tip,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 10,
                                            height: 1.3,
                                            fontFamily: 'Satoshi',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (widget.onSkip != null)
                                        GestureDetector(
                                          onTap: widget.onSkip,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                CupertinoIcons.chevron_right,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
