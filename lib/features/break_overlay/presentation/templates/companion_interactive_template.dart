import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';

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
    extends State<CompanionInteractiveTemplate> {
  double? _x;
  double? _y;
  double? _lastWidth;
  double? _lastHeight;
  bool _isDragging = false;

  static const double _widgetSize = 130.0;

  void _snapToEdge(double sw, double sh) {
    if (_x == null || _y == null) return;
    final dists = {
      'left': _x!,
      'right': sw - (_x! + _widgetSize),
      'top': _y!,
      'bottom': sh - (_y! + _widgetSize),
    };
    final nearest = dists.entries.reduce((a, b) => a.value < b.value ? a : b);
    setState(() {
      switch (nearest.key) {
        case 'left':
          _x = 24;
          break;
        case 'right':
          _x = sw - _widgetSize - 24;
          break;
        case 'top':
          _y = 40;
          break;
        case 'bottom':
          _y = sh - _widgetSize - 90;
          break;
      }
    });
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final petTheme = PetTheme.getTheme(widget.settings.companionPetTheme);
    final isShort = widget.breakInfo.type == BreakType.short;
    final compact = MediaQuery.of(context).size.width < 760;

    return ColoredBox(
      color: const Color(0xFF0A0A0F),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_lastWidth != constraints.maxWidth ||
              _lastHeight != constraints.maxHeight) {
            if (_x != null && _lastWidth != null && _lastWidth! > 0) {
              _x = (_x! / _lastWidth!) * constraints.maxWidth;
            } else {
              _x = constraints.maxWidth / 2 - _widgetSize / 2;
            }
            if (_y != null && _lastHeight != null && _lastHeight! > 0) {
              _y = (_y! / _lastHeight!) * constraints.maxHeight;
            } else {
              _y = constraints.maxHeight - _widgetSize - 130;
            }
            _lastWidth = constraints.maxWidth;
            _lastHeight = constraints.maxHeight;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: compact ? 20 : 36,
                left: 0,
                right: 0,
                child: Center(
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
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7EC8E3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatTime(widget.remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
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
                          isShort ? 'Mindful rest' : 'Step away & unwind',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _x! - 40,
                top: _y! - 90,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1115).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      widget.breakInfo.tip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),

              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _x,
                top: _y,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDragging = true),
                  onPanUpdate: (d) {
                    setState(() {
                      _x = (_x! + d.delta.dx).clamp(
                        0.0,
                        constraints.maxWidth - _widgetSize,
                      );
                      _y = (_y! + d.delta.dy).clamp(
                        0.0,
                        constraints.maxHeight - _widgetSize - 80,
                      );
                    });
                  },
                  onPanEnd: (_) {
                    setState(() => _isDragging = false);
                    _snapToEdge(constraints.maxWidth, constraints.maxHeight);
                  },
                  child: SizedBox(
                    width: _widgetSize,
                    height: _widgetSize,
                    child: CompanionSpriteWidget(
                      petTheme: petTheme,
                      animationState: PetAnimationState.idle,
                      scale: 3.5,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: compact ? 20 : 36,
                left: compact ? 24 : 40,
                right: compact ? 24 : 40,
                child: Row(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Drag companion anywhere',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const Spacer(),
                    if (!widget.settings.strictMode && widget.onSkip != null)
                      GestureDetector(
                        onTap: widget.onSkip,
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
