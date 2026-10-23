import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/companion_sprite_widget.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

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
  bool _petHovered = false;

  static const double _widgetSize = 130.0;

  /// Idle bob: one full sine period every 2.4s.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// One-shot effects: landing squash (260ms) and the completion hop (400ms).
  late final AnimationController _fx = AnimationController(vsync: this);
  bool _hopping = false;

  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  Color get _accent => BreakPalette.of(context).accentOn(
    BreakOverlayTheme.resolveAccent(
      widget.settings.templateAccentOverrides,
      'companion',
      _kind.accent,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_bob, context, park: 0.0);
  }

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
    _bob.dispose();
    _fx.dispose();
    super.dispose();
  }

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
    final palette = BreakPalette.of(context);
    final petTheme = PetTheme.getTheme(widget.settings.companionPetTheme);
    final reduced = BreakMotion.reduced(context);
    final scrimBase = palette.canvas;

    return BreakScaffold(
      canvas: Colors.transparent,
      scrim: scrimBase.withValues(alpha: 0.55),
      scaled: false,
      showSkip: false,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      accent: _accent,
      background: const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.95,
              colors: [Colors.transparent, Color(0x40000000)],
            ),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
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
              _y = math.max(
                0.0,
                (constraints.maxHeight - _widgetSize) / 2 - 24,
              );
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
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(
                        BreakOverlayTheme.radiusMd,
                      ),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      widget.breakInfo.tip,
                      textAlign: TextAlign.center,
                      style: BreakOverlayTheme.body.copyWith(
                        color: palette.textSecondary,
                        fontSize: 13,
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
                top: _y! + _widgetSize + 32,
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
                    onEnter: (_) => setState(() => _petHovered = true),
                    onExit: (_) => setState(() => _petHovered = false),
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
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: BreakMotion.fast,
                                  width: _widgetSize - 8,
                                  height: _widgetSize - 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _accent.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _accent.withValues(
                                          alpha: _petHovered ? 0.28 : 0.18,
                                        ),
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                ),
                                CompanionSpriteWidget(
                                  petTheme: petTheme,
                                  animationState: PetAnimationState.idle,
                                  scale: 3.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: compact ? 20 : 48,
                left: 0,
                right: 0,
                child: Center(child: _buildDock(palette, compact)),
              ),

              Positioned(
                bottom: compact ? 36 : 64,
                left: compact ? 24 : 40,
                child: Semantics(
                  label: 'Current time',
                  excludeSemantics: true,
                  child: Text(
                    DateFormat('HH:mm').format(DateTime.now()),
                    style: BreakOverlayTheme.micro.copyWith(
                      color: palette.textMuted,
                      fontFeatures: BreakOverlayTheme.tabular,
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

  Widget _buildDock(BreakPalette palette, bool compact) {
    final canSkip = breakCanSkip(widget.settings, widget.onSkip);
    return BreakGlass(
      radius: BreakOverlayTheme.radiusPill,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreakCountdown(
              seconds: widget.remainingSeconds,
              style: BreakOverlayTheme.title,
              color: breakClockColor(widget.settings, palette),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              BreakLabel(_kind.label),
            ],
            if (canSkip) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 20, color: palette.border),
              const SizedBox(width: 8),
              BreakSkipButton(onPressed: widget.onSkip!, accent: _accent),
            ],
          ],
        ),
      ),
    );
  }
}
