import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/domain/break_tips.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

/// Break template: a draggable pet companion that snaps to screen edges and cycles through tips.
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
    with TickerProviderStateMixin {
  double? _x;
  double? _y;
  double? _lastWidth;
  double? _lastHeight;
  bool _isDragging = false;
  bool _hasDragged = false;

  static const double _widgetSize = 130.0;

  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final AnimationController _fx = AnimationController(vsync: this);
  bool _hopping = false;

  late final List<String> _tips = [
    if (widget.breakInfo.tip.isNotEmpty) widget.breakInfo.tip,
    ...BreakTips.extra(widget.breakInfo),
  ];
  int _tipIndex = 0;
  Timer? _tipTimer;

  static const BreakPalette _mint = BreakPalette(
    canvas: Color(0xFF1C2823),
    canvasRaised: Color(0xFF26382F),
    surface: Color(0xFF26382F),
    border: Color(0x426B746B),
    track: Color(0x426B746B),
    textPrimary: Color(0xFFDCE6DC),
    textSecondary: Color(0xFFB8CEBE),
    textMuted: Color(0xFFA1BAA9),
    isDark: true,
  );

  Color get _accent => BreakOverlayTheme.resolveAccent(
    widget.settings.templateAccentOverrides,
    'companion',
    const Color(0xFF1F9D78),
  );

  // Tips rotate every 12s unless frozen or the user is dragging the pet.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_bob, context, park: 0.0);
    _tipTimer?.cancel();
    if (_tips.length > 1 && !breakShouldFreeze(context)) {
      _tipTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted && !_isDragging) setState(() => _tipIndex++);
      });
    }
  }

  // Hops once when the countdown hits zero.
  @override
  void didUpdateWidget(covariant CompanionInteractiveTemplate old) {
    super.didUpdateWidget(old);
    if (widget.remainingSeconds <= 0 &&
        old.remainingSeconds > 0 &&
        !breakShouldFreeze(context)) {
      _hopping = true;
      _fx.duration = const Duration(milliseconds: 400);
      _fx.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _bob.dispose();
    _fx.dispose();
    super.dispose();
  }

  // Snaps to whichever screen edge is nearest.
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

  void _land() {
    if (breakShouldFreeze(context)) return;
    _hopping = false;
    _fx.duration = const Duration(milliseconds: 260);
    _fx.forward(from: 0);
  }

  Matrix4 _petTransform() {
    final bobY = 3 * math.sin(_bob.value * 2 * math.pi);
    var sx = 1.0, sy = 1.0, dy = bobY;
    if (_fx.isAnimating || _fx.value > 0) {
      final t = _fx.value;
      if (_hopping) {
        dy += -12 * math.sin(math.pi * t);
      } else {
        final k = Curves.elasticOut.transform(t);
        sx = 1.08 + (1.0 - 1.08) * k;
        sy = 0.9 + (1.0 - 0.9) * k;
      }
    }
    if (_isDragging) {
      sx *= 1.05;
      sy *= 1.05;
    }
    return Matrix4.translationValues(0, dy, 0)..scaleByDouble(sx, sy, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _mint;
    final petTheme = PetTheme.getTheme(widget.settings.companionPetTheme);
    final reduced = BreakMotion.reduced(context);

    return BreakScaffold(
      palette: palette,
      background: const CustomPaint(painter: _RoomPainter()),
      scaled: false,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
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
              _y = math.max(0.0, constraints.maxHeight * 0.74 - _widgetSize);
            }
            _lastWidth = constraints.maxWidth;
            _lastHeight = constraints.maxHeight;
          }

          final settle = _isDragging || reduced
              ? Duration.zero
              : const Duration(milliseconds: 300);
          final bubbleAbove = _y! > 120;

          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedPositioned(
                duration: settle,
                curve: Curves.easeOutCubic,
                left: math.max(8.0, _x! - 45),
                top: bubbleAbove ? null : _y! + _widgetSize + 12,
                bottom: bubbleAbove ? constraints.maxHeight - _y! + 12 : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tips[_tipIndex % _tips.length],
                      textAlign: TextAlign.center,
                      style: BreakOverlayTheme.serif.copyWith(
                        color: palette.textPrimary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              AnimatedPositioned(
                duration: settle,
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,

                top: bubbleAbove
                    ? _y! + _widgetSize + 32
                    : math.max(8.0, _y! - 32),
                child: ExcludeSemantics(
                  child: AnimatedOpacity(
                    opacity: _hasDragged ? 0 : 1,
                    duration: BreakMotion.medium,
                    child: Text(
                      'Drag companion anywhere',
                      textAlign: TextAlign.center,
                      style: BreakOverlayTheme.body.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
              ),

              AnimatedPositioned(
                duration: settle,
                curve: Curves.easeOutCubic,
                left: _x,
                top: _y,
                child: Semantics(
                  label: 'Companion, draggable',
                  child: MouseRegion(
                    cursor: _isDragging
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: GestureDetector(
                      onPanStart: (_) => setState(() {
                        _isDragging = true;
                        _hasDragged = true;
                      }),
                      onPanUpdate: (d) {
                        setState(() {
                          _x = (_x! + d.delta.dx).clamp(
                            0.0,
                            constraints.maxWidth - _widgetSize,
                          );
                          _y = (_y! + d.delta.dy).clamp(
                            0.0,
                            math.max(
                              0.0,
                              constraints.maxHeight - _widgetSize - 80,
                            ),
                          );
                        });
                      },
                      onPanEnd: (_) {
                        setState(() => _isDragging = false);
                        _snapToEdge(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        _land();
                      },
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_bob, _fx]),
                          builder: (context, child) => Transform(
                            alignment: Alignment.bottomCenter,
                            transform: _petTransform(),
                            child: child,
                          ),
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
                    ),
                  ),
                ),
              ),

              Positioned(
                top: math.min(40.0, constraints.maxHeight * 0.1),
                left: math.min(56.0, constraints.maxWidth * 0.08),
                child: BreakCountdown(
                  seconds: widget.remainingSeconds,
                  textAlign: TextAlign.left,
                  style: BreakOverlayTheme.display.copyWith(
                    fontSize: (constraints.maxHeight * 0.14).clamp(28.0, 64.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                  ),
                  color: breakClockColor(widget.settings, palette),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final floorY = h * 0.72;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, floorY),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2823), Color(0xFF25352D)],
        ).createShader(Rect.fromLTWH(0, 0, w, floorY)),
    );

    final win = Rect.fromLTWH(w * 0.7, h * 0.12, w * 0.16, h * 0.34);
    final winRRect = RRect.fromRectAndCorners(
      win,
      topLeft: Radius.circular(w * 0.08),
      topRight: Radius.circular(w * 0.08),
      bottomLeft: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
    );
    canvas.drawRRect(
      winRRect.inflate(math.max(4, w * 0.008)),
      Paint()..color = const Color(0xFF3B5144),
    );
    canvas.drawRRect(
      winRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF263D49), Color(0xFF384B4A)],
        ).createShader(win),
    );
    final mullion = Paint()
      ..color = const Color(0xFF3B5144)
      ..strokeWidth = math.max(3, w * 0.005);
    canvas.drawLine(win.topCenter, win.bottomCenter, mullion);
    canvas.drawLine(
      Offset(win.left, win.center.dy),
      Offset(win.right, win.center.dy),
      mullion,
    );

    final beam = Path()
      ..moveTo(win.left, win.bottom)
      ..lineTo(win.right, win.bottom)
      ..lineTo(win.right - w * 0.22, h)
      ..lineTo(win.left - w * 0.34, h)
      ..close();
    canvas.drawPath(beam, Paint()..color = const Color(0x107C9A83));

    final floor = Rect.fromLTRB(0, floorY, w, h);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF302E28), Color(0xFF252923)],
        ).createShader(floor),
    );
    final plank = Paint()
      ..color = const Color(0x1F8A5A2B)
      ..strokeWidth = 1.5;
    for (var i = 1; i < 4; i++) {
      final y = floorY + (h - floorY) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), plank);
    }
    canvas.drawLine(
      Offset(0, floorY),
      Offset(w, floorY),
      Paint()
        ..color = const Color(0xFF3B5144)
        ..strokeWidth = math.max(3, h * 0.008),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.85),
        width: w * 0.36,
        height: h * 0.12,
      ),
      Paint()..color = const Color(0xFF344B3B),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) => false;
}
