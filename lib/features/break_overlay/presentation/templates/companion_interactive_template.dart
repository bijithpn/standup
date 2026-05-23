import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/features/settings/settings_model.dart';
import 'package:standup/features/companion/domain/pet_theme.dart';
import 'package:standup/features/companion/domain/pet_animation_state.dart';
import 'package:standup/features/companion/domain/pet_type.dart';
import 'package:standup/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

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
  State<CompanionInteractiveTemplate> createState() => _CompanionInteractiveTemplateState();
}

class _CompanionInteractiveTemplateState extends State<CompanionInteractiveTemplate> {
  // Companion placement and physics snapping
  double? _x;
  double? _y;
  bool _isDragging = false;
  bool _isSnapping = false;

  // AI & Conversation State
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
    _startSpeechCycle();
    _startAIBehaviorCycle();
  }

  @override
  void dispose() {
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
          } else if (species == PetSpecies.rabbit) {
            _speechText = 'Hop stretch! Warming up my hind legs!';
          } else if (species == PetSpecies.fox) {
            _speechText = 'Sly fox stretch! Stay alert!';
          } else if (species == PetSpecies.dragon) {
            _speechText = 'Spreading my wings for a grand stretch!';
          } else {
            _speechText = 'Mmm, cat stretching feels incredible...';
          }
        } else if (random < 0.45) {
          _animationState = PetAnimationState.sleep;
          if (species == PetSpecies.dog) {
            _speechText = 'Zzz... Cozy puppy dreams...';
          } else if (species == PetSpecies.rabbit) {
            _speechText = 'Zzz... Dreaming of clover fields...';
          } else if (species == PetSpecies.fox) {
            _speechText = 'Zzz... Curl up in a warm den...';
          } else if (species == PetSpecies.dragon) {
            _speechText = 'Zzz... Resting on a pile of gold...';
          } else {
            _speechText = 'Zzz... Perfect cozy catnap...';
          }
        } else if (random < 0.65) {
          _animationState = PetAnimationState.lick1;
          if (species == PetSpecies.dog) {
            _speechText = 'Cleaning up my puppy paws!';
          } else if (species == PetSpecies.rabbit) {
            _speechText = '*Twitching nose and cleaning long ears...*';
          } else if (species == PetSpecies.fox) {
            _speechText = '*Grooming its fluffy tail...*';
          } else if (species == PetSpecies.dragon) {
            _speechText = '*Polishing shiny dragon scales...*';
          } else {
            _speechText = '*Carefully grooming its soft whiskers...*';
          }
        } else if (random < 0.8) {
          _animationState = PetAnimationState.walkSide;
          if (species == PetSpecies.dog) {
            _speechText = 'Walking around! Zoom zoom!';
          } else if (species == PetSpecies.rabbit) {
            _speechText = 'Hop hop! Exploring new territory!';
          } else if (species == PetSpecies.fox) {
            _speechText = 'Prowling silently... What was that?';
          } else if (species == PetSpecies.dragon) {
            _speechText = 'Gliding through the air currents...';
          } else {
            _speechText = 'Prowling around. I see a bug!';
          }
        } else {
          _animationState = PetAnimationState.breakMode;
          if (species == PetSpecies.dog) {
            _speechText = 'Let\'s take a break together! Woof!';
          } else if (species == PetSpecies.rabbit) {
            _speechText = 'Rest time is the best time! *wiggle nose*';
          } else if (species == PetSpecies.fox) {
            _speechText = 'Time to rest in the woods.';
          } else if (species == PetSpecies.dragon) {
            _speechText = 'Relax, mortal. Let\'s enjoy this quiet moment.';
          } else {
            _speechText = 'Purr... Time to relax and recharge.';
          }
        }
      });
    });
  }

  void _snapToEdges(double screenWidth, double screenHeight, double widgetSize) {
    if (_x == null || _y == null) return;
    
    // Snap to the closest edge: Left, Right, Top, Bottom
    final distLeft = _x!;
    final distRight = screenWidth - (_x! + widgetSize);
    final distTop = _y!;
    final distBottom = screenHeight - (_y! + widgetSize);

    final minDist = [distLeft, distRight, distTop, distBottom].reduce(min);

    setState(() {
      _isSnapping = true;
      if (minDist == distLeft) {
        _x = 20;
        _flipX = false;
      } else if (minDist == distRight) {
        _x = screenWidth - widgetSize - 20;
        _flipX = true;
      } else if (minDist == distTop) {
        _y = 20;
      } else {
        _y = screenHeight - widgetSize - 80; // offset for bottom bar
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

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Initialize coordinates at bottom center if not set
          if (_x == null || _y == null) {
            _x = constraints.maxWidth / 2 - (widgetSize / 2);
            _y = constraints.maxHeight - widgetSize - 120;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Ambient full-screen dark screen dimming
              Container(
                color: Colors.black.withValues(alpha: 0.8),
              ),

              // Ambient backdrop aesthetic particles or slow floating glow
              Positioned(
                top: constraints.maxHeight * 0.15,
                left: constraints.maxWidth * 0.2,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.02),
                  ),
                ),
              ),

              // Main Subtle Floating Timer Header Card
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.015),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDuration(widget.remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          widget.breakInfo.type == BreakType.short
                              ? 'Mindful Rest'
                              : 'Step Away & Unwind',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Interactive Companion Widget
              AnimatedPositioned(
                duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
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
                        constraints.maxHeight - widgetSize - 60,
                      );
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                    _snapToEdges(constraints.maxWidth, constraints.maxHeight, widgetSize);
                  },
                  onTap: () {
                    // Quick Action Menu on Click
                    setState(() {
                      _showInteractionMenu = !_showInteractionMenu;
                      _animationState = PetAnimationState.excited;
                      _speechText = 'Hehe, that tickles!';
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Speech Bubble above Pet
                        Positioned(
                          top: -75,
                          left: -60,
                          right: -60,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Text(
                                      _speechText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Satoshi',
                                      ),
                                    ),
                                    // Bubble Tail
                                    Positioned(
                                      bottom: -6,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: CustomPaint(
                                          size: const Size(12, 6),
                                          painter: _BubbleTailPainter(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Custom Hover Interaction Menu
                        if (_showInteractionMenu)
                          Positioned(
                            bottom: -50,
                            left: -60,
                            right: -60,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24).withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Stretch
                                    _buildMenuButton(
                                      icon: CupertinoIcons.sparkles,
                                      color: const Color(0xFFFFD700),
                                      onPressed: () {
                                        setState(() {
                                          _animationState = PetAnimationState.stretch;
                                          if (species == PetSpecies.dog) {
                                            _speechText = 'A big dog stretch! Ready for action!';
                                          } else if (species == PetSpecies.rabbit) {
                                            _speechText = 'Hop stretch! Warming up my hind legs!';
                                          } else if (species == PetSpecies.fox) {
                                            _speechText = 'Sly fox stretch! Stay alert!';
                                          } else if (species == PetSpecies.dragon) {
                                            _speechText = 'Spreading my wings for a grand stretch!';
                                          } else {
                                            _speechText = 'Mmm, cat stretching feels incredible...';
                                          }
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                    // 2. Pet / Groom
                                    _buildMenuButton(
                                      icon: CupertinoIcons.hand_raised_fill,
                                      color: const Color(0xFFFF9500),
                                      onPressed: () {
                                        setState(() {
                                          _animationState = PetAnimationState.lick1;
                                          if (species == PetSpecies.dog) {
                                            _speechText = 'Happily licking your screen! Slurp!';
                                          } else if (species == PetSpecies.rabbit) {
                                            _speechText = '*Twitching nose and cleaning long ears...*';
                                          } else if (species == PetSpecies.fox) {
                                            _speechText = '*Grooming its fluffy tail...*';
                                          } else if (species == PetSpecies.dragon) {
                                            _speechText = '*Polishing shiny dragon scales...*';
                                          } else {
                                            _speechText = '*Carefully grooming its soft whiskers...*';
                                          }
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                    // 3. Play / Move
                                    _buildMenuButton(
                                      icon: CupertinoIcons.play_arrow_solid,
                                      color: const Color(0xFF34C759),
                                      onPressed: () {
                                        setState(() {
                                          _animationState = PetAnimationState.walkSide;
                                          if (species == PetSpecies.dog) {
                                            _speechText = 'Zooms around hyperactively!';
                                          } else if (species == PetSpecies.rabbit) {
                                            _speechText = 'Hop hop! Exploring new territory!';
                                          } else if (species == PetSpecies.fox) {
                                            _speechText = 'Prowling silently... What was that?';
                                          } else if (species == PetSpecies.dragon) {
                                            _speechText = 'Gliding through the air currents...';
                                          } else {
                                            _speechText = 'Stalking a phantom laser pointer...';
                                          }
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                    // 4. Excited / Love
                                    _buildMenuButton(
                                      icon: CupertinoIcons.heart_fill,
                                      color: const Color(0xFFFF453A),
                                      onPressed: () {
                                        setState(() {
                                          _animationState = PetAnimationState.excited;
                                          if (species == PetSpecies.dog) {
                                            _speechText = 'Happy barks and tail wags! Woof!';
                                          } else if (species == PetSpecies.rabbit) {
                                            _speechText = '*Excited nose wiggles and tiny binkies!*';
                                          } else if (species == PetSpecies.fox) {
                                            _speechText = '*Happy yips and playful pounces!*';
                                          } else if (species == PetSpecies.dragon) {
                                            _speechText = '*Roars softly and breathes tiny heart sparks!*';
                                          } else {
                                            _speechText = '*Happy purrs and headbutts! Meow!*';
                                          }
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                    // 5. Sleep
                                    _buildMenuButton(
                                      icon: CupertinoIcons.moon_fill,
                                      color: const Color(0xFF00E5FF),
                                      onPressed: () {
                                        setState(() {
                                          _animationState = PetAnimationState.sleep;
                                          if (species == PetSpecies.dog) {
                                            _speechText = 'Soft puppy snores... Zzz.';
                                          } else if (species == PetSpecies.rabbit) {
                                            _speechText = 'Napping snugly... Zzz.';
                                          } else if (species == PetSpecies.fox) {
                                            _speechText = 'Sleeping in a curl... Zzz.';
                                          } else if (species == PetSpecies.dragon) {
                                            _speechText = 'Resting on a pile of gold... Zzz.';
                                          } else {
                                            _speechText = 'Cozy catnap mode: activated.';
                                          }
                                          _showInteractionMenu = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
 
                        // Companion Sprite rendering
                        SizedBox(
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
                      ],
                    ),
                  ),
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
                    Text(
                      'Drag your companion to snap them to screen edges.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
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
          );
        },
      ),
    );
  }

  Widget _buildMenuButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
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
      ..color = const Color(0xFF1E1E24).withValues(alpha: 0.85)
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
