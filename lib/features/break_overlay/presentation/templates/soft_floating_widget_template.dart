import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

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
  double? _x;
  double? _y;
  bool _isDragging = false;
  bool _isHovered = false;

  PetAnimationState _animationState = PetAnimationState.breakMode;
  Timer? _behaviorTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _startBehaviorCycle();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _behaviorTimer?.cancel();
    _pulseController.dispose();
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

  void _snapToBoundaries(
    double screenWidth,
    double screenHeight,
    double width,
    double height,
  ) {
    if (_x == null || _y == null) return;

    final offset = 30.0;
    final corners = [
      Offset(offset, offset),
      Offset(screenWidth - width - offset, offset),
      Offset(offset, screenHeight - height - offset - 50),
      Offset(screenWidth - width - offset, screenHeight - height - offset - 50),
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
    final petTheme = PetTheme.getTheme(widget.settings.companionPetTheme);
    final double closedWidth = 190.0;
    final double openWidth = 340.0;
    final double height = 76.0;
    final bool enableAnimations =
        widget.settings.enableAnimations &&
        !MediaQuery.of(context).disableAnimations;

    final isShort = widget.breakInfo.type == BreakType.short;
    final accent = isShort ? const Color(0xFF38BDF8) : const Color(0xFF34D399);

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_x == null || _y == null) {
            _x = constraints.maxWidth - closedWidth - 30;
            _y = constraints.maxHeight - height - 100;
          }

          final currentWidth = _isHovered ? openWidth : closedWidth;

          return Stack(
            fit: StackFit.expand,
            children: [
              const _FloatingBackdrop(),

              // Corner Snappable Floating Pill
              AnimatedPositioned(
                duration: _isDragging || !enableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: _x,
                top: _y,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: GestureDetector(
                    onPanStart: (_) => setState(() => _isDragging = true),
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
                      setState(() => _isDragging = false);
                      _snapToBoundaries(
                        constraints.maxWidth,
                        constraints.maxHeight,
                        currentWidth,
                        height,
                      );
                    },
                    child: AnimatedContainer(
                      duration: enableAnimations
                          ? const Duration(milliseconds: 250)
                          : Duration.zero,
                      curve: Curves.easeOutBack,
                      width: currentWidth,
                      height: height,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1115).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
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
                              // Compact Pet Avatar
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.03),
                                ),
                                child: Center(
                                  child: CompanionSpriteWidget(
                                    petTheme: petTheme,
                                    animationState: _animationState,
                                    scale: 2.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Time remaining capsule
                              RepaintBoundary(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Pulse Neon Dot indicator
                                        AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, child) {
                                            return Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: accent.withValues(
                                                  alpha:
                                                      0.4 +
                                                      (0.6 *
                                                          _pulseController
                                                              .value),
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: accent.withValues(
                                                      alpha: 0.5,
                                                    ),
                                                    blurRadius:
                                                        4 *
                                                        _pulseController.value,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDuration(
                                            widget.remainingSeconds,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Inter',
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.breakInfo.type == BreakType.short
                                          ? 'Eye Rest'
                                          : 'Pause Rest',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Faded interactions drawer
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: _isHovered ? 1.0 : 0.0,
                                  duration: enableAnimations
                                      ? const Duration(milliseconds: 150)
                                      : Duration.zero,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 1,
                                        height: 28,
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          widget.breakInfo.tip,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                            fontSize: 10,
                                            height: 1.35,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (widget.onSkip != null &&
                                          !widget.settings.strictMode)
                                        GestureDetector(
                                          onTap: widget.onSkip,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.08),
                                                ),
                                              ),
                                              child: const Icon(
                                                CupertinoIcons.chevron_right,
                                                size: 10,
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

class _FloatingBackdrop extends StatelessWidget {
  const _FloatingBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FloatingBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _FloatingBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.48);
    canvas.drawRect(Offset.zero & size, paint);

    final railPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    for (double y = 80; y < size.height; y += 96) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), railPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
