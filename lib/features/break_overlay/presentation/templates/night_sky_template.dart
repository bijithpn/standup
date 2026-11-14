import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class NightSkyTemplate extends StatefulWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const NightSkyTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  State<NightSkyTemplate> createState() => _NightSkyTemplateState();
}

class _Star {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
  });
}

class _NightSkyTemplateState extends State<NightSkyTemplate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  late final List<_Star> _stars = () {
    final rand = math.Random(7);
    return List.generate(
      130,
      (_) => _Star(
        dx: rand.nextDouble(),
        dy: rand.nextDouble(),
        size: 0.8 + rand.nextDouble() * 1.2,
        phase: rand.nextDouble() * 2 * math.pi,
      ),
    );
  }();
  late final BreakKind _kind = BreakKind.of(widget.breakInfo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    breakSyncLoop(_twinkle, context);
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  bool get _isEnding =>
      widget.remainingSeconds <= 0 ||
      breakProgress(widget.remainingSeconds, widget.totalSeconds) >= 0.95;

  static const _palette = BreakPalette(
    canvas: Color(0xFF0B0F2B),
    canvasRaised: Color(0xFF141A3D),
    surface: Color(0xFF1A2147),
    border: Color(0x33FFFFFF),
    track: Color(0x33FFFFFF),
    textPrimary: Color(0xFFF1EEFF),
    textSecondary: Color(0xFFB9B5E0),
    textMuted: Color(0xFF9692C4),
    isDark: true,
  );
  static const _aurora = Color(0xFF7BE0C3);

  @override
  Widget build(BuildContext context) {
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      palette: _palette,
      canvas: _palette.canvas,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      showSkip: !_isEnding,
      accent: _aurora,
      background: CustomPaint(painter: _SkyPainter(_stars, _twinkle)),
      child: Stack(
        children: [
          Positioned(
            left: 128,
            bottom: 184,
            child: BreakEntrance(
              scale: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: BreakMotion.medium,
                    switchInCurve: BreakMotion.enter,
                    child: Column(
                      key: ValueKey(_isEnding),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEnding ? 'Recharged & Ready' : _kind.label,
                          style: BreakOverlayTheme.serif.copyWith(
                            fontSize: 40,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w300,
                            color: _palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(
                            _isEnding
                                ? 'The time away was well spent. Come back '
                                      'to your work with fresh eyes.'
                                : (showTip ? widget.breakInfo.tip : ''),
                            style: BreakOverlayTheme.body.copyWith(
                              fontSize: 17,
                              color: _palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  BreakCountdown(
                    seconds: widget.remainingSeconds,
                    textAlign: TextAlign.left,
                    style: BreakOverlayTheme.hero.copyWith(
                      fontSize: 168,
                      fontWeight: FontWeight.w100,
                      letterSpacing: -6,
                    ),
                    color: breakClockColor(widget.settings, _palette),
                  ),
                ],
              ),
            ),
          ),
          if (_isEnding && widget.onSkip != null)
            Positioned(
              left: 128,
              bottom: 64,
              child: _CompleteButton(onTap: widget.onSkip!),
            ),
        ],
      ),
    );
  }
}

class _CompleteButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CompleteButton({required this.onTap});

  @override
  State<_CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<_CompleteButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final lit = _hovered || _focused;
    return Semantics(
      container: true,
      button: true,
      label: 'Complete session',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: BreakMotion.fast,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BreakOverlayTheme.radiusPill),
              border: Border.all(
                color: lit
                    ? _NightSkyTemplateState._aurora
                    : _NightSkyTemplateState._palette.border,
              ),
            ),
            child: Text(
              'Complete Session',
              style: BreakOverlayTheme.body.copyWith(
                color: _NightSkyTemplateState._palette.textPrimary,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final List<_Star> stars;
  final Animation<double> twinkle;
  final Paint _p = Paint();

  _SkyPainter(this.stars, this.twinkle) : super(repaint: twinkle);

  void _band(
    Canvas canvas,
    Size size, {
    required double y,
    required double thickness,
    required double phase,
    required Color color,
  }) {
    final drift = math.sin(twinkle.value * 2 * math.pi + phase) * 30;
    final top = <Offset>[];
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      top.add(
        Offset(
          size.width * (t * 1.2 - 0.1),
          size.height * y +
              drift +
              math.sin(t * 5 + phase) * size.height * 0.05 -
              t * size.height * 0.12,
        ),
      );
    }
    final path = Path()..moveTo(top.first.dx, top.first.dy);
    for (final o in top.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    for (final o in top.reversed) {
      path.lineTo(o.dx, o.dy + thickness * size.height);
    }
    path.close();
    _p
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.7))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawPath(path, _p);
    _p
      ..shader = null
      ..maskFilter = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    _p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF060820), Color(0xFF1B1646), Color(0xFF3A2A6B)],
    ).createShader(rect);
    canvas.drawRect(rect, _p);
    _p.shader = null;

    _band(
      canvas,
      size,
      y: 0.3,
      thickness: 0.28,
      phase: 0.6,
      color: const Color(0xFF3FD6B0),
    );
    _band(
      canvas,
      size,
      y: 0.4,
      thickness: 0.22,
      phase: 2.4,
      color: const Color(0xFF8B6CF0),
    );

    for (final s in stars) {
      final tw = 0.5 + 0.5 * math.sin(twinkle.value * 2 * math.pi + s.phase);
      _p.color = Colors.white.withValues(alpha: 0.25 + 0.6 * tw);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height * 0.85),
        s.size,
        _p,
      );
    }

    final moonC = Offset(size.width * 0.8, size.height * 0.2);
    final r = size.height * 0.085;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moonC, radius: r)),
      Path()..addOval(
        Rect.fromCircle(
          center: moonC.translate(r * 0.55, -r * 0.2),
          radius: r * 0.92,
        ),
      ),
    );
    _p.color = const Color(0xFFF7EFD4);
    canvas.drawPath(moon, _p);

    for (final (base, amp, seed, color) in [
      (0.9, 0.07, 1.0, const Color(0xFF1A1442)),
      (0.96, 0.05, 4.0, const Color(0xFF0A0A22)),
    ]) {
      final hill = Path()..moveTo(0, size.height);
      for (var i = 0; i <= 48; i++) {
        final t = i / 48;
        hill.lineTo(
          size.width * t,
          size.height * (base - amp * (0.5 + 0.5 * math.sin(t * 4.2 + seed))),
        );
      }
      hill
        ..lineTo(size.width, size.height)
        ..close();
      _p.color = color;
      canvas.drawPath(hill, _p);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}
