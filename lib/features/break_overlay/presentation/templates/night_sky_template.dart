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
      70,
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

  @override
  Widget build(BuildContext context) {
    const palette = BreakPalette.night;
    final showTip =
        widget.settings.showExercisesInBreak && widget.breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      palette: palette,
      canvas: palette.canvas,
      onSkip: widget.onSkip,
      strictMode: widget.settings.strictMode,
      showSkip: !_isEnding,
      accent: BreakOverlayTheme.dusk,
      background: CustomPaint(painter: _SkyPainter(_stars, _twinkle)),
      child: Stack(
        children: [
          Center(
            child: BreakEntrance(
              scale: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: BreakMotion.medium,
                    switchInCurve: BreakMotion.enter,
                    child: Column(
                      key: ValueKey(_isEnding),
                      children: [
                        Text(
                          _isEnding ? 'Recharged & Ready' : _kind.label,
                          textAlign: TextAlign.center,
                          style: BreakOverlayTheme.serif.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Text(
                            _isEnding
                                ? 'The time away was well spent. Come back '
                                      'to your work with fresh eyes.'
                                : (showTip ? widget.breakInfo.tip : ''),
                            textAlign: TextAlign.center,
                            style: BreakOverlayTheme.body.copyWith(
                              fontSize: 17,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  BreakCountdown(
                    seconds: widget.remainingSeconds,
                    style: BreakOverlayTheme.hero.copyWith(fontSize: 88),
                    color: breakClockColor(widget.settings, palette),
                  ),
                ],
              ),
            ),
          ),
          if (_isEnding && widget.onSkip != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: Center(child: _CompleteButton(onTap: widget.onSkip!)),
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
                color: lit ? BreakOverlayTheme.dusk : BreakPalette.night.border,
              ),
            ),
            child: Text(
              'Complete Session',
              style: BreakOverlayTheme.body.copyWith(
                color: BreakPalette.night.textPrimary,
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
  final Paint _sky = Paint();
  final Paint _star = Paint();

  _SkyPainter(this.stars, this.twinkle) : super(repaint: twinkle);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _sky.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF070A1C), Color(0xFF0A0E27), Color(0xFF111634)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _sky);

    for (final s in stars) {
      final tw = 0.5 + 0.5 * math.sin(twinkle.value * 2 * math.pi + s.phase);
      _star.color = Colors.white.withValues(alpha: 0.2 + 0.45 * tw);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.size,
        _star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}
