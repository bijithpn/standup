import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/companion/domain/pet_type.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

class CompanionInteractiveTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const CompanionInteractiveTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<CompanionInteractiveTemplate> createState() =>
      _CompanionInteractiveTemplateState();
}

class _CompanionInteractiveTemplateState
    extends State<CompanionInteractiveTemplate>
    with WidgetsBindingObserver {
  double? _x;
  double? _y;
  bool _isDragging = false;
  bool _isSnapping = false;

  PetAnimationState _animationState = PetAnimationState.breakMode;
  String _speechText = 'Take a deep breath. I am here to rest with you!';
  Timer? _aiBehaviorTimer;
  Timer? _speechBubbleTimer;
  bool _showInteractionMenu = false;
  bool _flipX = false;

  final List<String> _companionTips = [
    'Remember to relax your shoulders!',
    'How about drinking a glass of water?',
    'You can pet me by clicking on me!',
    'Let\'s stretch together. Try matching my pose!',
    'Look at something far away for 20 seconds.',
    'Breathe in... and breathe out...',
    'A rest now makes your next hour twice as productive.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSpeechCycle();
    _startAIBehaviorCycle();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _aiBehaviorTimer?.cancel();
      _speechBubbleTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startSpeechCycle();
      _startAIBehaviorCycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aiBehaviorTimer?.cancel();
    _speechBubbleTimer?.cancel();
    super.dispose();
  }

  void _startSpeechCycle() {
    _speechBubbleTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (!mounted) return;
      setState(() {
        _speechText = _companionTips[Random().nextInt(_companionTips.length)];
      });
    });
  }

  void _startAIBehaviorCycle() {
    _aiBehaviorTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted || _isDragging || _isSnapping) return;

      final petTheme = PetTheme.getTheme(widget.settings.companionPetTheme);
      final species = petTheme.species;
      final random = Random().nextDouble();

      setState(() {
        if (random < 0.25) {
          _animationState = PetAnimationState.stretch;
          if (species == PetSpecies.dog) {
            _speechText = 'A big dog stretch! Ready for action!';
          } else {
            _speechText = 'Mmm, cat stretching feels incredible...';
          }
        } else if (random < 0.45) {
          _animationState = PetAnimationState.sleep;
          if (species == PetSpecies.dog) {
            _speechText = 'Zzz... Cozy puppy dreams...';
          } else {
            _speechText = 'Zzz... Perfect cozy catnap...';
          }
        } else if (random < 0.65) {
          _animationState = PetAnimationState.lick1;
          if (species == PetSpecies.dog) {
            _speechText = 'Cleaning up my puppy paws!';
          } else {
            _speechText = '*Carefully grooming its soft whiskers...*';
          }
        } else if (random < 0.8) {
          _animationState = PetAnimationState.walkSide;
          if (species == PetSpecies.dog) {
            _speechText = 'Walking around! Zoom zoom!';
          } else {
            _speechText = 'Prowling around. I see a bug!';
          }
        } else {
          _animationState = PetAnimationState.breakMode;
          if (species == PetSpecies.dog) {
            _speechText = 'Let\'s take a break together! Woof!';
          } else {
            _speechText = 'Purr... Time to relax and recharge.';
          }
        }
      });
    });
  }

  void _snapToEdges(
    double screenWidth,
    double screenHeight,
    double widgetSize,
  ) {
    if (_x == null || _y == null) return;

    final distLeft = _x!;
    final distRight = screenWidth - (_x! + widgetSize);
    final distTop = _y!;
    final distBottom = screenHeight - (_y! + widgetSize);

    final minDist = [distLeft, distRight, distTop, distBottom].reduce(min);

    setState(() {
      _isSnapping = true;
      if (minDist == distLeft) {
        _x = 24;
        _flipX = false;
      } else if (minDist == distRight) {
        _x = screenWidth - widgetSize - 24;
        _flipX = true;
      } else if (minDist == distTop) {
        _y = 40;
      } else {
        _y = screenHeight - widgetSize - 90;
      }
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isSnapping = false;
        });
      }
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
    final species = petTheme.species;
    const double widgetSize = 130.0;
    final bool enableAnimations =
        widget.settings.enableAnimations &&
        !MediaQuery.of(context).disableAnimations;
    final media = MediaQuery.of(context).size;
    final compact = media.width < 760;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_x == null || _y == null) {
            _x = constraints.maxWidth / 2 - (widgetSize / 2);
            _y = constraints.maxHeight - widgetSize - 130;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              const _CompanionBackdrop(),

              // Floating Timer Header Capsule
              Positioned(
                top: compact ? 20 : 36,
                left: 0,
                right: 0,
                child: Center(
                  child: RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1116).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8), // Cyan neon indicator
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatDuration(widget.remainingSeconds),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1,
                            height: 14,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.breakInfo.type == BreakType.short
                                ? 'Mindful Rest'
                                : 'Step Away & Unwind',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Interactive Companion Widget
              AnimatedPositioned(
                duration: _isDragging || !enableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _x,
                top: _y,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isDragging = true;
                      _animationState = PetAnimationState.walkSide;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _x = (_x! + details.delta.dx).clamp(
                        0,
                        constraints.maxWidth - widgetSize,
                      );
                      _y = (_y! + details.delta.dy).clamp(
                        0,
                        constraints.maxHeight - widgetSize - 80,
                      );
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;
                      _animationState = PetAnimationState.breakMode;
                    });
                    _snapToEdges(
                      constraints.maxWidth,
                      constraints.maxHeight,
                      widgetSize,
                    );
                  },
                  onTap: () {
                    // Pet interaction
                    setState(() {
                      _flipX = !_flipX;
                      _showInteractionMenu = !_showInteractionMenu;
                      if (_showInteractionMenu) {
                        _animationState = PetAnimationState.idle;
                        _speechText = 'Want to play or cuddle?';
                      } else {
                        _animationState = PetAnimationState.excited;
                        _speechText = '*Happy purrs*';
                      }
                    });
                  },
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Spotlight under pet shadow
                        Positioned(
                          bottom: 55,
                          child: Container(
                            width: 80,
                            height: 16,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Dialogue Speech Bubble
                        Positioned(
                          top: 10,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF0F1115,
                                    ).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _speechText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 1.45,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                CustomPaint(
                                  size: const Size(12, 6),
                                  painter: _BubbleTailPainter(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Quick Radial Menu for actions
                        if (_showInteractionMenu)
                          Positioned(
                            bottom: 25,
                            child: Card(
                              color: const Color(
                                0xFF0F1115,
                              ).withValues(alpha: 0.9),
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Love/Heart
                                    _buildMenuButton(
                                      icon: CupertinoIcons.heart_fill,
                                      color: const Color(0xFFEF4444),
                                      onPressed: () {
                                        setState(() {
                                          _animationState =
                                              PetAnimationState.excited;
                                          _speechText =
                                              species == PetSpecies.dog
                                              ? 'Happy puppy wiggles!'
                                              : 'Purr... Meow!';
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                    // Sleeping
                                    _buildMenuButton(
                                      icon: CupertinoIcons.moon_fill,
                                      color: const Color(0xFF38BDF8),
                                      onPressed: () {
                                        setState(() {
                                          _animationState =
                                              PetAnimationState.sleep;
                                          _speechText = 'Nap time... Zzz.';
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                    // Walk zoom
                                    _buildMenuButton(
                                      icon: CupertinoIcons.play_arrow_solid,
                                      color: const Color(0xFF34D399),
                                      onPressed: () {
                                        setState(() {
                                          _animationState =
                                              PetAnimationState.walkSide;
                                          _speechText =
                                              species == PetSpecies.dog
                                              ? 'Zoom zoom zooms!'
                                              : 'Prowling...';
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Companion Sprite
                        Positioned(
                          bottom: 50,
                          child: SizedBox(
                            width: widgetSize,
                            height: widgetSize,
                            child: Center(
                              child: CompanionSpriteWidget(
                                petTheme: petTheme,
                                animationState: _animationState,
                                scale: 3.5,
                                flipX: _flipX,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Bar: Current Time & Skip
              Positioned(
                bottom: compact ? 20 : 36,
                left: compact ? 24 : 40,
                right: compact ? 24 : 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      'Drag companion anywhere',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (widget.onSkip != null && !widget.settings.strictMode)
                      SkipBreakButton(onSkip: widget.onSkip!),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F1115).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompanionBackdrop extends StatelessWidget {
  const _CompanionBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CompanionBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CompanionBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08090B),
    );

    // Warm radial spotlight source
    final center = Offset(size.width * 0.5, size.height * 0.85);
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF1E293B).withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.45),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);

    final railPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    for (double x = 44; x < size.width; x += 88) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), railPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
