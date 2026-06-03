import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

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

  final List<String> _zenQuotes = [
    'Silence is not silent. It is full of answers.',
    'Breathe in experience, breathe out poetry.',
    'Concentrate the mind on the present moment.',
    'Within you, there is a sanctuary of peace.',
    'Flow with whatever may happen.',
    'Mindfulness is remembering to be present.',
  ];

  late String _activeQuote;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _activeQuote = _zenQuotes[DateTime.now().minute % _zenQuotes.length];
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _durationLabel {
    final s = widget.totalSeconds;
    final label = s < 60 ? '$s sec' : '${s ~/ 60} min';
    return 'ZEN MODE · $label';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final compact = media.width < 760 || media.height < 620;

    return Material(
      color: const Color(0xFF07080B),
      child: Stack(
        children: [
          // Animated breathing background glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breathingController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ZenBackdropPainter(
                    breathValue: _breathingController.value,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 24 : 48,
                  vertical: compact ? 20 : 36,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA7F3D0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFA7F3D0).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.wind,
                            size: 12,
                            color: Color(0xFFA7F3D0),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _durationLabel,
                            style: const TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 40 : 64),

                    // Breathing ripples and text
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _breathingController,
                        builder: (context, child) {
                          final val = _breathingController.value;
                          double scale = 0.5;
                          String text = 'Breathe In';

                          if (val < 0.25) {
                            final t = val / 0.25;
                            scale = 0.5 + (t * 0.5); // expand to 1.0
                            text = 'Breathe In';
                          } else if (val < 0.5) {
                            scale = 1.0;
                            text = 'Hold';
                          } else if (val < 0.75) {
                            final t = (val - 0.5) / 0.25;
                            scale = 1.0 - (t * 0.5); // shrink to 0.5
                            text = 'Breathe Out';
                          } else {
                            scale = 0.5;
                            text = 'Hold';
                          }

                          return Column(
                            children: [
                              SizedBox(
                                width: compact ? 220 : 280,
                                height: compact ? 220 : 280,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Ripple 3 (delayed outer glow)
                                    _BreathingRipple(
                                      scale: scale * 1.25,
                                      opacity: 0.03 * scale,
                                    ),
                                    // Ripple 2
                                    _BreathingRipple(
                                      scale: scale * 1.12,
                                      opacity: 0.08 * scale,
                                    ),
                                    // Main core orb
                                    _BreathingRipple(
                                      scale: scale,
                                      opacity: 0.15 * scale,
                                      borderWidth: 2.0,
                                    ),
                                    // Central typography readouts
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: compact ? 20 : 26,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: 1.0,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatTime(widget.remainingSeconds),
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.48,
                                            ),
                                            fontSize: compact ? 12 : 14,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Wellness quote — hidden when showExercisesInBreak is off
                    if (widget.settings.showExercisesInBreak) ...[
                      SizedBox(height: compact ? 36 : 48),
                      Container(
                        width: 480,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1115).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.quote,
                              size: 14,
                              color: const Color(
                                0xFFA7F3D0,
                              ).withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _activeQuote,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.6,
                                fontFamily: 'Inter',
                                fontStyle: FontStyle.italic,
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

          // Skip button — hidden in strict mode
          if (widget.onSkip != null && !widget.settings.strictMode)
            Positioned(
              right: compact ? 24 : 36,
              bottom: compact ? 20 : 36,
              child: SkipBreakButton(onSkip: widget.onSkip!),
            ),
        ],
      ),
    );
  }
}

class _BreathingRipple extends StatelessWidget {
  final double scale;
  final double opacity;
  final double borderWidth;

  const _BreathingRipple({
    required this.scale,
    required this.opacity,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFA7F3D0).withValues(alpha: opacity),
          border: Border.all(
            color: const Color(0xFFA7F3D0).withValues(alpha: opacity * 2.5),
            width: borderWidth,
          ),
        ),
      ),
    );
  }
}

class _ZenBackdropPainter extends CustomPainter {
  final double breathValue;
  _ZenBackdropPainter({required this.breathValue});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08090C),
    );

    // Calculate breath expansion factor
    double expansion = 0.5;
    if (breathValue < 0.25) {
      expansion = 0.5 + ((breathValue / 0.25) * 0.5);
    } else if (breathValue < 0.5) {
      expansion = 1.0;
    } else if (breathValue < 0.75) {
      expansion = 1.0 - (((breathValue - 0.5) / 0.25) * 0.5);
    } else {
      expansion = 0.5;
    }

    // Centered breathing aura glow
    final center = Offset(size.width / 2, size.height / 2);
    final auraPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF0F766E).withValues(alpha: 0.12 * expansion),
              const Color(0xFF1E293B).withValues(alpha: 0.02),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: center,
              radius: size.width * 0.45 * expansion,
            ),
          );
    canvas.drawCircle(center, size.width * 0.45 * expansion, auraPaint);

    // Thin elegant parallel lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    const double spacing = 64.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZenBackdropPainter oldDelegate) =>
      oldDelegate.breathValue != breathValue;
}
